#!/usr/bin/env python3
"""Inventory and add the tests of a library, in its doc blocks and in tests/*.dsp.

Every test lives in two places (AGENTS.md, rule 8): first in the `#### Test`
section of the function's doc block in the .lib, then, copied verbatim and
under the same name, in the matching tests/*.dsp. A function whose parameters
are meant to vary at run time has three tests: `name_test` (constant
parameters), `name_slider_test` (parameters from sliders) and
`name_modulated_test` (a parameter modulated at every sample), and a
recursive filter a fourth, `name_jump_test` (a parameter jumping between the
two ends of its range); see doc/docs/contributing.md, section "Constant,
slider, modulated and jump tests".

inventory LIB
    For every documented symbol of LIB, which of the four tests exist, in
    the .lib and in tests/*.dsp. A test present on one side only breaks rule
    8; the inventory lists those first. Whether a function needs the slider
    and modulated variants is a judgement (its parameters must be meant to
    vary at run time): the inventory only reports.

add LIB SPEC.dsp [--tests-file FILE] [--dry-run]
    Insert the tests of SPEC.dsp where they are missing. SPEC.dsp is an
    ordinary Faust file: its `xx = library("...");` lines, its `*_test`
    definitions and any helper definition the tests use (`src = ...;`). It
    compiles as it is, so it can be checked first:

        scripts/check_precision.py SPEC.dsp && scripts/lib_tests.py add filters.lib SPEC.dsp

    Each test belongs to the documented function whose name is the longest
    prefix of the test name (`highpass_plus_lowpass_even_slider_test` belongs
    to `highpass_plus_lowpass_even`, not `highpass`). For each test:

    - in the .lib, it is appended to the `#### Test` section of that
      function's doc block (created before `#### References`, or at the end
      of the block, when there is none), with the imports and helper
      definitions it uses that the section lacks;
    - in tests/*.dsp, it goes after the last test of the same function, in
      the file that holds them, again with the missing imports and helpers;
      a function with no test yet goes to --tests-file, created if needed.

    A test already present on a side is left as it is on that side, so the
    command also copies a test that exists only in tests/*.dsp into the
    .lib. A test name used by another function's file is an error: names are
    unique across tests/*.dsp.

Definitions must fit on one line each (a `with { }` included), the style of
the test files. After `add`: regenerate the references of the new tests
(`make reference`), check them (`make check-precision
PRECISION_ARGS="tests/xx_tests.dsp"`), bump the library version and
regenerate its documentation page (`make -C doc md`).
"""

import argparse
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMPORT_RE = re.compile(r'^\s*([A-Za-z]\w*)\s*=\s*(library|import)\("([^"]+)"\)\s*;')
DEF_RE = re.compile(r"^\s*([A-Za-z_]\w*)\s*=")
TEST_RE = re.compile(r"^\s*([A-Za-z0-9_]+_test)\s*=")
TITLE_RE = re.compile(r"^//[-=]*\s*((?:`\([A-Za-z]+\.\)[A-Za-z0-9_\[\]]+`[,\s]*)+)[-=]*\s*$")
SYMBOL_RE = re.compile(r"`\([A-Za-z]+\.\)([A-Za-z0-9_]+)(?:\[n\])?`")
BLOCK_END_RE = re.compile(r"^//\s*[-=]{5,}\s*$")
FENCE_RE = re.compile(r"^//\s*```\s*$")


# ---------------------------------------------------------------- parsing

class Block:
    """A doc block: its symbols, its line range and its Test section."""

    def __init__(self, title, symbols, end):
        self.title = title      # index of the title line
        self.symbols = symbols
        self.end = end          # index of the closing //---- line (or first non-comment)
        self.test = None        # (index of "#### Test", index of opening ```, of closing ```)
        self.references = None  # index of "#### References", if any


