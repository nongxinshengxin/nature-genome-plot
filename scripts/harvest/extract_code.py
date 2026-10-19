#!/usr/bin/env python3
"""Extract code-availability evidence for the harvested corpus.

For every paper in docs/corpus.csv, fetch the Europe PMC full-text XML and pull
out: the Code/Data availability sections, repository links, plotting-library
mentions, and the number of figures. Writes docs/code-audit.csv.

Usage:
    python3 scripts/harvest/extract_code.py [--corpus docs/corpus.csv] [--out docs/code-audit.csv]
"""
from __future__ import annotations

import argparse
import csv
import re
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
import urllib.request
import xml.etree.ElementTree as ET

API = "https://www.ebi.ac.uk/europepmc/webservices/rest/{pmcid}/fullTextXML"

HOSTS = {
    "github": "github.com",
    "gitlab": "gitlab.com",
    "zenodo": "zenodo.org",
    "figshare": "figshare.com",
    "dryad": "datadryad.org",
    "osf": "osf.io",
    "bitbucket": "bitbucket.org",
}

PLOT_LIBS = [
    "ggplot2", "matplotlib", "seaborn", "circlize", "ggtree",
    "complexheatmap", "plotly", "karyoploteR", "RIdeogram", "CMplot",
    "ggpubr", "patchwork", "scanpy", "seurat", "pheatmap",
]

URL_RE = re.compile(r"https?://[^\s<>\"',;\)\]]+")


def fetch(pmcid: str, tries: int = 2) -> str | None:
    for i in range(tries):
        try:
            with urllib.request.urlopen(API.format(pmcid=pmcid), timeout=25) as fh:
                return fh.read().decode("utf-8", "ignore")
        except Exception:
            if i == tries - 1:
                return None
            time.sleep(1.5 * (i + 1))
    return None


def sections(xml: str) -> dict[str, str]:
    out: dict[str, str] = {}
    try:
        root = ET.fromstring(xml)
    except ET.ParseError:
        return out
    for sec in root.iter():
        if not sec.tag.endswith("sec"):
            continue
        title = ""
        for child in sec:
            if child.tag.endswith("title"):
                title = "".join(child.itertext()).strip().lower()
                break
        if title in {"code availability", "data availability"}:
            out[title] = " ".join("".join(sec.itertext()).split())[:4000]
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", default="docs/corpus.csv")
    ap.add_argument("--out", default="docs/code-audit.csv")
    args = ap.parse_args()

    rows = list(csv.DictReader(open(args.corpus, encoding="utf-8")))

    def process(row: dict) -> dict:
        pmcid = row["pmcid"]
        xml = fetch(pmcid)
        if xml is None:
            return {**row, "fulltext": "fail", "n_figs": 0,
                    "has_code_section": 0, "has_data_section": 0,
                    "n_code_links": 0, "hosts": "", "code_urls": "",
                    "plot_libs": ""}
        secs = sections(xml)
        code = secs.get("code availability", "")
        urls = URL_RE.findall(code + " " + secs.get("data availability", ""))
        urls = [u.rstrip(".") for u in dict.fromkeys(urls)]
        hosts = sorted({name for name, dom in HOSTS.items() if any(dom in u for u in urls)})
        low = xml.lower()
        libs = sorted({lib for lib in PLOT_LIBS if lib.lower() in low})
        n_figs = len(re.findall(r"<fig\b", xml))
        return {
            **row,
            "fulltext": "ok",
            "n_figs": n_figs,
            "has_code_section": int(bool(code)),
            "has_data_section": int("data availability" in secs),
            "n_code_links": len(urls),
            "hosts": "|".join(hosts),
            "code_urls": "|".join(urls[:8]),
            "plot_libs": "|".join(libs),
        }

    out_rows = []
    done = 0
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = {pool.submit(process, r): r for r in rows}
        for fut in as_completed(futures):
            out_rows.append(fut.result())
            done += 1
            if done % 25 == 0:
                print(f"  {done}/{len(rows)}", flush=True)

    order = {r["pmcid"]: i for i, r in enumerate(rows)}
    out_rows.sort(key=lambda r: order.get(r["pmcid"], 9999))

    with open(args.out, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(out_rows[0].keys()))
        w.writeheader()
        w.writerows(out_rows)

    ok = sum(1 for r in out_rows if r["fulltext"] == "ok")
    with_code = sum(1 for r in out_rows if r["has_code_section"])
    with_repo = sum(1 for r in out_rows if r["n_code_links"] > 0)
    print(f"wrote {len(out_rows)} rows -> {args.out}")
    print(f"fulltext ok={ok}, code section={with_code}, has repo link={with_repo}")


if __name__ == "__main__":
    main()
