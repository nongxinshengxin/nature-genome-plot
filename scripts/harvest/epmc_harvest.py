#!/usr/bin/env python3
"""Harvest a 200-paper open-access corpus from Europe PMC.

Queries six journals, keeps OA research articles on genome / pangenome /
population-genomics topics, ranks them, and applies per-journal and per-year
quotas. Writes docs/corpus.csv.

Usage:
    python3 scripts/harvest/epmc_harvest.py [--out docs/corpus.csv]
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import re
import time
import urllib.parse
import urllib.request

BASE = "https://www.ebi.ac.uk/europepmc/webservices/rest/search"

JOURNALS = {
    "Nature": 30,
    "Nature Genetics": 30,
    "Nature Plants": 15,
    "Nature Ecology & Evolution": 15,
    "Nature Microbiology": 20,
    "Nature Communications": 90,
}
YEARS = [2023, 2024, 2025, 2026]

TOPIC = (
    '(TITLE_ABS:genome OR TITLE_ABS:genomic OR TITLE_ABS:pangenome '
    'OR TITLE_ABS:"pan-genome" OR TITLE_ABS:"structural variation" '
    'OR TITLE_ABS:"population genomics" OR TITLE_ABS:admixture '
    'OR TITLE_ABS:GWAS OR TITLE_ABS:introgression OR TITLE_ABS:domestication '
    'OR TITLE_ABS:phylogenomics OR TITLE_ABS:metagenome '
    'OR TITLE_ABS:"horizontal gene transfer")'
)

STRONG = [
    "pangenome", "pan-genome", "genome assembly", "telomere-to-telomere", "t2t",
    "structural variation", "structural variant", "copy number variation",
    "population structure", "population genomics", "admixture", "gwas",
    "genome-wide association", "selective sweep", "selection signature",
    "introgression", "demographic history", "domestication", "phylogenomics",
    "comparative genomics", "genome evolution", "sv", "cnv", "snp",
]
WEAK = ["genome", "genomic", "chromosome", "allele", "variant", "sequencing", "assembly"]

BAD_TITLE = re.compile(
    r"^(author correction|correction|publisher correction|retraction|editorial expression)",
    re.I,
)
BAD_TYPE = {"review", "review-article", "comment", "editorial", "correction", "letter"}


def get_json(url: str, tries: int = 3) -> dict:
    for i in range(tries):
        try:
            with urllib.request.urlopen(url, timeout=45) as fh:
                return json.load(fh)
        except Exception:
            if i == tries - 1:
                raise
            time.sleep(2 * (i + 1))
    raise RuntimeError("unreachable")


def search(journal: str, year: int, cap: int = 100) -> list[dict]:
    q = (
        f'JOURNAL:"{journal}" AND OPEN_ACCESS:y AND PUB_YEAR:[{year} TO {year}] '
        f"AND {TOPIC}"
    )
    out: list[dict] = []
    cursor = "*"
    while len(out) < cap:
        params = {
            "query": q,
            "format": "json",
            "pageSize": 100,
            "resultType": "core",
            "cursorMark": cursor,
        }
        data = get_json(BASE + "?" + urllib.parse.urlencode(params))
        batch = data.get("resultList", {}).get("result", [])
        if not batch:
            break
        out.extend(batch)
        nxt = data.get("nextCursorMark")
        if not nxt or nxt == cursor:
            break
        cursor = nxt
    return out[:cap]


def pub_types(rec: dict) -> set[str]:
    lst = (rec.get("pubTypeList") or {}).get("pubType") or []
    return {str(x).lower() for x in lst}


def score(rec: dict) -> float:
    title = (rec.get("title") or "").lower()
    abstract = (rec.get("abstractText") or "").lower()
    s = 0.0
    for term in STRONG:
        if term in title:
            s += 3
        if title.count(term) > 1:
            s += 1
        if term in abstract:
            s += 1
    for term in WEAK:
        if term in title:
            s += 1
    cites = rec.get("citedByCount") or 0
    s += min(math.log10(1 + cites) * 2, 4)
    if rec.get("firstPublicationDate", "2026") >= "2025-01-01":
        s += 0.5
    return round(s, 2)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="docs/corpus.csv")
    args = ap.parse_args()

    selected: list[dict] = []
    for journal, quota in JOURNALS.items():
        # spread the quota evenly across years, earlier years take the remainder
        base, rem = divmod(quota, len(YEARS))
        year_quota = {y: base + (1 if i < rem else 0) for i, y in enumerate(YEARS)}

        chosen: list[dict] = []
        seen: set[str] = set()
        leftovers: list[dict] = []

        for y in YEARS:
            recs = search(journal, y)
            keep = []
            for r in recs:
                title = (r.get("title") or "").strip()
                doi = r.get("doi") or r.get("id")
                if not title or BAD_TITLE.search(title) or doi in seen:
                    continue
                if pub_types(r) & BAD_TYPE:
                    continue
                if r.get("isOpenAccess") != "Y" or not r.get("pmcid"):
                    continue
                key = r.get("doi") or r.get("id")
                if any((c.get("doi") or c.get("id")) == key for c in chosen):
                    continue
                keep.append(r)
            keep.sort(key=score, reverse=True)
            take = keep[: year_quota[y]]
            for r in take:
                chosen.append(r)
                seen.add(r.get("doi") or r.get("id"))
            leftovers.extend(keep[len(take):])

        if len(chosen) < quota:
            leftovers.sort(key=score, reverse=True)
            for r in leftovers:
                key = r.get("doi") or r.get("id")
                if key in seen:
                    continue
                chosen.append(r)
                seen.add(key)
                if len(chosen) >= quota:
                    break

        years = {y: sum(1 for c in chosen if str(c.get("pubYear")) == str(y)) for y in YEARS}
        print(f"{journal:32s} selected={len(chosen):3d} years={years}")
        for r in chosen:
            selected.append(
                {
                    "journal": journal,
                    "year": r.get("pubYear"),
                    "doi": r.get("doi"),
                    "pmid": r.get("pmid"),
                    "pmcid": r.get("pmcid"),
                    "title": (r.get("title") or "").strip(),
                    "cited_by": r.get("citedByCount") or 0,
                    "score": score(r),
                    "license": r.get("license") or "",
                }
            )

    selected.sort(key=lambda d: (d["journal"], -d["score"]))
    with open(args.out, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(selected[0].keys()))
        w.writeheader()
        w.writerows(selected)
    print(f"\nwrote {len(selected)} rows -> {args.out}")


if __name__ == "__main__":
    main()