def parse_blocks(lines):
    """The doc blocks of a .lib, in order."""
    blocks = []
    i = 0
    while i < len(lines):
        m = TITLE_RE.match(lines[i])
        if not m:
            i += 1
            continue
        j = i + 1
        while j < len(lines) and lines[j].startswith("//") and not BLOCK_END_RE.match(lines[j]):
            j += 1
        b = Block(i, SYMBOL_RE.findall(m.group(1)), j)
        for k in range(i + 1, j):
            text = lines[k][2:].strip()
            if text == "#### Test":
                opening = next((n for n in range(k + 1, j) if FENCE_RE.match(lines[n])), None)
                closing = next((n for n in range(opening + 1, j) if FENCE_RE.match(lines[n])),
                               None) if opening is not None else None
                if closing is not None:
                    b.test = (k, opening, closing)
            elif text == "#### References":
                b.references = k
        blocks.append(b)
        i = j
    return blocks


def section_defs(lines, start, end, strip_comment):
    """Imports ({env: line}) and definitions ({name: line}) of a range of lines."""
    imports, defs = {}, {}
    for line in lines[start:end]:
        text = line[2:].strip() if strip_comment else line.strip()
        m = IMPORT_RE.match(text)
        if m:
            imports[m.group(1)] = text
            continue
        m = DEF_RE.match(text)
        if m:
            defs[m.group(1)] = text
    return imports, defs


def owner(test, symbols):
    """The documented function a test belongs to: the longest symbol prefix."""
    stem = test[:-len("_test")]
    best = None
    for s in symbols:
        if stem == s or stem.startswith(s + "_"):
            if best is None or len(s) > len(best):
                best = s
    return best


def envs_used(code):
    """The environment prefixes a line uses (`fi.`, `ba.`...)."""
    return set(re.findall(r"(?<![\w.])([A-Za-z]\w*)\.(?=[A-Za-z_])", code))


def names_used(code):
    return set(re.findall(r"(?<![\w.])([A-Za-z_]\w*)(?![\w(])", code))


def read_spec(path):
    imports, helpers, tests = {}, {}, []
    for line in open(path):
        text = line.strip()
        if not text or text.startswith("//"):
            continue
        m = IMPORT_RE.match(text)
        if m:
            imports[m.group(1)] = text
            continue
        m = TEST_RE.match(text)
        if m:
            tests.append((m.group(1), text))
            continue
        m = DEF_RE.match(text)
        if m:
            helpers[m.group(1)] = text
            continue
        sys.exit(f"{path}: cannot read this line (one definition per line): {text}")
    return imports, helpers, tests


def dsp_files():
    return sorted(glob.glob(os.path.join(ROOT, "tests", "*.dsp")))


def dsp_tests():
    """{test name: test file} over tests/*.dsp."""
    found = {}
    for path in dsp_files():
        for line in open(path):
            m = TEST_RE.match(line)
            if m:
                found[m.group(1)] = path
    return found


# ---------------------------------------------------------------- inventory

def inventory(args):
    lines = open(args.lib).read().split("\n")
    blocks = parse_blocks(lines)
    lib_tests = set()
    for b in blocks:
        if b.test:
            _, o, c = b.test
            for line in lines[o + 1:c]:
                m = TEST_RE.match(line[2:].strip())
                if m:
                    lib_tests.add(m.group(1))
    in_dsp = dsp_tests()
    one_side, rows = [], []
    for b in blocks:
        for s in b.symbols:
            cells = []
            for suffix in ("_test", "_slider_test", "_modulated_test", "_jump_test"):
                name = s + suffix
                lib, dsp = name in lib_tests, name in in_dsp
                cells.append("both" if lib and dsp else "lib" if lib else "dsp" if dsp else "-")
                if lib != dsp:
                    one_side.append(f"{name}: only in {'the .lib' if lib else os.path.relpath(in_dsp[name], ROOT)}")
            rows.append((b.title + 1, s, cells))
    if one_side:
        print("Tests on one side only (rule 8):")
        for line in one_side:
            print("  " + line)
        print()
    width = max(len(s) for _, s, _ in rows)
    print(f"{'line':>5}  {'symbol':<{width}}  {'_test':>6}  {'_slider':>7}  {'_modulated':>10}  {'_jump':>5}")
    for line, s, (t, sl, mo, ju) in rows:
        # _jump_test is for recursive filters only: it does not make a symbol "missing"
        if args.missing and "-" not in (t, sl, mo):
            continue
        print(f"{line:>5}  {s:<{width}}  {t:>6}  {sl:>7}  {mo:>10}  {ju:>5}")
    counts = [sum(1 for _, _, c in rows if c[k] == "both") for k in range(4)]
    print(f"\n{len(rows)} symbols; in both places: {counts[0]} _test, {counts[1]} _slider_test, "
          f"{counts[2]} _modulated_test, {counts[3]} _jump_test; {len(one_side)} tests on one side only")
    return 1 if one_side else 0


