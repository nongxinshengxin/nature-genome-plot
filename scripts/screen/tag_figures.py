#!/usr/bin/env python3
"""Build a figure inventory for the 200-paper corpus and score archetype coverage.

Caches full-text XML under data/fulltext/, extracts every <fig> caption, tags it
against the 12 archetype keyword sets, and writes:
  - docs/figure-inventory.csv  (one row per figure)
  - docs/m2-figures.md         (coverage report)

Usage:
    python3 scripts/screen/tag_figures.py
"""
from __future__ import annotations

import csv
import os
import re
import time
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import urllib.request
import xml.etree.ElementTree as ET

API = "https://www.ebi.ac.uk/europepmc/webservices/rest/{pmcid}/fullTextXML"
CACHE = Path("data/fulltext")

# Strict vocabularies: only terms that almost always indicate the archetype.
# Recall is lower than a loose match, but counts stay defensible.
ARCHETYPES: dict[str, list[str]] = {
    "circos-landscape": [r"circos", r"circular genome", r"circular plot", r"circle plot",
                         r"genome circle", r"circular representation"],
    "linear-tracks": [r"genome browser", r"\bIGV\b", r"\bJBrowse\b", r"gene model",
                      r"coverage track", r"genomic track"],
    "synteny": [r"synteny", r"collinear", r"dot ?plot", r"macro-?synteny", r"micro-?synteny"],
    "assembly-qc": [r"BUSCO", r"\bN50\b", r"NG50", r"k-?mer", r"assembly statistic",
                    r"Merqury", r"\bQV\b", r"assembly completeness"],
    "pangenome-composition": [r"pan-?genome", r"graph-based (pangenome|reference|genome)",
                              r"core genome", r"accessory genome", r"dispensable genome",
                              r"core and (accessory|dispensable)"],
    "presence-absence": [r"presence[/ -]absence", r"\bPAV\b", r"upset", r"flower plot",
                         r"gene presence"],
    "sv-cnv": [r"structural variation", r"structural variant", r"\bCNV\b", r"copy number vari"],
    "population-structure": [r"\bPCA\b", r"principal component", r"admixture",
                             r"population structure", r"\bUMAP\b"],
    "manhattan-qq": [r"manhattan", r"\bQQ\b", r"quantile-?quantile"],
    "selection-scan": [r"\bFst\b", r"Tajima", r"XP-?EHH", r"\biHS\b", r"selective sweep",
                       r"selection signature", r"nucleotide diversity", r"\bCLR\b"],
    "demography": [r"PSMC", r"site frequency spectrum", r"\bSFS\b", r"treemix",
                   r"demographic history", r"LD decay", r"\bIBD\b"],
    "phylogenomics": [r"phylogen", r"species tree", r"gene tree", r"tree topology",
                      r"maximum likelihood tree"],
}

COMPILED = {k: re.compile("|".join(v), re.I) for k, v in ARCHETYPES.items()}


def fetch(pmcid: str) -> str | None:
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / f"{pmcid}.xml"
    if path.exists() and path.stat().st_size > 5000:
        return path.read_text(encoding="utf-8", errors="ignore")
    for i in range(2):
        try:
            with urllib.request.urlopen(API.format(pmcid=pmcid), timeout=25) as fh:
                xml = fh.read().decode("utf-8", "ignore")
            path.write_text(xml, encoding="utf-8")
            time.sleep(0.1)
            return xml
        except Exception:
            if i == 1:
                return None
            time.sleep(1.5)
    return None


def figures(xml: str) -> list[tuple[str, str]]:
    out = []
    try:
        root = ET.fromstring(xml)
    except ET.ParseError:
        return out
    for fig in root.iter():
        if not fig.tag.endswith("fig"):
            continue
        label, caption = "", ""
        for child in fig:
            tag = child.tag.split("}")[-1]
            if tag == "label":
                label = "".join(child.itertext()).strip()
            elif tag in {"caption", "title"}:
                caption += " " + " ".join("".join(child.itertext()).split())
        if caption.strip():
            out.append((label, caption.strip()[:1200]))
    return out


def main() -> None:
    rows = list(csv.DictReader(open("docs/corpus.csv", encoding="utf-8")))
    results: list[dict] = []

    def work(row: dict) -> list[dict]:
        xml = fetch(row["pmcid"])
        if not xml:
            return []
        out = []
        for label, cap in figures(xml):
            tags = [k for k, rx in COMPILED.items() if rx.search(cap)]
            out.append({
                "pmcid": row["pmcid"],
                "journal": row["journal"],
                "year": row["year"],
                "doi": row["doi"],
                "fig_label": label,
                "archetypes": "|".join(tags),
                "n_tags": len(tags),
                "caption": cap,
            })
        return out

    with ThreadPoolExecutor(max_workers=8) as pool:
        futs = {pool.submit(work, r): r for r in rows}
        for n, fut in enumerate(as_completed(futs), 1):
            results.extend(fut.result())
            if n % 40 == 0:
                print(f"  {n}/{len(rows)}", flush=True)

    order = {r["pmcid"]: i for i, r in enumerate(rows)}
    results.sort(key=lambda r: (order.get(r["pmcid"], 9999), r["fig_label"]))

    with open("docs/figure-inventory.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(results[0].keys()))
        w.writeheader()
        w.writerows(results)

    # coverage: a paper counts for an archetype if any of its figures is tagged
    per_paper: dict[str, set[str]] = defaultdict(set)
    for r in results:
        if r["archetypes"]:
            per_paper[r["pmcid"]].update(r["archetypes"].split("|"))

    counts = Counter(t for tags in per_paper.values() for t in tags)
    lines = [
        "# M2 图型覆盖报告（自动标注）",
        "",
        f"- 论文数：{len(rows)}；图数：{len(results)}；平均每篇 {len(results)/len(rows):.1f} 张图",
        f"- 至少被标注一次的图：{sum(1 for r in results if r['n_tags'])}",
        "",
        "| archetype | 覆盖论文数 | 覆盖图数 | 达标（≥10 篇） |",
        "|---|---|---|---|",
    ]
    for k in ARCHETYPES:
        n_papers = sum(1 for tags in per_paper.values() if k in tags)
        n_figs = sum(1 for r in results if k in r["archetypes"])
        lines.append(f"| {k} | {n_papers} | {n_figs} | {'✅' if n_papers >= 10 else '⚠️'} |")

    # per-journal coverage
    lines += ["", "## 分刊覆盖（论文数）", "", "| 期刊 | " + " | ".join(ARCHETYPES) + " |",
              "|---" * (len(ARCHETYPES) + 1) + "|"]
    for j in ["Nature", "Nature Genetics", "Nature Plants", "Nature Ecology & Evolution",
              "Nature Microbiology", "Nature Communications"]:
        ids = {r["pmcid"] for r in rows if r["journal"] == j}
        cells = [str(sum(1 for pid, tags in per_paper.items() if pid in ids and k in tags))
                 for k in ARCHETYPES]
        lines.append(f"| {j} | " + " | ".join(cells) + " |")

    Path("docs/m2-figures.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines[4:18]))
    print(f"\nwritten: docs/figure-inventory.csv ({len(results)} rows), docs/m2-figures.md")


if __name__ == "__main__":
    main()
