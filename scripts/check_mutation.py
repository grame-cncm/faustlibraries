#!/usr/bin/env python3
"""Measure what the regression tests detect: small faults injected in the libraries.

`make check` says that nothing moved, `make check-weak` that a reference holds
information. Neither says whether the suite would see a bug. This script
writes one into a copy of a library, one at a time, and runs the tests that
reach it against tests/reference/, as `make check` does (-double, 48 kHz,
tolerance FLOAT_TOL). The sample is drawn with a fixed seed, so two runs
measure the same faults.

Mutation operators, applied to the code of the top-level definitions (never
to comments, strings, `declare`, `waveform` tables, the numbers of sliders or
foreign functions):

- num: a number moved, 0.7 -> 0.707, 3 -> 4: a pole, a constant, an index;
- sign: `+` <-> `-`;
- muldiv: `*` <-> `/`;
- cmp: `<` <-> `<=`, `>` <-> `>=`, `==` <-> `!=`;
- func: `min` <-> `max`, `floor` <-> `ceil`;
- delay: `x'` -> `x`, `@(d)` -> `@(1+d)`: one sample too few or too many.

Each mutant ends in one of these states:

- killed: a test fails, or crashes, or does not end;
- survived: the generated code of a test changed, and every such test still
  matches its reference: the suite runs the fault and does not see it;
- unreached: no candidate test compiles to other code: the fault sits in
  code no test runs, or it changes nothing (an equivalent mutant);
- invalid: faust refuses the mutant in every test, or does not end: not a
  fault, it does not count. A mutant only some tests refuse is killed: make
  check stops on it.

`make check` runs in -double: the definitions of the other precisions
(`singleprecision x = ...`) are not mutated.

The score is killed / (killed + survived + unreached). The unreached mutants
stay in the denominator: most are code without a test, and telling them from
equivalent ones takes a reader. --list-survivors prints what remains for one.

The candidates of a mutant come from a static call graph of the libraries and
test files (names, `xx.name` through the `library()` aliases), which is an
over-approximation: the tests of the library's own file come first, then the
others. A candidate is compiled first, and only rendered if its C++ differs
from that of the intact libraries. --max-compare and --max-render bound the
work per mutant; a mutant that hits a bound says so in the report.

Tests run from a mirror of the libraries (symbolic links, the mutated file a
real copy) in tests/build-mutation/, one per worker, so the working tree is
never touched. The C++ of the intact tests is cached there and redone when a
library or a test file is newer. The script reports and has no baseline: it
fails only on a broken harness (a test that does not match its reference on
the intact libraries, with --self-check).

    scripts/check_mutation.py --list                  # what would be mutated
    scripts/check_mutation.py -n 20                   # 20 mutants per library
    scripts/check_mutation.py --lib filters.lib -n 50 --seed 2
    scripts/check_mutation.py --lib tonestacks.lib --def twin --op num
    scripts/check_mutation.py -n 20 --json report.json --list-survivors
"""
import argparse
import collections
import concurrent.futures as cf
import json
import os
import queue
import random
import re
import shutil
import subprocess
import sys
import threading
import time
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import build_faust_doc_index as bfdi  # noqa: E402

BUILD_DIR = os.path.join(ROOT, "tests", "build-mutation")
REF_DIR = os.path.join(ROOT, "tests", "reference")
ARCH = os.path.join(ROOT, "arch", "print_arch.cpp")
FLOATDIFF = os.path.join(ROOT, "scripts", "floatdiff.py")
OPERATORS = ("num", "sign", "muldiv", "cmp", "func", "delay")
NUM_SAMPLES, SAMPLE_RATE = "48000", "48000"

