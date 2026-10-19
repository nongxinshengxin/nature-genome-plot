#!/usr/bin/env python3
"""Scaffold a new archetype (template + contract + fixture + registry entry).

Usage:
    python3 scripts/extend/new_archetype.py heatmap-tracks --label "热图轨道" [--implementation ggplot2] [--dry-run]
"""
import argparse, os, sys
import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.chdir(ROOT)

ap = argparse.ArgumentParser()
ap.add_argument("id")
ap.add_argument("--label", default="")
ap.add_argument("--implementation", default="ggplot2")
ap.add_argument("--dry-run", action="store_true")
args = ap.parse_args()

aid = args.id
paths = {
    "contract": f"catalog/archetypes/{aid}.yaml",
    "template": f"templates/R/{aid}.R",
    "fixture": f"fixtures/{aid}/README.md",
}
for p in paths.values():
    if os.path.exists(p):
        sys.exit(f"already exists: {p}")

contract = {
    "id": aid, "label": args.label or aid, "status": "scaffold",
    "implementation": args.implementation, "structures": ["TODO"],
    "why": "TODO: one sentence on what question this figure answers",
    "inputs": {"TODO": "{file: data.tsv, columns: {TODO}}"},
    "presets": [], "rules": ["TODO"], "fixtures": f"fixtures/{aid}/",
    "template": f"templates/R/{aid}.R", "tests": "pending",
}

template = f'''#!/usr/bin/env Rscript
# {aid}.R — TODO: describe the figure
#
# Contract: catalog/archetypes/{aid}.yaml
# Presets:  templates/presets/{aid}/
stop("template {aid} is still a scaffold: implement the plotting code first")
'''

print("would write:", ", ".join(paths.values()))
print("would register in catalog/index.yaml")
if args.dry_run:
    sys.exit(0)

os.makedirs(f"fixtures/{aid}", exist_ok=True)
open(paths["contract"], "w", encoding="utf-8").write(yaml.safe_dump(contract, sort_keys=False, allow_unicode=True))
open(paths["template"], "w", encoding="utf-8").write(template)
open(paths["fixture"], "w", encoding="utf-8").write(f"# {aid} fixture\n\n字段说明放这里。\n")
os.makedirs(f"templates/presets/{aid}", exist_ok=True)

idx = yaml.safe_load(open("catalog/index.yaml", encoding="utf-8"))
idx["archetypes"].append({
    "id": aid, "label": contract["label"], "implementation": args.implementation,
    "structures": ["TODO"], "presets": [], "fixture": f"fixtures/{aid}/",
    "template": f"templates/R/{aid}.R", "summary": contract["why"][:120],
})
open("catalog/index.yaml", "w", encoding="utf-8").write(yaml.safe_dump(idx, sort_keys=False, allow_unicode=True))

print("\nnext:")
print(f"  1. fill inputs/rules in {paths['contract']}")
print(f"  2. implement {paths['template']}")
print(f"  3. add fixtures + a preset: python3 scripts/extend/new_style.py {aid} minimal-editorial")
print("  4. python3 scripts/validate/catalog_check.py && python3 scripts/validate/smoke.py --only " + aid)
