#!/usr/bin/env python3
"""Structural checks for the catalog. Exits non-zero on failure."""
import glob, os, sys, yaml
os.chdir(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

errors=[]; warns=[]
idx=yaml.safe_load(open('catalog/index.yaml',encoding='utf-8'))
arch_files={os.path.basename(p)[:-5] for p in glob.glob('catalog/archetypes/*.yaml')}
idx_ids={a['id'] for a in idx['archetypes']}
if arch_files!=idx_ids: errors.append(f"index mismatch: {arch_files ^ idx_ids}")

for a in idx['archetypes']:
    aid=a['id']
    if not os.path.exists(a['template']): errors.append(f"{aid}: template missing")
    if not os.path.isdir(a['fixture']): errors.append(f"{aid}: fixture dir missing")
    for preset in a['presets']:
        pp=f"templates/presets/{aid}/{preset}.yaml"
        cp=f"catalog/styles/{aid}.{preset}.yaml"
        if not os.path.exists(pp): errors.append(f"{aid}: preset missing {preset}")
        if not os.path.exists(cp): errors.append(f"{aid}: style card missing {preset}")
        else:
            c=yaml.safe_load(open(cp,encoding='utf-8'))
            ev=c.get('provenance',{}).get('evidence',[])
            if len(ev)<3: warns.append(f"{aid}.{preset}: only {len(ev)} evidence items")
            for e in ev:
                if not e.get('doi') or not e.get('figure'): errors.append(f"{aid}.{preset}: evidence incomplete")
print(f"archetypes={len(idx['archetypes'])} cards={len(glob.glob('catalog/styles/*.yaml'))}")
for w in warns: print("WARN", w)
for e in errors: print("ERR ", e)
print("OK" if not errors else f"{len(errors)} errors")
sys.exit(1 if errors else 0)
