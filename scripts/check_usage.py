#!/usr/bin/env python3
"""Compile the `#### Usage` section of every documented symbol.

Why
---
A Usage section shows a call with its input and output buses:

    _ : lowpass(N,fc) : _

This line is a Faust expression. Once `N` and `fc` have values, the
compiler can evaluate it, and its sequential composition `:` fails when a
bus does not match the arity of the call. A Usage that says `_ : wgr(f,r) : _`
for a filter with two outputs is therefore a compilation error, not just a
doc typo that nobody sees. The same Usage strings feed the documentation
pages and the JSON export read by the LLM tools (AGENTS.md, rule 7), so a
wrong arity there misleads every reader.

What is checked
---------------
For each symbol of the JSON export (scripts/build_faust_doc_index.py, the
same 1194 symbols as the documentation):

  1. The Usage lines are read as written in the `.lib`, one statement per
     logical line (see `logical_lines`): a statement may continue over
     several lines, prose lines are skipped but the `code` they quote is
     kept, comments and `-> result` annotations are dropped.
  2. Each statement that names the symbol becomes `process = <statement>;`:
     `(fi.)lowpass` and the bare names of the symbol's library are qualified
     (`fi.lowpass`), and `hslider(...)` (any control written with `...`)
     reads as a control input `_`.
  3. The parameters of the library's calls in the statement take the values
     of the same calls in the `#### Test` section, and the Test section's
     definitions are in scope (helpers, sources). A plain definition line of
     the Usage (`index = 1.69;`) is kept as well.
  4. A name that still has no value is retried as a signal `_` when it sits
     on a bus (`excitation : bowTable(offset,slope) : _`), and as an
     arbitrary value, 2, when it is an argument (`isnan(x)`).
  5. A bus made of wires and a `...` (`_,_, ... : f(N) : _,_, ...`) states a
     variable channel count: it is dropped, and only the call is checked.
  6. The program is evaluated with `faust -e`, which resolves the names,
     applies the functions and checks every composition, without generating
     code (fast: about 15 ms for most symbols).
  7. When it evaluates, the arguments of the symbol's call and the bullets
     of its `Where:` section must name the same parameters (a bullet may
     belong to another function of the same block).

For fi.wgr, `scripts/check_usage.py --symbol fi.wgr` prints the program:

    aa = library("aanl.lib");           // the stdfaust.lib prefixes
    ...
    fi = library("filters.lib");        // the #### Test section
    ...
    src = os.tosc(440);
    wgr_test = fi.wgr(440, 0.995, src);
    process = _ : fi.wgr(f,r) : _ with { f = 440; r = 0.995; };
                                        // the Usage, valued by wgr_test

and the failure: `The number of outputs [2] of wgr(440)(0.995f) must be
equal to the number of inputs [1] of B`.

Kinds of failure
----------------
  arity    a composition of the statement does not match the arity of the
           call: the Usage states the wrong buses;
  prefix   the statement writes a name of the symbol's own library with
           its prefix, `ef.reverseEchoN` in misceffects.lib, `si.bus` in
           signals.lib: write it bare, as the title gives the prefix
           (another library's names keep theirs, `si.bus` in filters.lib);
  params   the call and `Where:` disagree: a parameter of the call is not
           documented, or a documented one does not appear in the Usage;
  unbound  a name has no value: a parameter the Test section does not give
           (write the call with that value in the Test section), or a name
           used without its prefix (`bus` for `si.bus`). Any failure that
           happens after an arbitrary value was given (step 4) is reported
           as `unbound` too, since the value itself may be the cause;
  missing  no Usage statement names the symbol (a family block whose Usage
           shows one member only, a constant without Usage);
  pseudo   a `...` placeholder in an argument list (`conv((k1,k2,...))`);
  syntax   the statement is not Faust (`etc.`, a shell command, `[gain]`);
  error    any other evaluation error, or a time-out (120 s).

A generic name (`fdelay[N]`) is not checked.

Baseline
--------
The debt is pinned in tests/usage-baseline.json, one entry per symbol with
its kind of failure, written by --update-baseline from a full run. The rule
is the one of tests/doc-baseline.json and tests/precision-baseline.json:

  - a symbol that is not in the baseline must pass;
  - an entry must still fail the same way (a Usage edited from `syntax` into
    `arity` is reported, it is not the accepted debt any more);
  - an entry that passes is reported, and removed in the commit that fixes
    the Usage. Never add an entry to silence a Usage you wrote.

Fixing a failure
----------------
`--symbol xx.name` prints each compiled program and the error. Fix the
Usage, not the program: write the buses the call really has
(`_ : f : _,_`, `si.bus(N) : f(N) : si.bus(N)`, `_ : bank(N) : par(i,N,_)`),
name the parameters as in `Where:`, and give the Test section a call that
values every parameter of the Usage.

Name the inputs that have a meaning, and document them: `expm1(x) : _`
with a bullet for `x`, `hypot(x,y) : _`, `ADAA1(EPS, f, F1, x) : _`, are
more explicit than `_ : expm1 : _`. The anonymous `_` is for the audio
input of an effect (`_ : lowpass(N,fc) : _`) and for buses. A `params`
failure on a bullet that documents an input is fixed by naming the input
in the call, never by deleting the bullet. Conventions:
doc/docs/contributing.md, section "New Functions".

Arity of the JSON export
------------------------
The same machinery measures the arity the export publishes:
`build_faust_doc_index.py --measure-io` (the `make doc-index*` targets) calls
`measure_index_io`, which compiles the symbol's call alone as
`process = inputs(call), outputs(call);` (see `measure_io`).

Usage:
    scripts/check_usage.py                    # check, exit 1 on a regression
    scripts/check_usage.py -v                 # also list the accepted debt
    scripts/check_usage.py --symbol fi.wgr    # one symbol, with its programs
    scripts/check_usage.py --lib filters.lib  # one library (repeatable)
    scripts/check_usage.py --changed          # the libraries changed since HEAD
    scripts/check_usage.py --update-baseline  # record the current debt

`make check-usage` checks every symbol (about a minute, 50 s of it for
dx.algorithms alone); `make checkdoc` runs it with --changed when faust is
installed. Exit status: 0 on success, 1 on a regression, 2 without faust.
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
sys.path.insert(0, str(ROOT / "scripts"))
# the doc-block parser of the JSON export: the symbols checked here are
# exactly the symbols exported
import build_faust_doc_index as bfdi  # noqa: E402

BASELINE = ROOT / "tests" / "usage-baseline.json"
IDENT = r"[A-Za-z_][A-Za-z0-9_]*"
# a control whose arguments are elided, `hslider(...) : automat(...)`: one
# control signal, read as an input `_`
CONTROL_RE = re.compile(r"\b(?:hslider|vslider|nentry|button|checkbox|hbargraph|vbargraph)\s*\(\s*\.\.\.\s*\)")
# the value of a parameter neither the Usage nor the Test section gives: an
# integer, so that a size or an order still evaluates, and not 1, which
# selects degenerate cases (a one-element list, a first-order section)
ARBITRARY_VALUE = "2"
# the prose that introduces a statement, `Typical use: ...`
PROSE_PREFIX_RE = re.compile(r"^[A-Z][a-z]+(?: [a-z]+)*:\s+")
# a bus made only of wires and a `...` ellipsis: a variable channel count
VARIADIC_BUS_RE = re.compile(r"^[\s_,!.()]*\.\.\.[\s_,!.()]*$")


def stdfaust_prefixes():
    """The prefixes of stdfaust.lib, {"fi": "filters.lib", ...}."""
    text = (ROOT / "stdfaust.lib").read_text(encoding="utf-8")
    return {m.group(1): m.group(2) for m in bfdi.LIBRARY_DIRECTIVE_RE.finditer(text)}


def load_symbols(index=None):
    """The documented symbols of the export, with their raw Usage lines.

    index is an export index already built (measure_index_io), else it is
    built here.

    The export joins the lines of a Usage into one string; the statements
    are needed one by one, so the Usage lines are read again from the
    `.lib`, with the export's own block parser. Each symbol also carries
    the names of its library (`siblings`) and their Test sections: a Usage
    may call a sibling, `_ : quantize(rf,ionian) : _` for qu.ionian.
    """
    if index is None:
        bfdi.warn = lambda message: None
        index = bfdi.build_index(ROOT, ROOT / "stdfaust.lib")
    names_by_file = {}
    for sym in index["symbols"]:
        names_by_file.setdefault(sym["source"]["path"], set()).add(sym["name"])
    usage_lines = {}
    for path in names_by_file:
        lines = (ROOT / path).read_text(encoding="utf-8").splitlines()
        i = 0
        while i < len(lines):
            block = bfdi.extract_doc_block(lines, i)
            if not block:
                i += 1
                continue
            raw = raw_usage_lines(block["body"])
            for h in block["headerInfos"]:
                usage_lines.setdefault((path, str(h["name"] or "").strip()), raw)
            i = int(block["endIndex"]) + 1
    symbols = []
    for sym in index["symbols"]:
        path = sym["source"]["path"]
        symbols.append({
            "qname": sym["qualifiedName"],          # fi.lowpass
            "name": sym["name"],                    # lowpass
            "prefix": sym["qualifiedName"].rsplit(".", 1)[0],
            "file": sym["source"]["file"],          # filters.lib
            "path": path,                           # dx7/dx7.lib for dx
            "line": sym["source"]["lineStart"],
            "usage": usage_lines.get((path, sym["name"]), []),
            "test": sym.get("testCode") or "",
            # the `Where:` bullets, `K (integer)` read as `K`
            "params": [m.group(0) for m in (re.match(IDENT, str(q["name"]).strip())
                                            for q in sym.get("params") or []) if m],
            "siblings": names_by_file[path],
        })
    tests = {(s["path"], s["name"]): s["test"] for s in symbols}
    for s in symbols:
        s["sibling_tests"] = {n: tests.get((s["path"], n), "") for n in s["siblings"]}
    return symbols


def raw_usage_lines(body):
    """The lines of the `#### Usage` section, as written (one per line).

    The section ends at the next `#### ` title or at `Where:`; fence
    markers, blank lines and `-----` separators are dropped.
    """
    out, section = [], None
    for line in body:
        t = line.strip()
        if t.startswith("#### "):
            section = "usage" if t[5:].strip().lower().startswith("usage") else None
            continue
        if re.match(r"^where\s*:?\s*$", t, flags=re.IGNORECASE):
            section = None
        if section != "usage" or not t or t.startswith("```") or bfdi.is_separator_line(t):
            continue
        out.append(t)
    return out


def split_args(text):
    """Split an argument list on its top-level commas: `a, f(b, c)` -> 2."""
    out, depth, cur = [], 0, ""
    for ch in text:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def call_args(text, name):
    """Arguments of the first call `name(...)` or `xx.name(...)` in text.

    None when there is no such call (a bare `name`, or unbalanced brackets).
    """
    m = re.search(rf"(?<![\w.])(?:{IDENT}\.)?{re.escape(name)}\s*\(", text)
    if not m:
        return None
    i = j = m.end()
    depth = 1
    while j < len(text) and depth:
        depth += {"(": 1, ")": -1}.get(text[j], 0)
        j += 1
    return split_args(text[i:j - 1]) if depth == 0 else None


def names_symbol(line, name):
    """Whether line names the symbol: `name`, `fi.name` or `(fi.)name`."""
    return re.search(rf"(?<![\w.])(?:\({IDENT}\.\)|{IDENT}\.)?{re.escape(name)}(?![\w])", line)


def top_level_split(expr):
    """Split on top-level `:`, `<:`, `:>`, keeping the operators.

    `_,_ : f(a:b) : _` -> ["_,_ ", ":", " f(a:b) ", ":", " _"]: the first
    and last items are the input and output buses of the statement.
    """
    parts, depth, cur, i = [], 0, "", 0
    while i < len(expr):
        ch = expr[i]
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if depth == 0:
            for op in ("<:", ":>", ":"):
                if expr.startswith(op, i):
                    parts.append(cur)
                    parts.append(op)
                    cur = ""
                    i += len(op)
                    break
            else:
                cur += ch
                i += 1
            continue
        cur += ch
        i += 1
    parts.append(cur)
    return parts


def logical_lines(lines):
    """The statements of a Usage section, one per item.

    - `// comments` are dropped, and so is a capitalized prose prefix
      ending with a colon (`Typical use: hslider(...) : kr2ar`);
    - a prose line (see `is_prose`) is skipped, except the `code` it quotes
      between backquotes, kept as a statement of its own;
    - a statement continues on the next line while its brackets are open,
      or when it ends with ` :`, `<:`, `:>`, `,` or `~`. A colon glued to
      a word (`convenience:`) is prose, not a composition.
    """
    out, cur = [], ""
    for line in lines:
        code = re.sub(r"//.*$", "", line).strip()
        code = PROSE_PREFIX_RE.sub("", code)  # `Typical use: ...`
        quoted = re.findall(r"`([^`]+)`", code)
        if quoted or is_prose(code):
            out.extend(quoted)  # only the `code` of a prose line
            continue
        if not code:
            continue
        cur = f"{cur} {code}".strip()
        depth = sum({"(": 1, ")": -1, "[": 1, "]": -1, "{": 1, "}": -1}.get(c, 0) for c in cur)
        if depth > 0 or re.search(r"(\s:|<:|:>|,|~)$", cur):
            continue
        out.append(cur)
        cur = ""
    if cur:
        out.append(cur)
    return out


def is_prose(line):
    """Three words in a row, outside strings: a sentence, not Faust.

    Faust never puts three identifiers side by side without an operator,
    while `Also for convenience` or `Useful for allocating` does. Commas do
    not count: `f(P, dur, ratio)` is code.
    """
    return bool(re.search(r"\b[A-Za-z]+ [A-Za-z]+ [A-Za-z]+\b", re.sub(r'"[^"]*"', "", line)))


def prepare(sym):
    """The Usage definitions, and the statements that name the symbol.

    Returns (defs, statements): defs are the plain definitions of the
    Usage (`index = 1.69`), put in the `with` of each statement;
    statements are (line as written, code) pairs. In a definition line:

    - `name = ...`, the definition of the symbol itself, and an alias
      `other = name;` are not uses: skipped (an unapplied function as
      `process` can also make the compiler loop);
    - `c1(i) = capacitor(i, R)` uses the symbol: its right-hand side is the
      statement, and `i` gets a value like any other parameter;
    - a definition with a `...` (`freqs = (300,400,...)`) is pseudo-code:
      dropped, so that the Test section gives the value.
    """
    defs, statements = [], []
    for line in logical_lines(sym["usage"]):
        code = re.sub(r"\s*->.*$", "", line)  # `take(3,(10,20,30,40)) -> 30`
        code = code.strip().rstrip(";").strip()
        code = re.sub(r"^process\s*=\s*", "", code)
        m = re.match(rf"^({IDENT})\s*(\([^()]*\))?\s*=\s*(.+)$", code)
        if m and "=" not in m.group(3):
            if m.group(1) == sym["name"] or re.fullmatch(
                    rf"(?:\(?{IDENT}\.\)?)?{re.escape(sym['name'])}", m.group(3).strip()):
                continue  # the definition itself, or an alias `x = name;`
            if not names_symbol(m.group(3), sym["name"]):
                if not m.group(2) and "..." not in code:
                    defs.append(code)  # `index = 1.69;`, a value for the line
                continue
            code = m.group(3).strip()  # `c1(i) = capacitor(i, R)`: the call
        if names_symbol(code, sym["name"]):
            statements.append((line, code))
    return defs, statements


def top_level_definitions(body):
    """Split `a = 1; f(x) = x*2;` on its top-level semicolons."""
    out, depth, cur = [], 0, ""
    for ch in body:
        depth += {"(": 1, ")": -1, "[": 1, "]": -1, "{": 1, "}": -1}.get(ch, 0)
        if ch == ";" and depth == 0:
            if cur.strip():
                out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def enclosing_with(text, pos):
    """The definitions of the `with { }` of the Test definition around pos.

    `ADAA1_test = aa.ADAA1(0.001, f, F1, sig) with { f(x) = ...; F1(x) = ...; };`
    gives ["f(x) = ...", "F1(x) = ..."]: the values of `f` and `F1` live
    there, not at the top level of the Test section. The Test definitions
    start at column 0 (the export removes the `// ` of the comment).
    """
    starts = [m.start() for m in re.finditer(rf"^{IDENT}\s*(?:\([^()]*\))?\s*=", text, re.M)
              if m.start() <= pos]
    if not starts:
        return []
    start, depth, end = starts[-1], 0, len(text)
    for k in range(start, len(text)):
        depth += {"(": 1, ")": -1, "[": 1, "]": -1, "{": 1, "}": -1}.get(text[k], 0)
        if text[k] == ";" and depth == 0:
            end = k
            break
    definition, depth = text[start:end], 0
    for k, ch in enumerate(definition):
        if depth == 0 and re.match(r"with\s*\{", definition[k:]) \
                and (k == 0 or not re.match(r"\w", definition[k - 1])):
            body_start = definition.index("{", k) + 1
            inner = 1
            for e in range(body_start, len(definition)):
                inner += {"{": 1, "}": -1}.get(definition[e], 0)
                if inner == 0:
                    return top_level_definitions(definition[body_start:e])
            return []
        depth += {"(": 1, ")": -1, "[": 1, "]": -1, "{": 1, "}": -1}.get(ch, 0)
    return []


def test_calls(test, name):
    """Each call of name in a Test section: (arguments, local definitions)."""
    out = []
    for m in re.finditer(rf"(?<![\w.])(?:{IDENT}\.)?{re.escape(name)}\s*\(", test):
        args = call_args(test[m.start():], name)
        if args is not None:
            out.append((args, enclosing_with(test, m.start())))
    return out


def rewrite(sym, code, defs, choice=0):
    """Turn a statement into the expression compiled for it.

    Returns (expr, bindings, local, more): bindings are the `with`
    definitions that value the parameters, local the definitions of the
    Test's own `with` that these values need, more whether the Test section
    has another call to try (choice + 1). For a `...` that is not a
    variable bus, returns (None, "pseudo", [], False). The steps:

    1. `(fi.)name` -> `fi.name`; `hslider(...)` -> `_`;
    2. drop an input or output bus written with `...`;
    3. for each call of a library symbol in the statement, its arguments
       that are identifiers take the values of the same call in the Test
       section: the symbol's own Test section first, else the callee's.
       `choice` selects which call of the Test section, the first one by
       default: `pt.lfWaveform` is first called in `par(i, 3, ...)` with
       values that depend on `i`, the next call has plain values. A call
       inside `... with { gen = ...; }` brings the definitions of that
       `with`, which its values may use;
    4. the bare names of the library get its prefix, except the names
       just bound, so that a parameter called like a symbol (`ar` in
       `smoothEnvelope(ar,t)`, not `en.ar`) keeps its value.
    """
    code = re.sub(rf"\(({IDENT})\.\)", r"\1.", code)
    code = CONTROL_RE.sub("_", code)
    parts = top_level_split(code)
    if len(parts) >= 3 and VARIADIC_BUS_RE.match(parts[0]):
        parts = parts[2:]
    if len(parts) >= 3 and VARIADIC_BUS_RE.match(parts[-1]):
        parts = parts[:-2]
    code = "".join(parts).strip()
    if "..." in code:
        return None, "pseudo", [], False
    # parameters of the library's calls, valued from their Test sections;
    # longest names first, so that `lowpass6e` is matched before `lowpass`
    bindings, local, more = {}, [], False
    defined = {d.split("=")[0].strip() for d in defs}
    for callee in sorted(sym["siblings"], key=len, reverse=True):
        args = call_args(code, callee)
        if args is None:
            continue
        calls = test_calls(sym["test"], callee) or test_calls(sym["sibling_tests"].get(callee, ""), callee)
        if not calls:
            continue
        more = more or choice + 1 < len(calls)
        values, with_defs = calls[min(choice, len(calls) - 1)]
        for a, v in zip(args, values):
            # a parameter may share its name with a symbol (`ar` in
            # smoothEnvelope(ar,t)): the binding takes precedence
            if re.fullmatch(IDENT, a) and a != "_" and a != v \
                    and a not in bindings and a not in defined:
                bindings[a] = v
        local += [d for d in with_defs if d not in local]
    # a local definition may not redefine a bound name (Faust refuses it)
    local = [d for d in local
             if re.match(IDENT, d).group(0) not in set(bindings) | defined]
    # bare names of the symbol's own library
    for n in sorted(sym["siblings"], key=len, reverse=True):
        if n in bindings or n in defined:
            continue
        # (not `SAFE` in `os[SAFE=1;]`, a definition)
        code = re.sub(rf"(?<![\w.]){re.escape(n)}(?![\w])(?!\s*=(?!=))", f"{sym['prefix']}.{n}", code)
    return code, bindings, local, more


def in_call(expr, pos):
    """Whether pos is inside the arguments of a call (not a bus grouping).

    A `(` that follows a name (or a `]`, `os[SAFE=1;](...)`) opens a call;
    one that follows an operator or a comma groups a bus, `(r0,i0), (r1,i1)`.
    """
    stack = []
    for i, ch in enumerate(expr[:pos]):
        if ch == "(":
            stack.append(bool(re.search(r"[\w\]]\s*$", expr[:i])))
        elif ch == ")" and stack:
            stack.pop()
    return any(stack)


def program(sym, expr, bindings, defs, prefixes):
    """The stdfaust prefixes, the Test section, then the Usage statement.

    stdfaust.lib is not imported: its prefixes are written one by one, and
    a prefix the Test section defines itself (`dx = library("dx7/dx7.lib")`,
    `sf = soundfile(...)`) is left to it, since Faust refuses two different
    definitions of a name. A `process` of the Test section is renamed, the
    one of the Usage statement taking its place.
    """
    test = re.sub(r"^process(?=\s*=)", "_usage_test_process", sym["test"], flags=re.M)
    own = set(re.findall(rf"^({IDENT})\s*(?:\(|=)", test, flags=re.M))
    lines = [f'{p} = library("{f}");' for p, f in prefixes.items() if p not in own]
    if sym["prefix"] not in prefixes and sym["prefix"] not in own:
        lines.append(f'{sym["prefix"]} = library("{sym["file"]}");')
    if test:
        lines.append(test)
    local = [f"{k} = {v};" for k, v in bindings.items()] + [d + ";" for d in defs]
    with_ = f" with {{ {' '.join(local)} }}" if local else ""
    lines.append(f"process = {expr}{with_};")
    return "\n".join(lines) + "\n"


def classify(stderr):
    """(kind, message) of a Faust error output.

    For a composition error, the message is the line that gives the two
    counts (`The number of outputs [2] of ... inputs [1] of B`). Faust
    reports a name with no value either as `undefined symbol : x` or, when
    it meets it inside a library function, as `BoxIdent[x] is defined
    here`: both are `unbound`.
    """
    lines = [l for l in stderr.strip().splitlines() if l.strip()]
    msg = next((l for l in lines if "ERROR" in l), lines[0] if lines else "?")
    msg = re.sub(r"^.*ERROR\s*:\s*", "", msg).strip()
    count = next((l.strip() for l in lines if l.strip().startswith("The number of")), None)
    if re.search(r"(sequential|split|merge|recursive|parallel) composition", msg):
        return "arity", count or msg
    if msg.startswith("undefined symbol"):
        return "unbound", msg
    m = re.match(r"BoxIdent\[(.+?)\] is defined here", msg)
    if m:  # a name with no value, met where the library uses its parameter
        return "unbound", f"undefined symbol : {m.group(1)}"
    if "syntax error" in msg:
        return "syntax", msg
    return "error", msg


def evaluate(sym, expr, bindings, defs, prefixes, workdir, programs, wrap=None):
    """Evaluate `process = expr` with `faust -e`, valuing its unbound names.

    Returns (stdout, None) when the program evaluates, else (None, (kind,
    message)). wrap, when given, turns expr into the process expression
    (`inputs(c), outputs(c)` for measure_io); the names are still looked
    for in expr. bindings is completed in place, and each source compiled
    is appended to programs.

    The program is compiled again each time an unbound name gets a value
    (step 4 of the module docstring), until it evaluates or fails on
    something else. A failure after an arbitrary value is reported as
    `unbound`: the value itself may be its cause.
    """
    given = []  # the names given a value by the retries, `x = 2`
    while True:
        src = program(sym, wrap(expr) if wrap else expr, bindings, defs, prefixes)
        programs.append(src)
        # one directory per call: fi.tf2 and fi.TF2 are the same file name
        # on a case-insensitive file system (macOS), and the threads would
        # overwrite each other's program
        path = Path(tempfile.mkdtemp(dir=workdir)) / (sym["qname"].replace(".", "_") + ".dsp")
        path.write_text(src, encoding="utf-8")
        try:
            # -e stops after the evaluation, which checks names and arities;
            # the evaluated program goes to stdout, where measure_io reads it
            r = subprocess.run(["faust", "-e", "-I", str(ROOT), str(path), "-o", "/dev/stdout"],
                               capture_output=True, text=True, cwd=ROOT, timeout=120)
        except subprocess.TimeoutExpired:
            return None, ("error", "compilation timed out")
        if r.returncode == 0 or "has no output signal" in r.stderr:
            # (a sink like si.block(N) evaluates fine and outputs nothing)
            return r.stdout, None
        kind, msg = classify(r.stderr)
        name = msg.split(":")[-1].strip() if kind == "unbound" else ""
        # A name the Test section gives no value, used as a value (not
        # called): on a bus, a signal (`excitation : bowTable(...)`); as an
        # argument, a value (`isnan(x)`, `envelopeAbs(..., sig)`). A called
        # name (`smooth(...)` for si.smooth) stays unbound.
        use = re.search(rf"(?<![\w.]){name}(?!\w)(?!\s*\()", expr) \
            if re.fullmatch(IDENT, name) and name not in bindings else None
        if use:
            bindings[name] = ARBITRARY_VALUE if in_call(expr, use.start()) else "_"
            given.append(name)
            continue
        if given:
            msg += f" (with {', '.join(f'{n} = {bindings[n]}' for n in given)})"
        if any(bindings[n] == ARBITRARY_VALUE for n in given):
            # the Usage needs a parameter value, in the Usage or the Test section
            kind = "unbound"
        return None, (kind, msg)


def check(sym, prefixes, workdir):
    """Check one symbol: (kind, detail, programs).

    kind is "ok" or a kind of failure (see the module docstring), detail
    the statement and the compiler's message, programs the sources
    compiled, printed by --symbol. Every statement naming the symbol must
    evaluate; the first failure is reported; then the parameters are
    compared with `Where:`.
    """
    if "[" in sym["name"]:
        return "ok", "generic name, not checked", []
    defs, statements = prepare(sym)
    if not statements:
        return "missing", "no Usage line names it", []
    programs = []
    for line, code in statements:
        first, choice = None, 0
        while True:
            expr, bindings, local, more = rewrite(sym, code, defs, choice)
            if expr is None:
                return bindings, f"`{line}`: `...` is not Faust", programs
            _, failure = evaluate(sym, expr, bindings, defs + local, prefixes, workdir, programs)
            if not failure:
                break
            first = first or failure
            if failure[0] == "unbound" and more:
                choice += 1  # the next call of the Test section
                continue
            return first[0], f"`{line}`: {first[1]}", programs
    detail = check_prefix(sym, statements)
    if detail:
        return "prefix", detail, programs
    detail = check_params(sym, statements, defs)
    if detail:
        return "params", detail, programs
    return "ok", "", programs


def check_prefix(sym, statements):
    """The names of the symbol's own library are written without prefix.

    In filters.lib the Usage reads `_ : lowpass(N,fc) : _`, not
    `fi.lowpass` or `(fi.)lowpass`: the title already gives the prefix,
    and the other blocks of the library are written so. A function of
    another library keeps its prefix (`si.bus(N)` in analyzers.lib, but
    `bus(N)` in signals.lib). Returns "" or the names written with it.
    """
    found = []
    for line, _ in statements:
        code = re.sub(r"//.*$", "", line)
        for m in re.finditer(rf"(?<![\w.])(\(?{re.escape(sym['prefix'])}\.\)?)({IDENT})", code):
            if m.group(2) in sym["siblings"] and m.group(0) not in found:
                found.append(m.group(0))
    if not found:
        return ""
    return (f"written with the prefix of its own library: {', '.join(found)}"
            f" (write {', '.join(re.sub(r'^.*[.)]', '', f) for f in found)})")


def symbol_call(expr, sym):
    """The symbol's call in expr, with its arguments.

    `_ : fi.wgr(f,r) : _` -> `fi.wgr(f,r)`; a member of an environment
    keeps its access, `os.rpm.sawtooth(freq, beta)`; a constant or a list
    is its name, `ma.PI`. None when expr does not use the qualified name.
    """
    m = re.search(rf"(?<![\w.]){re.escape(sym['prefix'])}\.{re.escape(sym['name'])}(?!\w)", expr)
    if not m:
        return None
    j = m.end()
    while True:
        k = j
        while k < len(expr) and expr[k] == " ":
            k += 1  # `filterbank (O,freqs)`
        if k < len(expr) and expr[k] == "(":
            depth = 0
            for k in range(k, len(expr)):
                depth += {"(": 1, ")": -1}.get(expr[k], 0)
                if depth == 0:
                    break
            if depth:
                return None
            j = k + 1
            continue
        member = re.match(rf"\.{IDENT}", expr[j:])
        if not member:
            return expr[m.start():j]
        j += member.end()


def measure_io(sym, prefixes, workdir):
    """The arity of the symbol's call in its Usage, computed by Faust.

    The first Usage statement whose call evaluates gives it: the call,
    with the parameter values check() would give it, is compiled as
    `process = inputs(call), outputs(call);`, two constants that `faust -e`
    prints. Returns {"inSignals", "outSignals", "parameterValues",
    "assumedValues"}, or None when no call evaluates (a pseudo-code Usage,
    an environment `fi.svf`). An arity may depend on the parameters
    (`an.ifft(N)` has 2N inputs): parameterValues holds the values of the
    call's parameters taken from the Test section or the Usage, and
    assumedValues those that neither gives, set to ARBITRARY_VALUE.
    """
    if "[" in sym["name"]:
        return None
    defs, statements = prepare(sym)
    for _, code in statements:
        choice, more = 0, True
        while more:
            expr, bindings, local, more = rewrite(sym, code, defs, choice)
            call = symbol_call(expr, sym) if expr is not None else None
            if call is None:
                break
            documented = set(bindings)
            out, failure = evaluate(sym, call, bindings, defs + local, prefixes, workdir, [],
                                    wrap=lambda c: f"inputs({c}), outputs({c})")
            counts = re.findall(r"^(?:ID_\d+|process)\s*=\s*(\d+)\s*,\s*(\d+)\s*;",
                                out or "", re.M)
            if not failure and counts:
                break
            choice += 1
        else:
            continue
        if call is None:
            continue
        def in_the_call(name):
            return re.search(rf"(?<![\w.]){re.escape(name)}(?!\w)", call)
        values = {k: v for k, v in bindings.items() if k in documented and in_the_call(k)}
        values.update({d.split("=")[0].strip(): d.split("=", 1)[1].strip() for d in defs + local
                       if in_the_call(d.split("=")[0].strip())})
        assumed = {k: v for k, v in bindings.items() if k not in documented and in_the_call(k)}
        return {"inSignals": int(counts[-1][0]), "outSignals": int(counts[-1][1]),
                "parameterValues": values, "assumedValues": assumed}
    return None


def measure_index_io(index, jobs=None):
    """Replace the io of the symbols of an export index by measure_io's.

    Used by `build_faust_doc_index.py --measure-io`. A measured io gets
    `"source": "faust"`, its `parameterValues` and `assumedValues`; the
    others keep the counts guessed from the Usage text, with `"source":
    "usage"`. The libraries measured are those of this checkout. Returns
    the number of symbols measured.
    """
    if not shutil.which("faust"):
        raise RuntimeError("faust not found in PATH")
    prefixes = stdfaust_prefixes()
    symbols = load_symbols(index)
    with tempfile.TemporaryDirectory() as workdir, \
            cf.ThreadPoolExecutor(max_workers=jobs or os.cpu_count() or 4) as pool:
        measured = dict(zip((s["qname"] for s in symbols),
                            pool.map(lambda s: measure_io(s, prefixes, workdir), symbols)))
    count = 0
    for sym in index["symbols"]:
        io = measured.get(sym["qualifiedName"])
        if io:
            sym["io"] = {"inSignals": io["inSignals"], "outSignals": io["outSignals"],
                         "raw": sym["io"].get("raw"), "source": "faust",
                         "parameterValues": io["parameterValues"],
                         "assumedValues": io["assumedValues"]}
            count += 1
    return count


def check_params(sym, statements, defs):
    """Whether the Usage call and the `Where:` bullets name the same parameters.

    Returns "" when they agree, else what differs. Two directions:

    - each identifier argument of the symbol's call must have a bullet,
      except the names defined in the Usage and the library's symbols
      (`quantize(rf, ionian)`: `ionian` is a function, not a parameter);
    - each bullet must appear somewhere in the Usage section, in a call or
      on a bus (`si.bus(N) : f(N)`): `* `x`: input` with a Usage
      `_ : cosh : _` documents a parameter the Usage does not have. The
      whole section counts, not only the statements of this symbol: in a
      block documenting several functions, `Where:` describes them all
      (`N` of `convN(N,kv)` in the block of `conv(kv)`).
    """
    used = " ".join(code for _, code in statements)
    section = " ".join(logical_lines(sym["usage"]))
    args = call_args(used, sym["name"]) or []
    defined = {d.split("=")[0].strip() for d in defs}
    names = [a for a in args if re.fullmatch(IDENT, a) and a != "_"
             and a not in defined and a not in sym["siblings"]]
    undocumented = [a for a in names if a not in sym["params"]]
    unused = [w for w in sym["params"]
              if not re.search(rf"(?<![\w.]){re.escape(w)}(?!\w)", section)]
    problems = []
    if undocumented:
        problems.append(f"not in `Where:`: {', '.join(undocumented)}")
    if unused:
        # the usual case: a bullet for the input of `_ : f : _`; the fix is
        # to name that input in the call, not to delete what documents it
        problems.append(f"in `Where:`, not in the Usage: {', '.join(unused)} (an input?"
                        f" name it in the call, `{sym['name']}({', '.join(unused)}) : _`,"
                        f" rather than deleting its bullet)")
    return "; ".join(problems)


def changed_libraries():
    """The .lib files that differ from HEAD (staged or not), or are untracked.

    Paths relative to the repository root, like the symbols' `path`. Only
    the libraries of the export matter: an untracked scratch `.lib` has no
    exported symbol and selects nothing.
    """
    out = subprocess.run(["git", "diff", "--name-only", "HEAD", "--", "*.lib"],
                         capture_output=True, text=True, cwd=ROOT).stdout.split()
    out += subprocess.run(["git", "ls-files", "--others", "--exclude-standard", "--", "*.lib"],
                          capture_output=True, text=True, cwd=ROOT).stdout.split()
    return set(out)


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--lib", action="append", help="check this library only (repeatable)")
    p.add_argument("--symbol", action="append",
                   help="check this qualified name only (repeatable), and print its programs")
    p.add_argument("--changed", action="store_true",
                   help="check the libraries that differ from HEAD (or are new) only")
    p.add_argument("-v", "--verbose", action="store_true", help="also list the accepted debt")
    p.add_argument("-j", "--jobs", type=int, default=os.cpu_count() or 4,
                   help="parallel compilations (default: the number of CPUs)")
    p.add_argument("--update-baseline", action="store_true",
                   help=f"record the current failures in {BASELINE.relative_to(ROOT)}")
    args = p.parse_args()

    if not shutil.which("faust"):
        print("check_usage: faust not found in PATH", file=sys.stderr)
        sys.exit(2)
    prefixes = stdfaust_prefixes()
    symbols = load_symbols()
    if args.lib:
        symbols = [s for s in symbols if s["file"] in args.lib]
    if args.symbol:
        symbols = [s for s in symbols if s["qname"] in args.symbol]
    if args.changed:
        changed = changed_libraries()
        symbols = [s for s in symbols if s["path"] in changed]
        if not symbols:
            print("check_usage: OK (no library changed since HEAD).")
            return
    # a partial run cannot tell that a baseline entry lost its symbol
    partial = bool(args.lib or args.symbol or args.changed)
    if args.update_baseline and partial:
        p.error("--update-baseline checks every symbol: drop --lib, --symbol and --changed")

    baseline = json.loads(BASELINE.read_text()) if BASELINE.exists() else {}
    results = {}
    with tempfile.TemporaryDirectory() as workdir, \
            cf.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(check, s, prefixes, workdir): s for s in symbols}
        for fut in cf.as_completed(futures):
            results[futures[fut]["qname"]] = (futures[fut], *fut.result())

    if args.update_baseline:
        debt = {q: r[1] for q, r in sorted(results.items()) if r[1] != "ok"}
        BASELINE.write_text(json.dumps(debt, indent=1, sort_keys=True) + "\n")
        print(f"Wrote {BASELINE.relative_to(ROOT)} ({len(debt)} symbols).")
        return

    # compare with the baseline: new failures, changed failures, entries
    # that pass now, entries whose symbol is gone
    errors, accepted, counts = [], [], {}
    for q, (sym, kind, detail, programs) in sorted(results.items()):
        counts[kind] = counts.get(kind, 0) + 1
        where = f"{sym['path']}:{sym['line']}"
        if args.symbol:
            for src in programs:
                print(f"--- {q}\n{src}", end="")
        if kind == "ok":
            if q in baseline:
                errors.append(f"{q} ({where}): passes now; remove it from the baseline")
            continue
        line = f"{q} ({where}): {kind}: {detail}"
        if baseline.get(q) == kind:
            accepted.append(line)
        elif q in baseline:
            errors.append(f"{line} (baseline: {baseline[q]})")
        else:
            errors.append(line)
    if not partial:
        for q in sorted(set(baseline) - set(results)):
            errors.append(f"{q}: no longer documented; remove it from the baseline")

    if args.verbose or args.symbol:
        for line in accepted:
            print(f"check_usage: accepted: {line}")
    for e in errors:
        print(f"check_usage: {e}")
    summary = ", ".join(f"{n} {k}" for k, n in sorted(counts.items(), key=lambda kv: -kv[1]))
    if errors:
        print(f"check_usage: FAILED ({len(errors)} problem(s)); {len(results)} symbols: {summary}.")
        print("A failure in a Usage you wrote is fixed in the Usage (or in the Test section"
              " that gives its parameters values), not in the baseline.")
        sys.exit(1)
    print(f"check_usage: OK ({len(results)} symbols: {summary}; accepted debt:"
          f" {len(accepted)}).")


if __name__ == "__main__":
    main()