IDENT = r"[A-Za-z_]\w*"
NUMBER_RE = re.compile(r"(?<![\w.])\d+\.?\d*(?:[eE][-+]?\d+)?(?![\w.])|(?<![\w.])\.\d+(?:[eE][-+]?\d+)?(?![\w.])")
# The numbers, the strings and the code of these are not faults of the DSP.
MASKED_CALL_RE = re.compile(r"\b(hslider|vslider|nentry|hbargraph|vbargraph|ffunction|fconstant|fvariable|soundfile)\s*\(")
WAVEFORM_RE = re.compile(r"\bwaveform\s*\{[^}]*\}")
ALIAS_RE = re.compile(rf'({IDENT})\s*=\s*library\s*\(\s*"([^"]+)"\s*\)')
IMPORT_RE = re.compile(r'import\s*\(\s*"([^"]+)"\s*\)')
TOKEN_RE = re.compile(rf"({IDENT})(?:\.({IDENT}))?")
CMP_RE = re.compile(r"(?<![<:=!>])<(?![:<=])|(?<![<:=!>])>(?![>=])|<=|>=|==|!=")
CMP_SWAP = {"<": "<=", "<=": "<", ">": ">=", ">=": ">", "==": "!=", "!=": "=="}
FUNC_SWAP = {"min": "max", "max": "min", "floor": "ceil", "ceil": "floor"}
FUNC_RE = re.compile(r"(?<![\w.])(min|max|floor|ceil)(?!\w)")
DELAY_CALL_RE = re.compile(r"@\s*(\(|[\w.]+)")


# ---------------------------------------------------------------- parsing

def blank(text):
    """text with comments and strings replaced by spaces, offsets unchanged."""
    out = list(text)
    i, n = 0, len(text)
    while i < n:
        two = text[i:i + 2]
        if two == "//":
            j = text.find("\n", i)
            j = n if j < 0 else j
        elif two == "/*":
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
        elif text[i] == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            j += 1
        else:
            i += 1
            continue
        for k in range(i, min(j, n)):
            if out[k] != "\n":
                out[k] = " "
        i = j
    return "".join(out)


def statements(code):
    """The top-level statements of blanked code: (start, end) of each."""
    depth, start, spans = 0, 0, []
    for i, c in enumerate(code):
        if c in "({[":
            depth += 1
        elif c in ")}]":
            depth -= 1
        elif c == ";" and depth == 0:
            spans.append((start, i))
            start = i + 1
    return spans


def split_definition(code, start, end):
    """(name, offset just after the `=`) of a statement, None if it defines nothing."""
    text = code[start:end]
    head = text.lstrip()
    if not head or re.match(r"(declare|import)\b", head):
        return None
    # `make check` runs in -double: `singleprecision MAX = ...` is another program.
    if re.match(r"(singleprecision|quadprecision|fixedpointprecision)\b", head):
        return None
    head = re.sub(r"^doubleprecision\s+(quadprecision\s+)?", "", head)
    depth = 0
    for i, c in enumerate(text):
        if c in "({[":
            depth += 1
        elif c in ")}]":
            depth -= 1
        elif c == "=" and depth == 0:
            if text[i + 1:i + 2] == "=" or text[i - 1:i] in ("=", "<", ">", "!"):
                continue
            m = re.match(IDENT, head)
            return (m.group(0), start + i + 1) if m else None
    return None


def masked(code, start, end):
    """The (start, end) ranges of [start, end) where nothing is mutated."""
    ranges = [m.span() for m in WAVEFORM_RE.finditer(code, start, end)]
    for m in MASKED_CALL_RE.finditer(code, start, end):
        depth, i = 1, m.end()
        while i < end and depth:
            depth += {"(": 1, ")": -1}.get(code[i], 0)
            i += 1
        ranges.append((m.start(), i))
    return ranges


def neighbours(code, i):
    """The previous and the next non-space characters around offset i."""
    p = i - 1
    while p >= 0 and code[p].isspace():
        p -= 1
    n = i + 1
    while n < len(code) and code[n].isspace():
        n += 1
    return code[p] if p >= 0 else "", code[n] if n < len(code) else ""


