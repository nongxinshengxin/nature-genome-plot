#!/usr/bin/env python3
"""Pick the 80-paper deep-read set from the 200-paper corpus.

Greedy coverage: prefer papers that add archetypes not yet covered, then papers
with code availability, while keeping journal representation reasonably even.

Usage:
    python3 scripts/screen/select_deepread.py [--n 80]
"""
from __future__ import annotations

import argparse
import csv
import math
from collections import Counter, defaultdict

ARCHETYPES = [
    "circos-landscape", "linear-tracks", "synteny", "assembly-qc",
    "pangenome-composition", "presence-absence", "sv-cnv",
    "population-structure", "manhattan-qq", "selection-scan",
    "demography", "phylogenomics",
]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=80)
    args = ap.parse_args()

    corpus = list(csv.DictReader(open("docs/corpus.csv", encoding="utf-8")))
    audit = {r["pmcid"]: r for r in csv.DictReader(open("docs/code-audit.csv", encoding="utf-8"))}
    figs = list(csv.DictReader(open("docs/figure-inventory.csv", encoding="utf-8")))

    paper_tags: dict[str, set[str]] = defaultdict(set)
    paper_figs: Counter = Counter()
    for r in figs:
        paper_figs[r["pmcid"]] += 1
        for t in r["archetypes"].split("|"):
            if t:
                paper_tags[r["pmcid"]].add(t)

    papers = []
    for c in corpus:
        pid = c["pmcid"]
        a = audit.get(pid, {})
        papers.append({
            **c,
            "tags": paper_tags.get(pid, set()),
            "has_code": int(a.get("has_code_section") or 0) or int(a.get("n_code_links") or 0) > 0,
            "n_figs": paper_figs.get(pid, 0),
        })

    covered: set[str] = set()
    journal_count: Counter = Counter()
    chosen: list[dict] = []
    remaining = [p for p in papers if p["tags"]]

    while remaining and len(chosen) < args.n:
        def gain(p: dict) -> float:
            new = len(p["tags"] - covered)
            s = new * 10.0
            s += 2.0 if p["has_code"] else 0.0
            s += 1.0 if journal_count[p["journal"]] < args.n / 8 else 0.0
            s += min(math.log10(1 + int(p["cited_by"] or 0)), 1.5)
            return s

        best = max(remaining, key=gain)
        remaining.remove(best)
        chosen.append(best)
        covered |= best["tags"]
        journal_count[best["journal"]] += 1

    # fill any archetype with fewer than 5 papers in the selection
    sel_tags = Counter(t for p in chosen for t in p["tags"])
    for a in ARCHETYPES:
        if sel_tags[a] >= 5:
            continue
        pool = [p for p in remaining if a in p["tags"]]
        pool.sort(key=lambda p: (p["has_code"], int(p["cited_by"] or 0)), reverse=True)
        for p in pool[: 5 - sel_tags[a]]:
            chosen.append(p)
            remaining.remove(p)
            cover_update = p["tags"]
            covered |= cover_update
            journal_count[p["journal"]] += 1

    chosen.sort(key=lambda p: (p["journal"], -len(p["tags"]), p["year"]))
    out = []
    for p in chosen:
        out.append({
            "pmcid": p["pmcid"], "doi": p["doi"], "journal": p["journal"], "year": p["year"],
            "title": p["title"], "cited_by": p["cited_by"], "n_figs": p["n_figs"],
            "has_code": int(bool(p["has_code"])),
            "archetypes": "|".join(sorted(p["tags"])),
            "score": p["score"],
        })
    with open("docs/deep-read.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(out[0].keys()))
        w.writeheader()
        w.writerows(out)

    cov = Counter(t for p in chosen for t in p["tags"])
    print(f"selected {len(chosen)} papers")
    print("journal mix:", dict(Counter(p["journal"] for p in chosen)))
    print("has code:", sum(1 for p in chosen if p["has_code"]))
    print("archetype coverage in selection:")
    for a in ARCHETYPES:
        print(f"  {a:24s} {cov[a]}")


if __name__ == "__main__":
    main()
