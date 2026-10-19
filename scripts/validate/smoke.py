#!/usr/bin/env python3
"""Render every archetype x preset and check the output.

Usage: python3 scripts/validate/smoke.py [--only archetype]
Writes docs/smoke-report.md; exits non-zero if any render fails.
"""
from __future__ import annotations
import argparse, os, subprocess, sys, time
from PIL import Image
import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.chdir(ROOT)

ap = argparse.ArgumentParser()
ap.add_argument("--only", default="")
args = ap.parse_args()

index = yaml.safe_load(open("catalog/index.yaml", encoding="utf-8"))
outdir = "out/smoke"
os.makedirs(outdir, exist_ok=True)

rows, fails = [], 0
t0 = time.time()
for a in index["archetypes"]:
    if args.only and a["id"] != args.only:
        continue
    for preset in a["presets"]:
        out = os.path.join(outdir, f"{a['id']}.{preset}.png")
        cmd = ["Rscript", a["template"], "--data", a["fixture"].rstrip("/"),
               "--style", preset, "--out", out]
        p = subprocess.run(cmd, capture_output=True, text=True)
        ok = p.returncode == 0 and os.path.exists(out) and os.path.getsize(out) > 10_000
        size = os.path.getsize(out) if os.path.exists(out) else 0
        dims = ""
        if ok:
            with Image.open(out) as im:
                dims = f"{im.width}x{im.height}"
        rows.append((a["id"], preset, "ok" if ok else "FAIL", size, dims,
                     "" if ok else (p.stderr.strip().splitlines() or [""])[-1][:160]))
        if not ok:
            fails += 1
        print(f"{'OK  ' if ok else 'FAIL'} {a['id']:22s} {preset:18s} {size:>8d} {dims}")

lines = ["# 冒烟测试报告", "", f"- 组合数：{len(rows)}；通过：{len(rows)-fails}；失败：{fails}",
         f"- 用时：{time.time()-t0:.0f}s", "",
         "| archetype | preset | 状态 | 字节 | 尺寸 | 错误 |", "|---|---|---|---|---|---|"]
for r in rows:
    lines.append("| " + " | ".join(str(x) for x in r) + " |")
open("docs/smoke-report.md", "w", encoding="utf-8").write("\n".join(lines) + "\n")
print(f"\n{len(rows)-fails}/{len(rows)} passed -> docs/smoke-report.md")
sys.exit(1 if fails else 0)