def is_operator(code, i):
    """Whether the arithmetic character at i is a binary operator or a section.

    `(-1)` and `,-1` are negative numbers, not subtractions.
    """
    prev, nxt = neighbours(code, i)
    if prev in ("(", ",", "=", "{") and (nxt.isalnum() or nxt in "._"):
        return False
    return prev.isalnum() or prev in "_)]':(,=~"


def moved_number(token):
    """The number after a num mutation, in the same kind (int or float)."""
    if re.fullmatch(r"\d+", token):
        return str(int(token) + 1)
    value = float(token)
    moved = f"{value * 1.01 if value else 0.01:.12g}"
    return moved if re.search(r"[.e]", moved) else moved + ".0"


def sites(code, start, end):
    """The mutation sites of a definition: (operator, offset, length, replacement)."""
    found = []
    for m in NUMBER_RE.finditer(code, start, end):
        found.append(("num", m.start(), len(m.group(0)), moved_number(m.group(0))))
    for i in range(start, end):
        c = code[i]
        if c in "+-" and not re.match(r"\d[eE]$", code[max(0, i - 2):i]) and is_operator(code, i):
            found.append(("sign", i, 1, "-" if c == "+" else "+"))
        elif c in "*/" and is_operator(code, i):
            found.append(("muldiv", i, 1, "/" if c == "*" else "*"))
        elif c == "'" and (code[i - 1].isalnum() or code[i - 1] in "_)"):
            found.append(("delay", i, 1, ""))
    for m in CMP_RE.finditer(code, start, end):
        found.append(("cmp", m.start(), len(m.group(0)), CMP_SWAP[m.group(0)]))
    for m in FUNC_RE.finditer(code, start, end):
        found.append(("func", m.start(), len(m.group(0)), FUNC_SWAP[m.group(0)]))
    for m in DELAY_CALL_RE.finditer(code, start, end):
        if m.group(1) == "(":
            found.append(("delay", m.end(), 0, "1+"))
        else:
            found.append(("delay", m.start(1), len(m.group(1)), f"(1+{m.group(1)})"))
    masks = masked(code, start, end)
    return [s for s in found if not any(a <= s[1] < b for a, b in masks)]


class Source:
    """A parsed .lib or .dsp file: its definitions, aliases and imports."""

    def __init__(self, path):
        self.path = path
        self.text = open(path, encoding="utf-8").read()
        self.code = blank(self.text)
        raw = re.sub(r"/\*.*?\*/", "", self.text, flags=re.S)
        raw = "\n".join(line.split("//")[0] for line in raw.splitlines())
        self.aliases = {a: os.path.basename(f) for a, f in ALIAS_RE.findall(raw)}
        self.imports = [os.path.basename(f) for f in IMPORT_RE.findall(raw)]
        self.definitions = collections.defaultdict(list)    # name -> [(start, body, end)]
        for start, end in statements(self.code):
            d = split_definition(self.code, start, end)
            if d:
                self.definitions[d[0]].append((start, d[1], end))

    def line(self, offset):
        return self.text.count("\n", 0, offset) + 1

    def tokens(self, name):
        """The names a definition uses, ("alias", "name") or (None, "name")."""
        found = set()
        for _, body, end in self.definitions[name]:
            for a, b in TOKEN_RE.findall(self.code[body:end]):
                if b:
                    found.add((a, b))
                found.add((None, a))
        return found


