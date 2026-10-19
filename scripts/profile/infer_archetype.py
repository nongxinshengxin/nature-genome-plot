#!/usr/bin/env python3
"""Guess which archetype fits a data file (or directory).

Usage:
    python3 scripts/profile/infer_archetype.py --data fixtures/manhattan-qq/gwas.tsv
    python3 scripts/profile/infer_archetype.py --data path/to/dir --top 3
"""
from __future__ import annotations
import argparse, glob, os, re, sys
import pandas as pd

RULES = {
    "manhattan-qq": {"need": [["chr", "chrom", "chromosome"], ["bp", "pos", "position"], ["p", "pval", "p_value", "pvalue"]]},
    "sv-cnv": {"need": [["chr", "chrom"], ["start", "pos"], ["end"], ["type", "svtype"], ["length", "svlen"], ["af", "freq"]]},
    "linear-tracks": {"need": [["chr", "chrom"], ["start"], ["end"], ["track", "feature"], ["value", "score"]]},
    "synteny": {"need": [["q_chr", "query_chr"], ["q_start", "query_start"], ["q_end", "query_end"],
                          ["t_chr", "target_chr"], ["t_start", "target_start"], ["t_end", "target_end"]]},
    "population-structure": {"need": [["sample", "id", "iid"], ["pc1"], ["pc2"]]},
    "pangenome-composition": {"need": [["genomes", "n_genomes"], ["pan", "pangenome"], ["core"]]},
    "selection-scan": {"need": [["chr", "chrom"], ["start"], ["end"], ["fst"], ["pi"]]},
    "assembly-qc": {"need": [["assembly"], ["class", "category"], ["percent", "pct"]]},
    "demography": {"need": [["frequency", "freq"], ["count"]]},
    "phylogenomics": {"need": []},
    "presence-absence": {"need": []},
    "circos-landscape": {"need": [["chr", "chrom"], ["start"], ["end"]]},
}


def norm(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", str(s).strip().lower()).strip("_")


def load(path: str) -> pd.DataFrame | None:
    try:
        sep = "," if path.lower().endswith(".csv") else "\t"
        return pd.read_csv(path, sep=sep, nrows=5000)
    except Exception:
        return None


def evaluate(df: pd.DataFrame, need: list[list[str]]) -> tuple[float, list[str]]:
    cols = [norm(c) for c in df.columns]
    hit, miss = 0, []
    for group in need:
        found = next((g for g in group if g in cols), None)
        if found:
            hit += 1
        else:
            miss.append("/".join(group))
    return (hit / len(need) if need else 0.0), miss


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True)
    ap.add_argument("--top", type=int, default=3)
    args = ap.parse_args()

    path = args.data
    ext = os.path.splitext(path)[1].lower()
    if ext == ".paf":
        print("1.00  synteny                  (PAF; run adapters/paf2synteny.R)"); return
    if ext in (".vcf", ".bcf"):
        print("0.90  sv-cnv                   (VCF; run adapters/vcf2sv.R)"); return
    if ext in (".gff", ".gff3", ".gtf"):
        print("0.90  linear-tracks            (GFF; run adapters/gff2genes.R)"); return
    if ext in (".nwk", ".treefile", ".newick"):
        print("0.95  phylogenomics            (Newick)"); return
    if os.path.isdir(path):
        files = sorted(glob.glob(os.path.join(path, "*.tsv")) + glob.glob(os.path.join(path, "*.csv")))
        nwk = glob.glob(os.path.join(path, "*.nwk")) or glob.glob(os.path.join(path, "*.treefile"))
        label = os.path.basename(os.path.normpath(path))
        if nwk and files:
            print(f"1.000  phylogenomics        (tree + matrix, missing: -)")
            return
        if not files:
            print("no table found", file=sys.stderr); sys.exit(1)
        path = files[0]
        print(f"[dir: {label}] using {os.path.basename(path)}")

    df = load(path)
    if df is None:
        print(f"cannot read {path}", file=sys.stderr); sys.exit(1)

    results = []
    for aid, spec in RULES.items():
        s, miss = evaluate(df, spec["need"])
        results.append((s, len(spec["need"]), aid, miss))

    # shape heuristics
    cols = [norm(c) for c in df.columns]
    if len(df.columns) > 8:
        binaryish = all(set(df[c].dropna().unique()).issubset({0, 1}) for c in df.columns[1:6])
        if binaryish:
            results.append((0.95, 3, "presence-absence", []))
    if any(c.startswith("k") and c[1:].isdigit() for c in cols):
        results.append((0.95, 3, "population-structure", []))

    results.sort(key=lambda x: (-x[0], -x[1]))
    seen, out = set(), []
    for s, _, aid, miss in results:
        if aid in seen or s == 0:
            continue
        seen.add(aid)
        out.append((s, aid, miss))
        if len(out) >= args.top:
            break

    print(f"file: {os.path.basename(path)}  rows={len(df)}  cols={len(df.columns)}")
    for s, aid, miss in out:
        m = ", ".join(miss) if miss else "-"
        print(f"{s:.2f}  {aid:24s} missing: {m}")


if __name__ == "__main__":
    main()
