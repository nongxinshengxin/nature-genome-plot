#!/usr/bin/env python3
"""Print a one-screen project state, for a fresh session."""
import glob, os, subprocess, sys, yaml

os.chdir(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
idx = yaml.safe_load(open('catalog/index.yaml', encoding='utf-8'))
cards = glob.glob('catalog/styles/*.yaml')
drafts = [c for c in cards if yaml.safe_load(open(c, encoding='utf-8')).get('status') == 'draft']
presets = glob.glob('templates/presets/*/*.yaml')
templates = glob.glob('templates/R/*.R')

print(f"archetypes : {len(idx['archetypes'])}")
print(f"presets    : {len(presets)}")
print(f"cards      : {len(cards)} (draft {len(drafts)})")
print(f"templates  : {len(templates)} R files")
print(f"adapters   : {len(glob.glob('adapters/*.R'))}")
print(f"fixtures   : {len([d for d in glob.glob('fixtures/*') if os.path.isdir(d)])}")
print()
for cmd in (["python3", "scripts/validate/catalog_check.py"],
            ["Rscript", "scripts/doctor.R"]):
    r = subprocess.run(cmd, capture_output=True, text=True)
    print(('OK   ' if r.returncode == 0 else 'FAIL ') + ' '.join(cmd))
print()
print("next: docs/EXTENDING.md  (how to add a template or style)")
print("      docs/todo.md       (known gaps)")