class Graph:
    """Which definitions use which, by names: nodes are (file, definition)."""

    def __init__(self, sources):
        self.sources = sources      # file name -> Source
        self.users = collections.defaultdict(set)
        self.scopes = {}
        for s in sources.values():
            aliases = self.aliases(s)
            for name in s.definitions:
                node = (os.path.basename(s.path), name)
                for a, b in s.tokens(name):
                    for target in self.targets(s, aliases, a, b):
                        self.users[target].add(node)

    def visible(self, source):
        if source.path not in self.scopes:
            names = [source]
            for s in names:
                if os.path.basename(s.path) != "stdfaust.lib":
                    names += [self.sources[f] for f in s.imports if f in self.sources and self.sources[f] not in names]
            self.scopes[source.path] = names
        return self.scopes[source.path]

    def aliases(self, source):
        table = {}
        for s in self.visible(source):
            table.update(s.aliases)
        return table

    def targets(self, source, aliases, a, b):
        """The nodes a name stands for in source."""
        if a is None:
            scope = self.visible(source)
        elif aliases.get(a) in self.sources:
            scope = self.visible(self.sources[aliases[a]])
        else:
            return []
        return [(os.path.basename(v.path), b) for v in scope if b in v.definitions]

    def reaching(self, node):
        """Every node from which node may be reached."""
        todo, seen = [node], {node}
        while todo:
            for user in self.users[todo.pop()]:
                if user not in seen:
                    seen.add(user)
                    todo.append(user)
        return seen


# ---------------------------------------------------------------- the sample

def library_files():
    """The libraries of the export, repository-relative."""
    bfdi.warn = lambda message: None
    index = bfdi.build_index(bfdi.Path(ROOT), bfdi.Path(ROOT) / "stdfaust.lib")
    return sorted(lib["path"] for lib in index["libraries"])


def all_sites(path, source, defs=None, ops=None):
    """Every mutation site of a library, with its definition and line."""
    result = []
    for name, spans in source.definitions.items():
        if defs and name not in defs:
            continue
        for _, body, end in spans:
            for op, offset, length, new in sites(source.code, body, end):
                if ops and op not in ops:
                    continue
                result.append({
                    "lib": path, "definition": name, "op": op, "offset": offset, "length": length,
                    "old": source.text[offset:offset + length], "new": new, "line": source.line(offset),
                })
    return sorted(result, key=lambda s: (s["offset"], s["op"]))


def draw(candidates, n, rng):
    """n sites of a library: operators and definitions as evenly as they come."""
    pool = candidates[:]
    rng.shuffle(pool)
    by_op, by_def, chosen = collections.Counter(), collections.Counter(), []
    while pool and len(chosen) < n:
        site = min(pool, key=lambda s: (by_op[s["op"]], by_def[s["definition"]]))
        pool.remove(site)
        chosen.append(site)
        by_op[site["op"]] += 1
        by_def[site["definition"]] += 1
    return chosen


# ---------------------------------------------------------------- running

def test_specs():
    """{test: file} of the tests tracked by git."""
    files = subprocess.run(["git", "ls-files", "tests/*.dsp"], capture_output=True, text=True, cwd=ROOT).stdout.split()
    out = subprocess.run([os.path.join(ROOT, "scripts", "extract_tests.sh")] + files,
                         capture_output=True, text=True, cwd=ROOT).stdout
    return {line.split(":")[1]: line.split(":")[0] for line in out.split()}


def mirror(directory, files):
    """A view of the libraries by symbolic links, in which a file can be replaced."""
    shutil.rmtree(directory, ignore_errors=True)
    os.makedirs(directory)
    for path in files:
        target = os.path.join(directory, path)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        os.symlink(os.path.join(ROOT, path), target)
    os.symlink(os.path.join(ROOT, "tests"), os.path.join(directory, "tests"))


def normal(cpp, directory):
    """Generated C++ without what depends on the directory it was compiled in."""
    return re.sub(r'.*(library_path|filename|compile_options).*\n', "", cpp.replace(directory, "LIB"))


def faust_cpp(faust, directory, test, dsp, output, arch=None, timeout=120):
    """Compile a test against a mirror: the return code, None when it does not end."""
    cmd = [faust, "-double", "-t", "0", "-I", directory, "-I", os.path.join(directory, "dx7")]
    cmd += ["-a", arch] if arch else []
    cmd += ["-pn", test, os.path.join(ROOT, dsp), "-o", output]
    try:
        return subprocess.run(cmd, capture_output=True, cwd=directory, timeout=timeout).returncode
    except subprocess.TimeoutExpired:
        return None


