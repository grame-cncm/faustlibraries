#!/usr/bin/env python3
"""Documentation coverage audit — authoritative version.

For each git-tracked .lib at the repository root, compares top-level
definitions against documentation blocks, handling the conventions the
libraries actually use:

  * multi-function headers   //---`(fi.)tf1`, `(fi.)tf2` and `(fi.)tf3`---
  * generic patterns         //---`(de.)fdelay[N]`---      matches fdelay1..N
  * `library()` / `environment` aliases are not definitions and are excluded
    (otherwise every `ba`, `fi`, `ma` import counts as an undocumented symbol)

Reports, per library: line count, number of definitions, number of doc blocks,
undocumented symbols, coverage, and blocks missing a `#### Usage` section.

Usage:
    scripts/audit2.py [output.json]
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

marker_re = re.compile(r'^//-{3,}[^-].*')                       # doc header line
name_re = re.compile(r'`\(?([a-zA-Z0-9_]+)\.\)?([a-zA-Z0-9_\[\]]+)`')  # `(fi.)name`
bare_re = re.compile(r'`([a-zA-Z0-9_\[\]]+)`')                  # `name`
def_re = re.compile(r'^([a-zA-Z_][a-zA-Z0-9_]*)\s*(\([^)]*\))?\s*=')
alias_re = re.compile(r'^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(library|environment|component)\b')


def matches(pattern, name):
    """`fdelay[N]` matches fdelay1, fdelay2, ... — one doc block, many symbols."""
    if '[' not in pattern:
        return pattern == name
    rx = re.sub(r'\\\[[A-Za-z]+\\\]', r'\\d+', re.escape(pattern))
    return re.fullmatch(rx, name) is not None


results = {}
for lib in libs:
    lines = open(lib, encoding="utf-8", errors="replace").read().split("\n")
    documented, patterns, defs, aliases = set(), set(), set(), set()
    doc_starts = []
    for i, l in enumerate(lines):
        if marker_re.match(l):
            ns = name_re.findall(l)
            got = [n for _, n in ns] or bare_re.findall(l)
            if got:
                doc_starts.append((got, i))
                for g in got:
                    (patterns if '[' in g else documented).add(g)
        if alias_re.match(l):
            aliases.add(alias_re.match(l).group(1))
            continue
        m = def_re.match(l)
        if m:
            defs.add(m.group(1))
    defs -= aliases
    undoc = sorted(d for d in defs
                   if d not in documented and not any(matches(p, d) for p in patterns))

    no_usage, test_only = [], []
    for names, start in doc_starts:
        blk = []
        for l in lines[start + 1:start + 150]:
            if marker_re.match(l):
                break
            if not l.startswith("//") and l.strip():
                break
            blk.append(l)
        b = "\n".join(blk)
        # a block whose prose disappears once the #### Test section is removed
        # is published with a title and a code snippet, and nothing else
        prose = re.split(r'####\s*Test', b)[0]
        if len(re.sub(r'#+ *\w+|[`_*\-/ ]', '', prose).strip()) < 12:
            test_only.append(names[0])
        elif "#### Usage" not in b:
            no_usage.append(names[0])

    results[lib] = dict(n_defs=len(defs), blocks=len(doc_starts),
                        undocumented=undoc, no_usage=no_usage,
                        test_only=test_only, lines=len(lines))

print(f"{'lib':<22}{'lines':>7}{'defs':>6}{'docblk':>7}{'undoc':>7}{'cov%':>6}{'noUsage':>8}{'testOnly':>9}")
for lib, r in sorted(results.items(), key=lambda x: -x[1]['n_defs']):
    cov = 100 * (r['n_defs'] - len(r['undocumented'])) / r['n_defs'] if r['n_defs'] else 0
    print(f"{lib:<22}{r['lines']:>7}{r['n_defs']:>6}{r['blocks']:>7}"
          f"{len(r['undocumented']):>7}{cov:>5.0f}%{len(r['no_usage']):>8}{len(r['test_only']):>9}")

test_only_all = [f"{l}:{n}" for l, r in results.items() for n in r['test_only']]
print(f"\nblocks with no description at all (Test section only): {len(test_only_all)}")
for e in sorted(test_only_all):
    print("   ", e)

if len(sys.argv) > 1:
    with open(sys.argv[1], "w") as f:
        json.dump(results, f, indent=1)
    print(f"\nwrote {sys.argv[1]}")
