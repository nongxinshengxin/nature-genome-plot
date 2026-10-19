#!/usr/bin/env python3
"""Scaffold a new style for an existing archetype.

Usage:
    python3 scripts/extend/new_style.py circos-landscape duo-tone --label "Duo tone" [--base minimal-editorial] [--dry-run]
"""
import argparse, copy, os, sys
import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.chdir(ROOT)

ap = argparse.ArgumentParser()
ap.add_argument("archetype")
ap.add_argument("style")
ap.add_argument("--label", default="")
ap.add_argument("--base", default="minimal-editorial")
ap.add_argument("--dry-run", action="store_true")
args = ap.parse_args()

idx = yaml.safe_load(open("catalog/index.yaml", encoding="utf-8"))
ids = {a["id"]: a for a in idx["archetypes"]}
if args.archetype not in ids:
    sys.exit(f"unknown archetype: {args.archetype}")

base_path = f"templates/presets/{args.archetype}/{args.base}.yaml"
if not os.path.exists(base_path):
    sys.exit(f"base preset not found: {base_path}")

new_path = f"templates/presets/{args.archetype}/{args.style}.yaml"
card_path = f"catalog/styles/{args.archetype}.{args.style}.yaml"
if os.path.exists(new_path) or os.path.exists(card_path):
    sys.exit(f"style already exists: {args.style}")

preset = yaml.safe_load(open(base_path, encoding="utf-8"))
preset["label"] = args.label or args.style.replace("-", " ").title()

card = {
    "id": f"{args.archetype}.{args.style}",
    "archetype": args.archetype,
    "label": preset["label"],
    "status": "draft",
    "preset": new_path,
    "template": ids[args.archetype]["template"],
    "provenance": {"support_n": 0, "evidence": [], "derivation": "scaffolded, evidence pending"},
    "visual_grammar": {},
    "when_to_use": "",
    "avoid_when": "",
    "pitfalls": [],
    "submission_safe": False,
}
print("would write", new_path)
print("would write", card_path)
print("would register in catalog/archetypes/%s.yaml and catalog/index.yaml" % args.archetype)
if args.dry_run:
    sys.exit(0)

open(new_path, "w", encoding="utf-8").write(yaml.safe_dump(preset, sort_keys=False, allow_unicode=True))
open(card_path, "w", encoding="utf-8").write(yaml.safe_dump(card, sort_keys=False, allow_unicode=True))

arch_path = f"catalog/archetypes/{args.archetype}.yaml"
arch = yaml.safe_load(open(arch_path, encoding="utf-8"))
if args.style not in arch["presets"]:
    arch["presets"].append(args.style)
open(arch_path, "w", encoding="utf-8").write(yaml.safe_dump(arch, sort_keys=False, allow_unicode=True))

for a in idx["archetypes"]:
    if a["id"] == args.archetype and args.style not in a["presets"]:
        a["presets"].append(args.style)
open("catalog/index.yaml", "w", encoding="utf-8").write(yaml.safe_dump(idx, sort_keys=False, allow_unicode=True))

print("\nnext:")
print(f"  1. edit colors/sizes in {new_path}")
print(f"  2. fill evidence (3+ DOIs) in {card_path}")
print(f"  3. Rscript templates/R/{args.archetype}.R --style {args.style} --out /tmp/t.png")
print(f"  4. python3 scripts/validate/smoke.py --only {args.archetype}")
print(f"  5. Rscript scripts/validate/style_audit.R")