def base_cpp(args, test, dsp):
    """The C++ of a test on the intact libraries, cached."""
    path = os.path.join(args.base_cpp, test + ".cpp")
    if not (os.path.exists(path) and os.path.getmtime(path) >= args.newest):
        partial = f"{path}.{threading.get_ident()}"     # two workers can ask for the same test
        if faust_cpp(args.faust, args.base, test, dsp, partial) != 0:
            return None
        os.replace(partial, path)
    return normal(open(path, encoding="utf-8", errors="replace").read(), args.base)


def render(args, directory, test, dsp, work):
    """True when the test on this mirror matches its reference."""
    cpp, exe, out = (os.path.join(work, test + e) for e in (".arch.cpp", "", ".out"))
    if faust_cpp(args.faust, directory, test, dsp, cpp, arch=ARCH) != 0:
        return False
    build = subprocess.run([args.cxx, "-O2", "-std=c++17", cpp, "-o", exe], capture_output=True, cwd=ROOT)
    if build.returncode != 0:
        return False
    try:
        with open(out, "w") as f:
            run = subprocess.run([exe, NUM_SAMPLES, SAMPLE_RATE], stdout=f, stderr=subprocess.DEVNULL,
                                 cwd=ROOT, timeout=args.timeout)
    except subprocess.TimeoutExpired:
        return False
    if run.returncode != 0:
        return False
    same = subprocess.run([sys.executable, FLOATDIFF, os.path.join(REF_DIR, test + ".ref"), out, args.tol],
                          stdout=subprocess.DEVNULL).returncode == 0
    for f in (cpp, exe, out):
        if os.path.exists(f):
            os.remove(f)
    return same


def run_mutant(site, args, workers):
    """Try one mutant: its state, and what was run."""
    directory = workers.get()
    work = directory + "-work"
    result = dict(site, state="unreached", test=None, compared=0, rendered=0, capped=False)
    target = os.path.join(directory, site["lib"])
    try:
        text = args.sources[site["lib"]].text
        mutated = text[:site["offset"]] + site["new"] + text[site["offset"] + site["length"]:]
        os.remove(target)
        with open(target, "w", encoding="utf-8") as f:
            f.write(mutated)
        os.makedirs(work, exist_ok=True)
        tests = args.candidates(site)
        result["candidates"] = len(tests)
        refused = 0
        for test in tests:
            if result["compared"] >= args.max_compare or result["rendered"] >= args.max_render:
                result["capped"] = True
                break
            dsp = args.specs[test]
            base = base_cpp(args, test, dsp)
            if base is None:
                continue
            cpp = os.path.join(work, test + ".cpp")
            code = faust_cpp(args.faust, directory, test, dsp, cpp)
            result["compared"] += 1
            if code is None:        # faust does not end on this mutant
                result["state"] = "invalid"
                break
            if code != 0:
                refused += 1
                continue
            changed = normal(open(cpp, encoding="utf-8", errors="replace").read(), directory) != base
            os.remove(cpp)
            if not changed:
                continue
            result["rendered"] += 1
            result["state"] = "survived"
            if not render(args, directory, test, dsp, work):
                result["state"], result["test"] = "killed", test
                break
        if refused and result["state"] != "invalid":
            # Refused everywhere: not a fault. Refused by a test only: make check stops on it.
            result["state"] = "invalid" if refused == result["compared"] else "killed"
    finally:
        os.remove(target)
        os.symlink(os.path.join(ROOT, site["lib"]), target)
        shutil.rmtree(work, ignore_errors=True)
        workers.put(directory)
    return result


