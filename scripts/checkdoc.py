#!/usr/bin/env python3
"""Documentation quality gate.

Aggregates the repository's documentation checks and fails on any
regression, without requiring the historical debt to be paid first:

  1. undocumented symbols and Usage-less blocks (scripts/audit2.py) are
     compared against the committed baseline tests/doc-baseline.json:
     a symbol missing documentation is an error unless it was already
     missing when the baseline was recorded;
  2. blocks containing only a #### Test section must not exist at all
     (that class of defect was fully repaired);
  3. doc/docs/standardFunctions.md must match the source markers
     (scripts/build_standard_functions.py --check);
  4. license declarations must be canonical SPDX identifiers
     (scripts/normalize_licenses.py --check);
  5. the LLM-facing JSON export (scripts/build_faust_doc_index.py) must
     still parse every documented symbol: its symbol count may only grow
     against the recorded baseline (a drop means the doc-block format
     drifted away from what the exporter understands).

Usage:
    scripts/checkdoc.py                    # verify, exit 1 on regression
    scripts/checkdoc.py --update-baseline  # record the current debt as accepted

Run it before committing library changes; `make checkdoc` is an alias.
"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
BASELINE = "tests/doc-baseline.json"
PYTHON = sys.executable or "python3"


def run_audit():
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tmp:
        path = tmp.name
    try:
        subprocess.check_output([PYTHON, "scripts/audit2.py", path],
                                stderr=subprocess.STDOUT)
        with open(path) as f:
            return json.load(f)
    finally:
        os.unlink(path)


def doc_index_symbol_count():
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tmp:
        path = tmp.name
    try:
        out = subprocess.check_output(
            [PYTHON, "scripts/build_faust_doc_index.py",
             "--repo-root", ".", "--output", path],
            stderr=subprocess.DEVNULL, text=True)
        return int(json.loads(out.splitlines()[-1])["symbolsCount"])
    finally:
        os.unlink(path)


def current_debt(audit):
    return {
        lib: {
            "undocumented": sorted(entry.get("undocumented", [])),
            "no_usage": sorted(entry.get("no_usage", [])),
        }
        for lib, entry in sorted(audit.items())
        if entry.get("undocumented") or entry.get("no_usage")
    }


def main():
    update = "--update-baseline" in sys.argv
    audit = run_audit()
    debt = current_debt(audit)
    n_index = doc_index_symbol_count()
    debt["_doc_index"] = {"symbols": n_index}

    if update:
        with open(BASELINE, "w") as f:
            json.dump(debt, f, indent=1, sort_keys=True)
            f.write("\n")
        n_undoc = sum(len(v["undocumented"]) for k, v in debt.items()
                      if not k.startswith("_"))
        n_nousage = sum(len(v["no_usage"]) for k, v in debt.items()
                        if not k.startswith("_"))
        print("Wrote %s (%d undocumented symbols, %d Usage-less blocks,"
              " %d exported symbols)." % (BASELINE, n_undoc, n_nousage, n_index))
        return

    errors = []

    # 1. no new undocumented symbols or Usage-less blocks
    if os.path.exists(BASELINE):
        with open(BASELINE) as f:
            baseline = json.load(f)
    else:
        errors.append("%s is missing; run scripts/checkdoc.py --update-baseline"
                      % BASELINE)
        baseline = {}
    floor = baseline.get("_doc_index", {}).get("symbols")
    if floor is not None and n_index < floor:
        errors.append("JSON doc export dropped from %d to %d symbols; the"
                      " exporter no longer parses part of the documentation"
                      % (floor, n_index))

    for lib, entry in debt.items():
        if lib.startswith("_"):
            continue
        for kind, label in (("undocumented", "undocumented symbol"),
                            ("no_usage", "block without #### Usage")):
            accepted = set(baseline.get(lib, {}).get(kind, []))
            for name in entry[kind]:
                if name not in accepted:
                    errors.append("%s: new %s '%s'" % (lib, label, name))

    # 2. test-only blocks: fully repaired, none may come back
    for lib, entry in sorted(audit.items()):
        for name in entry.get("test_only", []):
            errors.append("%s: block for '%s' contains only a #### Test section"
                          % (lib, name))

    # 3. standardFunctions.md in sync with the source markers
    r = subprocess.run([PYTHON, "scripts/build_standard_functions.py", "--check"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        errors.append((r.stderr.strip() or r.stdout.strip()
                       or "standardFunctions.md is out of date"))

    # 4. canonical license declarations
    r = subprocess.run([PYTHON, "scripts/normalize_licenses.py", "--check"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        for line in (r.stdout.strip() or r.stderr.strip()).splitlines():
            errors.append(line)

    if errors:
        for e in errors:
            print("checkdoc: %s" % e)
        print("checkdoc: FAILED (%d problem(s))." % len(errors))
        print("If a reported symbol is deliberate accepted debt, rerun with"
              " --update-baseline and commit %s." % BASELINE)
        sys.exit(1)
    n_undoc = sum(len(v["undocumented"]) for k, v in debt.items()
                  if not k.startswith("_"))
    print("checkdoc: OK (accepted debt: %d undocumented symbols, no new gaps,"
          " %d exported symbols)." % (n_undoc, n_index))


if __name__ == "__main__":
    main()
