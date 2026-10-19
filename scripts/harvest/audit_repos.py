#!/usr/bin/env python3
"""Audit GitHub repositories linked from the deep-read set.

Shallow, blob-less clones (trees only) keep this cheap: we list every file, then
fetch a few R/Python files to see whether real plotting code is present.

Usage:
    python3 scripts/harvest/audit_repos.py [--workers 5]
"""
from __future__ import annotations

import csv
import os
import re
import shutil
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor, as_completed

PLOT_LIBS = ["ggplot2", "ggplot(", "circlize", "ggtree", "ComplexHeatmap", "pheatmap",
             "matplotlib", "seaborn", "plotly", "ggpubr", "patchwork", "RIdeogram",
             "karyoploteR", "CMplot", "scanpy"]
PLOT_NAME = re.compile(r"(plot|fig|visual|draw|graph|circos|manhattan|pca)", re.I)


def run(cmd: list[str], cwd: str | None = None, timeout: int = 120) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)


def audit(repo: str) -> dict:
    tmp = tempfile.mkdtemp(prefix="repo_")
    out = {"repo": repo, "clone_ok": 0, "n_files": 0, "n_r": 0, "n_py": 0,
           "n_ipynb": 0, "n_shell": 0, "has_license": 0, "license_name": "",
           "plot_lib_hits": "", "plot_named_files": 0, "runnable_plot_code": 0}
    try:
        clone = run(["git", "clone", "--depth", "1", "--filter=blob:none",
                     "--no-checkout", "--quiet", f"https://github.com/{repo}.git", tmp], timeout=150)
        if clone.returncode != 0:
            return out
        out["clone_ok"] = 1
        tree = run(["git", "-C", tmp, "ls-tree", "-r", "--name-only", "HEAD"], timeout=60)
        files = [f for f in tree.stdout.splitlines() if f.strip()]
        out["n_files"] = len(files)
        r_files = [f for f in files if f.endswith((".R", ".r", ".Rmd"))]
        py_files = [f for f in files if f.endswith(".py")]
        nb_files = [f for f in files if f.endswith(".ipynb")]
        sh_files = [f for f in files if f.endswith((".sh", ".bash", ".smk", ".Snakefile"))]
        out["n_r"], out["n_py"], out["n_ipynb"], out["n_shell"] = (
            len(r_files), len(py_files), len(nb_files), len(sh_files))
        lic = [f for f in files if re.match(r"(LICEN[CS]E|COPYING)", os.path.basename(f), re.I)]
        if lic:
            out["has_license"] = 1
            out["license_name"] = lic[0].split("/")[0][:40]
        out["plot_named_files"] = sum(1 for f in r_files + py_files + nb_files
                                      if PLOT_NAME.search(os.path.basename(f)))
        hits: set[str] = set()
        candidates = [f for f in r_files + py_files if PLOT_NAME.search(f)][:4]
        if not candidates:
            candidates = (r_files + py_files)[:3]
        for f in candidates:
            blob = run(["git", "-C", tmp, "show", f"HEAD:{f}"], timeout=60)
            if blob.returncode != 0:
                continue
            text = blob.stdout[:400_000]
            for lib in PLOT_LIBS:
                if lib.lower() in text.lower():
                    hits.add(lib)
        out["plot_lib_hits"] = "|".join(sorted(hits))
        out["runnable_plot_code"] = int(bool(hits) or out["plot_named_files"] > 0)
    except Exception:
        pass
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return out


def main() -> None:
    rows = list(csv.DictReader(open("docs/repo-list.csv", encoding="utf-8")))
    repos = [r["repo"] for r in rows]
    results = []
    with ThreadPoolExecutor(max_workers=5) as pool:
        futs = {pool.submit(audit, r): r for r in repos}
        for n, fut in enumerate(as_completed(futs), 1):
            results.append(fut.result())
            if n % 10 == 0:
                print(f"  {n}/{len(repos)}", flush=True)
    results.sort(key=lambda r: r["repo"])
    with open("docs/repo-audit.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(results[0].keys()))
        w.writeheader()
        w.writerows(results)
    ok = [r for r in results if r["clone_ok"]]
    print(f"repos={len(results)} cloned={len(ok)} "
          f"with_r={sum(1 for r in ok if r['n_r'])} with_py={sum(1 for r in ok if r['n_py'])} "
          f"plot_code={sum(r['runnable_plot_code'] for r in ok)}")


if __name__ == "__main__":
    main()