def make_candidates(args, graph):
    """site -> the tests that may reach it, those of the function and of its library first."""
    known = {(os.path.basename(dsp), test): test for test, dsp in args.specs.items()}
    cache = {}

    def candidates(site):
        file, name = os.path.basename(site["lib"]), site["definition"]
        stem = site["lib"].split("/")[0].split(".")[0]      # dx7/lfo.lib: tests/dx7_tests.dsp
        if (file, name) not in cache:
            cache[file, name] = [known[n] for n in graph.reaching((file, name)) if n in known]

        def rank(test):
            own = os.path.basename(args.specs[test]).startswith(stem)
            # A hash, not the name: thirty tests in a row of one family see the same thing.
            return (name not in test, not own, zlib.crc32(test.encode()))

        return sorted(cache[file, name], key=rank)

    return candidates


def uncovered(args, graph):
    """The documented symbols from which no test can be reached."""
    tests = {(os.path.basename(dsp), test) for test, dsp in args.specs.items()}
    index = bfdi.build_index(bfdi.Path(ROOT), bfdi.Path(ROOT) / "stdfaust.lib")
    total, missing = 0, []
    for sym in index["symbols"]:
        file, name = sym["source"]["file"], sym["name"]
        if name not in graph.sources[file].definitions:
            continue
        total += 1
        if not graph.reaching((file, name)) & tests:
            missing.append(sym["qualifiedName"])
    print("\n".join(missing))
    print(f"\n{len(missing)} of {total} documented symbols are reached by no test")
    return 0


