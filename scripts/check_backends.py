#!/usr/bin/env python3
"""Compile every regression test for the restricted Faust backends.

Every other check compiles C++ only, yet the libraries are used through
WebAssembly first (the Faust IDE, faustwasm), and through Cmajor, Julia
and others. Those backends accept only a whitelist of foreign functions
(acosh, asinh, atanh, cosh, sinh, tanh, isnan, isinf, copysign), and some
lack a primitive (`soundfile`) or a foreign variable (`count`, read by
`ma.BS`). A library function that calls `ma.cbrt` three levels down
compiles in C++ and passes the whole suite, but not on the web.

This script compiles each test with `faust -lang L` (no C++ compilation,
no render: about 15 s per backend for the whole suite) and compares the
failures with `tests/backend-baseline.json`, the accepted debt: mostly the
tests of the `maths.lib` functions that *are* a non-portable foreign
function (`cbrt_test`, ...). Because it compiles the tests, it follows the
calls through every library, without a list of forbidden names.

    scripts/check_backends.py                    # the backends of the baseline
    scripts/check_backends.py --lang wasm,java   # these backends
    scripts/check_backends.py --changed          # only if a .lib or test differs from HEAD
    scripts/check_backends.py --update-baseline  # record the current debt
    scripts/check_backends.py tests/aanl_tests.dsp ...

It fails (exit status 1) on a test that fails on a backend of the baseline
without being listed there, and on a listed test that now compiles (remove
its entry in the same commit). A backend the baseline does not list is
reported, not checked; one this faust was built without is skipped with a
note. `make checkdoc` runs it with --changed, on WebAssembly only, when
faust is installed. Exit status 2 without faust.

faust looks for libraries in the current directory before the -I ones, so
every compilation runs from the repository root, with -I on it: the
libraries tested are this checkout's.
"""
import argparse
import concurrent.futures as cf
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASELINE = ROOT / "tests" / "backend-baseline.json"
FAUST = os.environ.get("FAUST", "faust")
# A top-level definition `name_test = ...` at the start of a line, as in
# scripts/extract_tests.sh and check_precision.py.
TEST_RE = re.compile(r"^[ \t]*([A-Za-z_][A-Za-z0-9_]*_test)[ \t]*=", re.M)
NOT_BUILT = ("not supported since", "cannot find backend")


def dsp_files(paths):
    if paths:
        return [Path(p).resolve() for p in paths]
    out = subprocess.run(["git", "ls-files", "tests/*.dsp"], cwd=ROOT,
                         capture_output=True, text=True).stdout.split()
    return sorted(ROOT / p for p in out if p.count("/") == 1)


def test_specs(files):
    return [(f, name) for f in files for name in TEST_RE.findall(f.read_text())]


def compile_error(lang, path, name):
    """None when the test compiles for `lang`, else faust's error line."""
    r = subprocess.run([FAUST, "-lang", lang, "-I", str(ROOT), "-pn", name, str(path),
                        "-o", os.devnull], cwd=ROOT, capture_output=True, text=True)
    if r.returncode == 0:
        return None
    lines = [line.strip() for line in r.stderr.splitlines()
             if "ERROR" in line or "ASSERT" in line]
    return (lines or [r.stderr.strip() or "failed"])[0]


def backend_built(lang):
    with tempfile.TemporaryDirectory() as tmp:
        dsp = Path(tmp) / "p.dsp"
        dsp.write_text("process = _;\n")
        r = subprocess.run([FAUST, "-lang", lang, str(dsp), "-o", os.devnull],
                           cwd=ROOT, capture_output=True, text=True)
    return not any(s in r.stderr for s in NOT_BUILT)


def changed():
    """True when a tracked library or test file differs from HEAD."""
    out = subprocess.run(["git", "diff", "--name-only", "HEAD", "--", "*.lib", "tests/*.dsp"],
                         cwd=ROOT, capture_output=True, text=True).stdout.split()
    return bool(out)


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("dsp", nargs="*", help="test files (default: the tracked tests/*.dsp)")
    p.add_argument("--lang", help="comma-separated backends (default: those of the baseline)")
    p.add_argument("--changed", action="store_true",
                   help="do nothing unless a tracked .lib or tests/*.dsp differs from HEAD")
    p.add_argument("--update-baseline", action="store_true",
                   help="record the current failures as accepted debt")
    p.add_argument("-j", "--jobs", type=int, default=os.cpu_count())
    args = p.parse_args()
    if not shutil.which(FAUST):
        print("check_backends: faust not found", file=sys.stderr)
        return 2
    if args.changed and not changed():
        print("check_backends: OK (no library or test changed since HEAD)")
        return 0

    baseline = json.loads(BASELINE.read_text()) if BASELINE.exists() else {}
    langs = args.lang.split(",") if args.lang else sorted(baseline)
    files = dsp_files(args.dsp)
    specs = test_specs(files)
    covered = {name for _, name in specs}

    failures, notes = {}, []
    with cf.ThreadPoolExecutor(args.jobs) as pool:
        for lang in langs:
            if not backend_built(lang):
                notes.append(f"{lang}: skipped, this faust is built without that backend")
                continue
            errors = pool.map(lambda s, lang=lang: compile_error(lang, *s), specs)
            failures[lang] = {name: e for (_, name), e in zip(specs, errors) if e}

    if args.update_baseline:
        new = {lang: dict(sorted(f.items())) for lang, f in failures.items()}
        if args.dsp:  # keep the entries of the files not scanned
            for lang, old in baseline.items():
                kept = {t: e for t, e in old.items() if t not in covered}
                new[lang] = dict(sorted({**kept, **new.get(lang, {})}.items()))
        BASELINE.write_text(json.dumps({**baseline, **new}, indent=1) + "\n")
        print(f"check_backends: baseline updated ({BASELINE.relative_to(ROOT)})")
        return 0

    problems = []
    for lang, failed in failures.items():
        if lang not in baseline:
            for name, e in sorted(failed.items()):
                notes.append(f"{lang} (not checked): {name}: {e}")
            continue
        accepted = baseline[lang]
        problems += [f"{lang}: {name}: {e}" for name, e in sorted(failed.items())
                     if name not in accepted]
        problems += [f"{lang}: {name} now compiles: remove it from {BASELINE.name}"
                     for name in sorted(accepted) if name in covered and name not in failed]

    for line in notes + problems:
        print(f"check_backends: {line}")
    summary = ", ".join(f"{lang} {len(failures[lang])} failed"
                        f"{'' if lang in baseline else ' (not checked)'}"
                        for lang in failures)
    if problems:
        print(f"check_backends: FAILED ({len(problems)} problem(s); {len(specs)} tests: {summary})")
        print("A test that no longer compiles for a backend calls something it rejects"
              " (the error names it): use a portable form, or record deliberate debt"
              f" with --update-baseline in {BASELINE.name}.")
        return 1
    accepted = sum(len(baseline[lang]) for lang in failures if lang in baseline)
    print(f"check_backends: OK ({len(specs)} tests: {summary}; accepted debt: {accepted})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