# ---------------------------------------------------------------- add

def needed(code, helpers):
    """Helper definitions a test uses, transitively, in dependency order."""
    out, todo = [], [code]
    while todo:
        for name in sorted(names_used(todo.pop())):
            if name in helpers and name not in out:
                out.append(name)
                todo.append(helpers[name])
    return list(reversed(out))


def add(args):
    spec_imports, spec_helpers, spec_tests = read_spec(args.spec)
    lines = open(args.lib).read().split("\n")
    blocks = parse_blocks(lines)
    symbols = [s for b in blocks for s in b.symbols]
    by_symbol = {s: b for b in blocks for s in b.symbols}
    in_dsp = dsp_tests()
    lib_prefix = next((env for env, text in spec_imports.items()
                       if os.path.basename(args.lib) in text), None)

    # 1. Resolve every test to its function, and check names.
    plan = []
    for name, code in spec_tests:
        fn = owner(name, symbols)
        if fn is None:
            sys.exit(f"{name}: no documented function of {os.path.basename(args.lib)} "
                     "is a prefix of this name")
        plan.append((name, code, fn))

    # 2. The .lib: per block, append to (or create) its Test section.
    #    Insertions are made from the bottom up so that indices stay valid.
    edits = {}  # block -> list of (name, code)
    for name, code, fn in plan:
        edits.setdefault(by_symbol[fn], []).append((name, code))
    report = []
    for b in sorted(edits, key=lambda b: -b.title):
        if b.test:
            _, o, c = b.test
            imports, defs = section_defs(lines, o + 1, c, True)
        else:
            imports, defs = {}, {}
        new_imports, new_lines = [], []
        for name, code in edits[b]:
            if name in defs:
                continue
            for h in needed(code, spec_helpers):
                if h not in defs:
                    new_lines.append(spec_helpers[h])
                    defs[h] = spec_helpers[h]
            for env in sorted(envs_used(code) | {e for h in needed(code, spec_helpers)
                                                   for e in envs_used(spec_helpers[h])}):
                if env not in imports and env in spec_imports:
                    new_imports.append(spec_imports[env])
                    imports[env] = spec_imports[env]
            new_lines.append(code)
            defs[name] = code
            report.append(f"lib: {name} -> block `{b.symbols[0]}` (line {b.title + 1})")
        if not new_lines:
            continue
        # Imports first: the library under test first, then alphabetical, as
        # in the existing sections.
        new_imports.sort(key=lambda t: (IMPORT_RE.match(t).group(1) != lib_prefix, t))
        if b.test:
            _, o, c = b.test
            last_import = max([n for n in range(o + 1, c)
                               if IMPORT_RE.match(lines[n][2:].strip())], default=o)
            lines[c:c] = ["// " + t for t in new_lines]
            lines[last_import + 1:last_import + 1] = ["// " + t for t in new_imports]
        else:
            at = b.references if b.references is not None else b.end
            section = ["// #### Test", "// ```"] + ["// " + t for t in new_imports + new_lines] + ["// ```", "//"]
            if lines[at - 1].strip() != "//":
                section.insert(0, "//")
            lines[at:at] = section
    if not args.dry_run:
        open(args.lib, "w").write("\n".join(lines))

    # 3. tests/*.dsp: after the last test of the same function.
    files = {}
    for name, code, fn in plan:
        if name in in_dsp:
            if owner(name, symbols) != fn:
                sys.exit(f"{name}: already used in {in_dsp[name]}")
            continue
        # The file of the function's base test; otherwise of another of its
        # tests. Not a file where a name merely starts with the function's
        # (demos_tests.dsp has spectral_tilt_demo_test, a test of dm.).
        if fn + "_test" in in_dsp:
            path = in_dsp[fn + "_test"]
        else:
            homes = sorted(p for t, p in in_dsp.items() if owner(t, symbols) == fn)
            path = homes[0] if homes else args.tests_file
        if path is None:
            sys.exit(f"{name}: `{fn}` has no test in tests/*.dsp yet: give --tests-file")
        files.setdefault(os.path.abspath(path), []).append((name, code, fn))
    for path, items in files.items():
        if os.path.exists(path):
            flines = open(path).read().split("\n")
        else:
            # A new file: its header, then every import its tests use.
            base = os.path.basename(path)
            envs = set()
            for _, code, _ in items:
                envs |= envs_used(code)
                for h in needed(code, spec_helpers):
                    envs |= envs_used(spec_helpers[h])
            flines = (["//" + "-" * 76, f"// {base}", f"// Tests of {os.path.basename(args.lib)}.",
                       "//" + "-" * 76, ""]
                      + sorted(spec_imports[e] for e in envs if e in spec_imports) + [""])
        imports, defs = section_defs(flines, 0, len(flines), False)
        for name, code, fn in items:
            anchor = max([k for k, l in enumerate(flines)
                          if (m := TEST_RE.match(l)) and owner(m.group(1), symbols) == fn],
                         default=None)
            block = []
            for h in needed(code, spec_helpers):
                if h not in defs:
                    block.append(spec_helpers[h])
                    defs[h] = spec_helpers[h]
            block.append(code)
            if anchor is None:
                # At the end of the file; keep the blank line after the imports.
                if flines and flines[-1] == "" and not (len(flines) > 1 and IMPORT_RE.match(flines[-2])):
                    flines.pop()
                flines += block + [""]
            else:
                flines[anchor + 1:anchor + 1] = block
            for env in sorted(envs_used(" ".join(block))):
                if env not in imports and env in spec_imports:
                    last_import = max([k for k, l in enumerate(flines) if IMPORT_RE.match(l)],
                                      default=None)
                    at = last_import + 1 if last_import is not None else 5
                    flines[at:at] = [spec_imports[env]] + ([] if last_import is not None else [""])
                    imports[env] = spec_imports[env]
            report.append(f"dsp: {name} -> {os.path.relpath(path, ROOT)}")
        if not args.dry_run:
            open(path, "w").write("\n".join(flines))

    for line in report:
        print(line)
    print(f"\n{len(report)} insertions{' (dry run: nothing written)' if args.dry_run else ''}")
    return 0


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0],
                                formatter_class=argparse.RawDescriptionHelpFormatter,
                                epilog=__doc__.split("\n", 2)[2])
    sub = p.add_subparsers(dest="cmd", required=True)
    q = sub.add_parser("inventory", help="which tests exist, per documented symbol")
    q.add_argument("lib")
    q.add_argument("--missing", action="store_true", help="only the symbols missing a test")
    q = sub.add_parser("add", help="insert the tests of a spec file where they are missing")
    q.add_argument("lib")
    q.add_argument("spec")
    q.add_argument("--tests-file", help="test file for the functions that have none yet")
    q.add_argument("--dry-run", action="store_true", help="report, write nothing")
    args = p.parse_args()
    return inventory(args) if args.cmd == "inventory" else add(args)


if __name__ == "__main__":
    sys.exit(main())