def summarize(results):
    """The table of a run, by library and by operator."""
    def line(label, rows):
        c = collections.Counter(r["state"] for r in rows)
        total = c["killed"] + c["survived"] + c["unreached"]
        score = f"{100 * c['killed'] / total:5.1f}%" if total else "    -"
        return (f"{label:<24} {len(rows):5d} {c['killed']:7d} {c['survived']:9d} "
                f"{c['unreached']:10d} {c['invalid']:8d} {score:>7}")

    print(f"{'':<24} {'all':>5} {'killed':>7} {'survived':>9} {'unreached':>10} {'invalid':>8} {'score':>7}")
    for lib in sorted({r["lib"] for r in results}):
        print(line(lib, [r for r in results if r["lib"] == lib]))
    print()
    for op in OPERATORS:
        print(line(op, [r for r in results if r["op"] == op]))
    print()
    print(line("all", results))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--lib", action="append", help="library to mutate (repeatable; default all of the export)")
    p.add_argument("--def", dest="defs", action="append", help="definition to mutate (repeatable)")
    p.add_argument("--op", dest="ops", action="append", choices=OPERATORS, help="operator (repeatable)")
    p.add_argument("-n", type=int, default=10, help="mutants per library (default 10)")
    p.add_argument("--seed", type=int, default=1, help="seed of the sample (default 1)")
    p.add_argument("--jobs", type=int, default=os.cpu_count() or 4, help="mutants run at the same time")
    p.add_argument("--max-compare", type=int, default=200, help="candidate tests compiled per mutant")
    p.add_argument("--max-render", type=int, default=40, help="tests rendered per mutant")
    p.add_argument("--timeout", type=float, default=60, help="seconds a render may take")
    p.add_argument("--tol", default=os.environ.get("FLOAT_TOL", "1e-5"), help="tolerance, as make check")
    p.add_argument("--json", help="write every result to this file")
    p.add_argument("--list", action="store_true", help="print the sample and stop")
    p.add_argument("--list-survivors", action="store_true", help="print the mutants not killed")
    p.add_argument("--uncovered", action="store_true",
                   help="print the documented symbols no test reaches in the call graph, and stop")
    p.add_argument("--self-check", type=int, default=0, metavar="N",
                   help="first render N intact tests through the mirror: they must match their reference")
    args = p.parse_args()
    args.faust = os.environ.get("FAUST", "faust")
    args.cxx = os.environ.get("CXX", "c++")

    every_file = subprocess.run(["git", "ls-files", "*.lib"], capture_output=True, text=True, cwd=ROOT).stdout.split()
    libs = library_files()
    selected = [f for f in libs if not args.lib or f in args.lib or os.path.basename(f) in args.lib]
    if args.lib and not selected:
        sys.exit(f"check_mutation: not in the export: {args.lib}")
    args.sources = {f: Source(os.path.join(ROOT, f)) for f in libs}
    by_name = {os.path.basename(f): s for f, s in args.sources.items()}
    by_name.update({os.path.basename(f): Source(os.path.join(ROOT, f)) for f in every_file
                    if os.path.basename(f) not in by_name})

    sample = []
    for f in selected:
        rng = random.Random(f"{args.seed}:{f}")
        sample += draw(all_sites(f, args.sources[f], args.defs, args.ops), args.n, rng)
    if args.list:
        for s in sample:
            print(f"{s['lib']}:{s['line']}: {s['definition']}: {s['op']}: {s['old']!r} -> {s['new']!r}")
        print(f"{len(sample)} mutants")
        return 0
    if not sample:
        sys.exit("check_mutation: nothing to mutate")

    args.specs = test_specs()
    for dsp in sorted(set(args.specs.values())):
        by_name[os.path.basename(dsp)] = Source(os.path.join(ROOT, dsp))
    graph = Graph(by_name)
    args.candidates = make_candidates(args, graph)
    if args.uncovered:
        return uncovered(args, graph)

    os.makedirs(BUILD_DIR, exist_ok=True)
    args.base = os.path.join(BUILD_DIR, "base")
    args.base_cpp = os.path.join(BUILD_DIR, "cpp")
    os.makedirs(args.base_cpp, exist_ok=True)
    mirror(args.base, every_file)
    args.newest = max(os.path.getmtime(os.path.join(ROOT, f)) for f in every_file + sorted(set(args.specs.values())))

    workers = queue.Queue()
    for k in range(args.jobs):
        directory = os.path.join(BUILD_DIR, f"w{k}")
        mirror(directory, every_file)
        workers.put(directory)

    if args.self_check:
        tests = random.Random(args.seed).sample(sorted(args.specs), args.self_check)
        work = args.base + "-work"
        os.makedirs(work, exist_ok=True)
        with cf.ThreadPoolExecutor(args.jobs) as pool:
            ok = list(pool.map(lambda t: render(args, args.base, t, args.specs[t], work), tests))
        wrong = [t for t, good in zip(tests, ok) if not good]
        if wrong:
            sys.exit(f"check_mutation: the harness is broken, on the intact libraries: {wrong}")
        print(f"[mutation] self-check: {len(tests)} intact tests match their references", flush=True)

    start = time.time()
    results = []
    with cf.ThreadPoolExecutor(args.jobs) as pool:
        futures = [pool.submit(run_mutant, s, args, workers) for s in sample]
        for done, future in enumerate(cf.as_completed(futures), 1):
            results.append(future.result())
            if done % 20 == 0:
                print(f"[mutation] {done}/{len(sample)} in {time.time() - start:.0f} s", flush=True)
                if args.json:
                    with open(args.json, "w") as f:
                        json.dump(results, f, indent=1)
    results.sort(key=lambda r: (r["lib"], r["offset"]))

    if args.json:
        with open(args.json, "w") as f:
            json.dump(results, f, indent=1)
    if args.list_survivors:
        for r in results:
            if r["state"] in ("survived", "unreached"):
                cap = " (capped)" if r["capped"] else ""
                print(f"{r['lib']}:{r['line']}: {r['definition']}: {r['op']}: {r['old']!r} -> {r['new']!r}: "
                      f"{r['state']}, {r['rendered']} rendered of {r['compared']} compared, "
                      f"{r['candidates']} candidates{cap}")
        print()
    summarize(results)
    print(f"\n[mutation] {len(results)} mutants, seed {args.seed}, in {time.time() - start:.0f} s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
