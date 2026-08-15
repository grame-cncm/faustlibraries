#!/usr/bin/env python3
"""Documentation coverage audit — naive first pass.

Matches one doc marker per line against top-level definitions. It does NOT
understand multi-function headers (`(fi.)tf1`, `(fi.)tf2` and `(fi.)tf3`),
generic patterns (`(de.)fdelay[N]`), or `library()` aliases, so it reports a
large number of false "undocumented" entries.

Kept for comparison only. Use audit2.py for the authoritative numbers; the
gap between the two outputs is what the marker conventions actually cost a
naive parser.

Usage:
    scripts/audit.py [output.json]
"""
import re
import os
import sys
import json
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

tracked = subprocess.check_output(["git", "ls-files", "*.lib"]).decode().split()
libs = [f for f in tracked if "/" not in f]

# doc function marker: //---------`(pfx.)name`----------
doc_re = re.compile(r'^//-+\s*`?\(?([a-zA-Z0-9_]*)\.?\)?([a-zA-Z0-9_]+)`?\s*-+')
# top-level def: name(...) = ... ;   or name = ...
def_re = re.compile(r'^([a-zA-Z_][a-zA-Z0-9_]*)\s*(\([^)]*\))?\s*=')

results = {}
for lib in libs:
    lines = open(lib, encoding="utf-8", errors="replace").read().split("\n")
    documented, defs, doc_entries = set(), set(), []
    usage_blocks = where_blocks = 0
    for i, l in enumerate(lines):
        m = doc_re.match(l)
        if m:
            documented.add(m.group(2))
            doc_entries.append((m.group(2), i))
        m2 = def_re.match(l)
        if m2:
            defs.add(m2.group(1))
    for name, start in doc_entries:
        blk = []
        for l in lines[start + 1:start + 80]:
            if doc_re.match(l):
                break
            if not l.startswith("//") and l.strip():
                break
            blk.append(l)
        b = "\n".join(blk)
        if "#### Usage" in b:
            usage_blocks += 1
        if re.search(r'where\s*:', b, re.I):
            where_blocks += 1
    results[lib] = dict(
        n_defs=len(defs), n_doc=len(documented),
        undocumented=sorted(defs - documented),
        doc_no_def=sorted(documented - defs),
        usage=usage_blocks, where=where_blocks,
        lines=len(lines),
    )

print(f"{'lib':<22}{'lines':>7}{'defs':>7}{'doc':>6}{'undoc':>7}{'cov%':>7}{'usage':>7}{'orphan':>7}")
tot_d = tot_doc = 0
for lib, r in sorted(results.items(), key=lambda x: -x[1]['n_defs']):
    cov = 100 * r['n_doc'] / r['n_defs'] if r['n_defs'] else 0
    tot_d += r['n_defs']
    tot_doc += r['n_doc']
    print(f"{lib:<22}{r['lines']:>7}{r['n_defs']:>7}{r['n_doc']:>6}"
          f"{len(r['undocumented']):>7}{cov:>6.0f}%{r['usage']:>7}{len(r['doc_no_def']):>7}")
print(f"{'TOTAL':<22}{'':>7}{tot_d:>7}{tot_doc:>6}")

if len(sys.argv) > 1:
    with open(sys.argv[1], "w") as f:
        json.dump(results, f, indent=1)
    print(f"\nwrote {sys.argv[1]}")
