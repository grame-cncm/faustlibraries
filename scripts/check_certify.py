#!/usr/bin/env python3
"""Regenerate the Lean certification and compare its verdicts with the committed one.

`make certify` diffs the whole of tests/lean/certified.lean, terms included, so
it fails as soon as a fixture's graph changes shape, even when no verdict moves.
Nothing called it either, and in October 2026 it failed unseen: two library
rewrites had taken 4 stable and 14 index verdicts down to 3 and 13. This script
is the routine form of it, which `make check-doc` runs:

- it regenerates the theorems with scripts/sig2lean.py and kernel-checks them
  (about 10 s);
- it fails when a verdict differs from tests/lean/certified.lean: a theorem's
  `true` or `false`, a theorem added or removed, or a line of the compiler
  clamp oracle (or the oracle's defect, which sig2lean.py fails on);
- it passes when only the terms differ, and says so: `make certify` stays
  strict about them, and `make certify-reference` brings them up to date.

With --changed it does nothing unless a library, tests/lean/, formalisation/
or the generator differs from HEAD (or a file in tests/lean/ is new), and
it reports itself skipped, exit 0, when lean or faust-rs is missing, or when
lean is not the version of formalisation/mathlib/lean-toolchain, which is the
one the prelude is checked with. An updated compiler is not a changed file:
run `make certify` after updating faust-rs.

Environment: FAUST_RS (default faust-rs), LEAN (default lean).

    scripts/check_certify.py              # make check-certify
    scripts/check_certify.py --changed    # what make check-doc runs
"""
import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = "formalisation/signal-import-formal-spec.lean"
TF2S_SPEC = "formalisation/tf2s-stability-formal-spec.lean"
TOOLCHAIN = "formalisation/mathlib/lean-toolchain"
CERTIFIED = "tests/lean/certified.lean"
WATCHED = ["*.lib", "tests/lean", "formalisation", "scripts/sig2lean.py",
           "scripts/check_certify.py"]

THEOREM = re.compile(r"^theorem (\S+) : .* = (true|false) := by decide$", re.M)
ORACLE = re.compile(r"^/-! ## Compiler clamp oracle$(.*?)^-/$", re.M | re.S)
ORACLE_LINE = re.compile(r"^(\S+\.dsp): (.*)$", re.M)


def changed():
    """True when a watched path differs from HEAD, or a file in tests/lean/ is new."""
    run = lambda *cmd: subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True).stdout.split()
    return bool(run("git", "diff", "--name-only", "HEAD", "--", *WATCHED)
                or run("git", "ls-files", "--others", "--exclude-standard", "--", "tests/lean"))


def verdicts(text):
    """The verdicts of a generated file: {theorem: true/false, file.dsp: oracle line}."""
    found = dict(THEOREM.findall(text))
    for section in ORACLE.findall(text):
        found.update(ORACLE_LINE.findall(section))
    return found


def compare(committed, regenerated):
    """One line per verdict that differs."""
    lines = []
    for name in sorted(committed.keys() | regenerated.keys()):
        old, new = committed.get(name), regenerated.get(name)
        if old is None:
            lines.append(f"{name}: new verdict '{new}'")
        elif new is None:
            lines.append(f"{name}: verdict '{old}' gone")
        elif old != new:
            lines.append(f"{name}: '{old}' -> '{new}'")
    return lines


def missing_tool(lean, faust_rs):
    """Why this check cannot run here, or None."""
    for tool in (lean, faust_rs):
        if not shutil.which(tool):
            return f"{tool} not found"
    version = subprocess.run([lean, "--version"], capture_output=True, text=True).stdout
    with open(os.path.join(ROOT, TOOLCHAIN)) as f:
        wanted = f.read().strip().rsplit(":v", 1)[-1]
    if f"version {wanted}," not in version:
        return f"lean is not {wanted}"
    return None


def generate(lean, faust_rs):
    """The regenerated file, kernel-checked: (text, None), or (None, what failed)."""
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "certified.lean")
        env = dict(os.environ, FAUST_RS=faust_rs, FAUST_LIBS=ROOT, LEAN=lean)
        steps = [[lean, TF2S_SPEC],
                 [sys.executable, "scripts/sig2lean.py", TEMPLATE, out,
                  *sorted(glob.glob("tests/lean/*.dsp"))],
                 [lean, out]]
        for cmd in steps:
            r = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True)
            if r.returncode != 0:
                return None, (r.stderr.strip() or r.stdout.strip()
                              or f"{cmd[0]} failed").splitlines()
        with open(out, encoding="utf-8") as f:
            return f.read(), None


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--changed", action="store_true",
                   help="do nothing unless a library, tests/lean/, formalisation/ or the"
                        " generator differs from HEAD, and skip when a tool is missing")
    args = p.parse_args()
    lean = os.environ.get("LEAN", "lean")
    faust_rs = os.environ.get("FAUST_RS", "faust-rs")

    if args.changed and not changed():
        print("[certify] skipped: nothing it reads differs from HEAD")
        return 0
    missing = missing_tool(lean, faust_rs)
    if missing:
        print(f"[certify] not run: {missing}")
        return 0 if args.changed else 2

    text, failure = generate(lean, faust_rs)
    if failure:
        for line in failure:
            print(f"[certify] {line}")
        print("[certify] FAILED: no certification generated")
        return 1
    with open(os.path.join(ROOT, CERTIFIED), encoding="utf-8") as f:
        committed = f.read()
    drift = compare(verdicts(committed), verdicts(text))
    if drift:
        for line in drift:
            print(f"[certify] {line}")
        print(f"[certify] FAILED: {len(drift)} verdict(s) differ from {CERTIFIED}")
        return 1
    print(f"[certify] OK: {len(verdicts(text))} verdicts match {CERTIFIED}")
    if text != committed:
        print("[certify] note: the terms differ, not the verdicts; make certify-reference"
              " brings them up to date")
    return 0


if __name__ == "__main__":
    sys.exit(main())
