#!/usr/bin/env python3
"""faust-rs `--dump-sig` output  ->  Lean 4 `Sig` terms + certification theorems.

    sig2lean.py <template.lean> <out.lean> <file.dsp> [<file.dsp> ...]

Runs in two passes: it emits the terms, asks Lean for each verdict via `#eval`,
then re-emits the file with a `by decide` theorem pinning each verdict. The
theorem is the artefact — Lean proves it, the script only predicts it.
It also runs the compiler clamp oracle: for every table read, Lean's
as-written verdict (`tableSiteVerdictsB`) is compared with what the compiler
actually did (`--dump-sig-dag-prepared` under `-ct 1` versus `-ct 0`). A
`clampRequired` table the compiler left unclamped fails certification; a
clamp on a table Lean proves in range is reported as a missed optimisation.
The per-program outcome is pinned into the generated file.

Arguments:
    template.lean   the Lean prelude the generated file starts from
                    (formalisation/signal-import-formal-spec.lean);
    out.lean        the file to write (tests/build/certified.lean for
                    `make certify`, tests/lean/certified.lean for
                    `make certify-reference`);
    file.dsp ...    the programs to certify (tests/lean/*.dsp); each file's
                    base name names its definitions and theorems.

Environment:
    FAUST_RS    the faust-rs compiler, which provides --dump-sig-dag and
                --dump-sig-dag-prepared (default: target/release/faust-rs;
                the Makefile passes $(FAUST_RS), `faust-rs` on the PATH);
    FAUST_LIBS  a library directory passed to faust-rs with -I (the Makefile
                passes the checkout, so the libraries under test are used);
    LEAN        the Lean 4 executable (default: lean).

Prints a summary (signals, certified stable, certified indices) and one
clamp-oracle line per program. Exits with a message, and writes nothing, if
Lean returns no verdict for a signal or if the clamp oracle finds a table
that Lean requires clamped and the compiler did not clamp.

Normally run through `make certify` (which also kernel-checks the result
and diffs it with tests/lean/certified.lean) or `make certify-reference`;
see doc/docs/contributing.md, section "Formal certification".
"""
import os, re, struct, subprocess, sys, tempfile
from fractions import Fraction

FAUST_RS = os.environ.get("FAUST_RS", "target/release/faust-rs")
LIBS     = os.environ.get("FAUST_LIBS", "")
LEAN     = os.environ.get("LEAN", "lean")

# Leaf patterns must precede the generic tag pattern: `int(` would otherwise
# lex as a tag named "int".
TOKEN = re.compile(r'''
      (?P<int>int\((?P<ival>-?\d+)\))
    | (?P<flt>float_bits\(0x(?P<fbits>[0-9a-fA-F]{16})\))
    | (?P<sym>sym\("(?P<sval>(?:[^"\\]|\\.)*)"\))
    | (?P<str>str\("(?P<tval>(?:[^"\\]|\\.)*)"\))
    | (?P<range>,\s*init=(?P<rinit>[-\d.einf]+),\s*min=(?P<rmin>[-\d.einf]+),
        \s*max=(?P<rmax>[-\d.einf]+),\s*step=(?P<rstep>[-\d.einf]+))
    | (?P<nil>nil)
    | (?P<tag>[A-Za-z][A-Za-z0-9_]*)\(
    | (?P<close>\))
    | (?P<comma>,)
    | (?P<space>\s+)
''', re.X)


class Node:
    __slots__ = ("tag", "kids", "val")

    def __init__(self, tag, kids=None, val=None):
        self.tag, self.kids, self.val = tag, kids if kids is not None else [], val


def parse(text):
    """Parse one `--dump-sig` line into a Node tree."""
    pos, stack = 0, [Node("ROOT")]
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m:
            raise SyntaxError(f"at {pos}: {text[pos:pos + 60]!r}")
        pos, g = m.end(), m.lastgroup
        if g in ("space", "comma"):
            continue
        if g == "range":
            stack[-1].val = tuple(Fraction(m.group(k))
                                  for k in ("rinit", "rmin", "rmax", "rstep"))
            continue
        if g == "close":
            done = stack.pop()
            stack[-1].kids.append(done)
        elif g == "tag":
            tag = m.group("tag")
            mop = re.match(r'op=(\w+) \([^)]*\),\s*', text[pos:])
            if tag == "SIGBINOP" and mop:
                pos += mop.end()
                stack.append(Node("SIGBINOP", val=mop.group(1)))
            else:
                stack.append(Node(tag))
        else:
            leaf = {
                "int": lambda: Node("int",   val=int(m.group("ival"))),
                "flt": lambda: Node("float", val=exact_double(m.group("fbits"))),
                "sym": lambda: Node("opaque", val=m.group("sval")),
                "str": lambda: Node("opaque", val=m.group("tval")),
                "nil": lambda: Node("nil"),
            }[g]()
            stack[-1].kids.append(leaf)
    assert len(stack) == 1 and len(stack[0].kids) == 1, "unbalanced dump"
    return stack[0].kids[0]


def exact_double(hex16):
    """IEEE-754 double bit pattern -> the exact rational it denotes."""
    return Fraction(struct.unpack(">d", bytes.fromhex(hex16))[0])


# ---------------------------------------------------------------- Lean emitter

def lean_str(s):
    """Re-escape a dump string literal for a Lean string literal."""
    return s.replace("\\", "\\\\").replace('"', '\\"')


UI_RANGE_TAGS = {"SIGVSLIDER", "SIGHSLIDER", "SIGNUMENTRY",
                 "SIGVBARGRAPH", "SIGHBARGRAPH"}


def q_lit(f):
    return f"⟨{i(f.numerator)}, {f.denominator}⟩"


def i(v):
    return f"({v})" if v < 0 else f"{v}"


def emit(n):
    t = n.tag
    if t == "int":    return f"(.int {i(n.val)})"
    if t == "nil":    return "(.nil)"
    if t == "opaque": return f'(.opaque "{lean_str(n.val)}")'
    if t == "float":
        f = n.val
        return f"(.const ⟨{i(f.numerator)}, {f.denominator}⟩)"
    if t in UI_RANGE_TAGS and isinstance(n.val, tuple):
        _, lo, hi, _ = n.val
        kids = ", ".join(emit(k) for k in n.kids[1:])
        return (f'(.control "{t}" {i(n.kids[0].val)} '
                f"{q_lit(lo)} {q_lit(hi)} [{kids}])")
    if t == "SIGINPUT":    return f"(.input {i(n.kids[0].val)})"
    if t == "SIGDELAY1":   return f"(.delay1 {emit(n.kids[0])})"
    if t == "SIGDELAY":    return f"(.delay {emit(n.kids[0])} {emit(n.kids[1])})"
    if t == "SIGPROJ":     return f"(.proj {i(n.kids[0].val)} {emit(n.kids[1])})"
    if t == "DEBRUIJNREC": return f"(.recur {emit(n.kids[0])})"
    if t == "DEBRUIJNREF": return f"(.ref {i(n.kids[0].val)})"
    if t == "cons":        return f"(.cons {emit(n.kids[0])} {emit(n.kids[1])})"
    if t == "SIGBINOP":
        op = {"add": ".add", "sub": ".sub", "mul": ".mul",
              "div": ".div", "rem": ".rem"}.get(n.val)
        if op:
            return f"(.binop {op} {emit(n.kids[0])} {emit(n.kids[1])})"
        # keep the opcode in the name: an unmapped binop must stay
        # distinguishable, otherwise every comparison and bit operation
        # collapses onto the same opaque node.
        kids = ", ".join(emit(k) for k in n.kids)
        return f'(.opaqueN "SIGBINOP:{lean_str(n.val)}" [{kids}])' 
    # Anything not modelled above stays opaque, which the certifier can never
    # read as a linear term.
    kids = ", ".join(emit(k) for k in n.kids)
    return f'(.opaqueN "{lean_str(t)}" [{kids}])'


def split_args(text):
    """Split one argument list on top-level commas."""
    parts, depth, quoted, cur = [], 0, False, []
    for ch in text:
        if quoted:
            cur.append(ch)
            quoted = ch != '"' or cur[-2:-1] == ["\\"]
            continue
        if ch == '"':
            quoted = True
        elif ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        elif ch == "," and depth == 0:
            parts.append("".join(cur).strip())
            cur = []
            continue
        cur.append(ch)
    if "".join(cur).strip():
        parts.append("".join(cur).strip())
    return parts


BIND = re.compile(r'^n(\d+) = ([A-Za-z_][A-Za-z0-9_]*)\((.*)\)$')
ROOT = re.compile(r'^\[(\d+)\] = (.+)$')
KV = re.compile(r'^(op|init|min|max|step)=(.*)$')


def dag_of(dsp):
    """Run `--dump-sig-dag` and return (bindings, roots).

    `bindings[k]` is `(tag, args, range)`; an arg is either `("ref", k)` or a
    parsed leaf `Node`. Reading the DAG form rather than the tree form is what
    keeps this linear: the tree dump of `fi.bandpass(4)` is 2.3 MB for the same
    6.5 kB of graph.
    """
    cmd = [FAUST_RS, "--dump-sig-dag"] + (["-I", LIBS] if LIBS else []) + [dsp]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"{dsp}: {r.stderr.strip()}")
    bindings, roots = {}, []
    for line in r.stdout.splitlines():
        m = BIND.match(line)
        if m:
            idx, tag, rest = int(m.group(1)), m.group(2), m.group(3)
            args, rng, op = [], {}, None
            for a in split_args(rest):
                kv = KV.match(a)
                if kv and kv.group(1) == "op":
                    op = kv.group(2).split()[0]
                elif kv:
                    rng[kv.group(1)] = Fraction(kv.group(2))
                elif re.fullmatch(r"n\d+", a):
                    args.append(("ref", int(a[1:])))
                else:
                    args.append(("leaf", parse(a)))
            bindings[idx] = (tag, args, rng, op)
            continue
        m = ROOT.match(line)
        if m:
            arg = m.group(2)
            roots.append(("ref", int(arg[1:])) if re.fullmatch(r"n\d+", arg)
                         else ("leaf", parse(arg)))
    return bindings, roots


def reachable(bindings, root):
    """Bindings reachable from one root, in dependency order.

    `--dump-sig-dag` numbers nodes in post-order, so a child always carries a
    lower index than its parent. Sorting the reachable set ascending is
    therefore already a topological order -- no second traversal needed.
    """
    seen, stack = set(), [root]
    while stack:
        kind, val = stack.pop()
        if kind != "ref" or val in seen:
            continue
        seen.add(val)
        stack.extend(a for a in bindings[val][1] if a[0] == "ref")
    return sorted(seen)


RAW_BIND = re.compile(r'^n(\d+) = ([A-Za-z_][A-Za-z0-9_]*)\((.*)\)$')
NREF = re.compile(r'\bn(\d+)\b')


def prepared_table_reads(dsp, ct):
    """Table read sites of the *prepared* forest under `-ct <ct>`.

    Runs `--dump-sig-dag-prepared` and returns, in binding order, one
    `(size, index_expr)` pair per `SIGRDTBL` whose table is a `SIGWRTBL` of
    constant size — the same site universe the Lean `sites` function models.
    `index_expr` is the index argument with every `nK` reference textually
    expanded, so it is stable under the renumbering that inserting clamp
    nodes causes between the two `-ct` runs.
    """
    cmd = ([FAUST_RS, "--dump-sig-dag-prepared", "-ct", str(ct)]
           + (["-I", LIBS] if LIBS else []) + [dsp])
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"{dsp} (-ct {ct}): {r.stderr.strip()}")
    raw = {}
    for line in r.stdout.splitlines():
        m = RAW_BIND.match(line)
        if m:
            raw[int(m.group(1))] = (m.group(2), m.group(3))

    def expand(text, depth=0):
        if depth > 500:
            raise RuntimeError(f"{dsp}: reference expansion too deep")
        return NREF.sub(
            lambda m: (lambda tag, rest:
                       f"{tag}({expand(rest, depth + 1)})")(*raw[int(m.group(1))]),
            text)

    sites = []
    for idx in sorted(raw):
        tag, rest = raw[idx]
        if tag != "SIGRDTBL":
            continue
        args = split_args(rest)
        tref = NREF.fullmatch(args[0])
        if not tref:
            continue
        ttag, trest = raw[int(tref.group(1))]
        if ttag != "SIGWRTBL":
            continue
        msize = re.match(r"int\((\d+)\)", split_args(trest)[0])
        if not msize:
            continue
        sites.append((int(msize.group(1)), expand(args[1])))
    return sites


def clamp_oracle(dsp, lean_site_verdicts):
    """Cross-checks Lean's table verdicts against the compiler's `-ct` clamps.

    `lean_site_verdicts` is the parsed `tableSiteVerdictsB` output for every
    output of `dsp`: a list of `(size, verdict)` pairs. The compiler side is
    the diff of the prepared forest between `-ct 1` and `-ct 0`: a read whose
    expanded index changed was clamped by the compiler.

    The comparison is by table-size *presence* (Lean walks the term tree, so
    a shared read can appear once per path; the compiler's hash-consed dump
    holds it once). Returns `(status_line, defect)` where `defect` names a
    table size Lean proves can leave the table but the compiler left
    unclamped — the direction that must fail certification.
    """
    ct1 = prepared_table_reads(dsp, 1)
    ct0 = prepared_table_reads(dsp, 0)
    if [sz for sz, _ in ct1] != [sz for sz, _ in ct0]:
        raise RuntimeError(f"{dsp}: -ct 1 / -ct 0 table sites do not align")
    clamped = {sz for (sz, i1), (_, i0) in zip(ct1, ct0) if i1 != i0}
    required = {sz for sz, v in lean_site_verdicts if v == "clampRequired"}
    sizes = {sz for sz, _ in lean_site_verdicts}
    in_range_only = {sz for sz in sizes
                     if all(v == "inRange"
                            for s2, v in lean_site_verdicts if s2 == sz)}

    not_proven = {sz for sz, v in lean_site_verdicts if v == "notProven"}

    defect = sorted(required - clamped)
    missed = sorted(clamped & in_range_only)
    agree = sorted((required & clamped) | (in_range_only - clamped))
    parts = []
    if agree:
        parts.append("agree on " + ", ".join(f"table[{sz}]" for sz in agree))
    if missed:
        parts.append("missed optimisation: compiler clamps "
                     + ", ".join(f"table[{sz}]" for sz in missed)
                     + " though Lean proves it in range")
    for sz in sorted(not_proven):
        # Lean makes no claim on this size; record what the compiler did so
        # a later rangeOf extension that unlocks the site shows as a drift.
        parts.append(f"table[{sz}] not proven by Lean — compiler "
                     + ("clamps it" if sz in clamped else "leaves it direct"))
    if defect:
        parts.append("DEFECT: Lean requires a clamp on "
                     + ", ".join(f"table[{sz}]" for sz in defect)
                     + " but the compiler left it unclamped")
    if not sizes:
        parts.append("no table site")
    return "; ".join(parts), defect


# ------------------------------------------------ DAG emission (rate analysis)

NODE_TAGS = {"SIGINPUT": ".input", "SIGDELAY1": ".delay1", "SIGDELAY": ".delay",
             "SIGPROJ": ".proj", "DEBRUIJNREC": ".recur", "DEBRUIJNREF": ".ref",
             "cons": ".cons", "SIGBUTTON": ".button", "SIGCHECKBOX": ".button",
             "SIGINTCAST": ".intcast", "SIGFLOATCAST": ".floatcast",
             "SIGMIN": ".min", "SIGMAX": ".max", "SIGABS": ".abs",
             "SIGFLOOR": ".floor", "SIGSELECT2": ".select2", "SIGTAN": ".tan",
             "SIGSIN": ".sin", "SIGCOS": ".cos", "SIGEXP": ".exp",
             "SIGSQRT": ".sqrt", "SIGPOW": ".pow"}
BINOPS = {"add": ".binop .add", "sub": ".binop .sub", "mul": ".binop .mul",
          "div": ".binop .div", "rem": ".binop .rem"}
COMPARISONS = {"lt", "le", "gt", "ge", "eq", "ne"}
SR_NAMES = {"fSamplingFreq", "fSamplingRate"}
PRECISIONS = ("exact", "double", "single")


def node_arg(arg):
    """One argument of a `Node`: a child index, or a leaf."""
    kind, val = arg
    if kind == "ref":
        return f".ref {val}"
    if val.tag == "int":
        return f".int {i(val.val)}"
    if val.tag == "float":
        return f".const {q_lit(val.val)}"
    if val.tag == "nil":
        return ".nil"
    return ".other"


def node_tag(tag, args, op):
    if tag == "SIGBINOP":
        if op in BINOPS:
            return BINOPS[op]
        if op in COMPARISONS:
            return ".cmp"
        return f'.other "SIGBINOP:{lean_str(op or "?")}"'
    if tag == "SIGFCONST":
        names = [a[1].val for a in args if a[0] == "leaf" and a[1].tag == "opaque"]
        return ".sr" if any(n in SR_NAMES for n in names) else '.other "SIGFCONST"'
    if tag in UI_RANGE_TAGS and tag not in ("SIGVBARGRAPH", "SIGHBARGRAPH"):
        return ".control"
    return NODE_TAGS.get(tag, f'.other "{lean_str(tag)}"')


def emit_nodes(bindings):
    """The whole DAG as a `Dag`: node `k` at position `k`."""
    if sorted(bindings) != list(range(len(bindings))):
        raise RuntimeError("dump bindings are not numbered 0..N-1")
    lines = []
    for k in range(len(bindings)):
        tag, args, rng, op = bindings[k]
        t = node_tag(tag, args, op)
        ctl = (f"({q_lit(rng['init'])}, {q_lit(rng['min'])}, {q_lit(rng['max'])})"
               if t == ".control" and rng else "(Q.zero, Q.zero, Q.zero)")
        a = ", ".join(node_arg(x) for x in args)
        lines.append(f"  ⟨{t}, [{a}], {ctl}⟩")
    return "[\n" + ",\n".join(lines) + "]"


def gv_list(letters):
    return "[" + ", ".join({"S": ".stable", "U": ".unproven", "R": ".refused"}[c]
                           for c in letters) + "]"


def parse_sr_probe(text):
    """`n26:SSSSSS;n49:RRRRRR(reason)` -> [(26, "SSSSSS", "reason"), ...]"""
    out = []
    for m in re.finditer(r"n(\d+):([SUR]+)(?:\(([^)]*)\))?", text):
        out.append((int(m.group(1)), m.group(2), m.group(3) or ""))
    return out


def emit_arg(bindings, arg):
    kind, val = arg
    return f"n{val}" if kind == "ref" else emit(val)


def emit_binding(bindings, idx):
    tag, args, rng, op = bindings[idx]
    if tag in UI_RANGE_TAGS and rng:
        cid = emit_arg(bindings, args[0]).strip("()")
        cid = cid.replace(".int ", "")
        kids = ", ".join(emit_arg(bindings, a) for a in args[1:])
        return (f'Sig.control "{tag}" {cid} '
                f"{q_lit(rng['min'])} {q_lit(rng['max'])} [{kids}]")
    if tag == "SIGBINOP" and op:
        lean_op = {"add": ".add", "sub": ".sub", "mul": ".mul",
                   "div": ".div", "rem": ".rem"}.get(op)
        a, b = (emit_arg(bindings, x) for x in args)
        if lean_op:
            return f"Sig.binop {lean_op} {a} {b}"
        return f'Sig.opaqueN "SIGBINOP:{lean_str(op)}" [{a}, {b}]'
    simple = {"SIGINPUT": "Sig.input", "SIGDELAY1": "Sig.delay1",
              "SIGDELAY": "Sig.delay", "SIGPROJ": "Sig.proj",
              "DEBRUIJNREC": "Sig.recur", "DEBRUIJNREF": "Sig.ref",
              "cons": "Sig.cons"}
    rendered = [emit_arg(bindings, a) for a in args]
    if tag in ("SIGINPUT", "DEBRUIJNREF"):
        return f"{simple[tag]} {rendered[0].replace('(.int ', '(').strip('()')}"
    if tag == "SIGPROJ":
        return f"Sig.proj {rendered[0].replace('(.int ', '(').strip('()')} {rendered[1]}"
    if tag in simple:
        return f"{simple[tag]} {' '.join(rendered)}"
    return f'Sig.opaqueN "{lean_str(tag)}" [{", ".join(rendered)}]'


def emit_dag(bindings, root, indent="  "):
    """One `let`-chain per root, binding only what that root reaches."""
    if root[0] == "leaf":
        return emit(root[1])
    lines = [f"{indent}let n{k} : Sig := {emit_binding(bindings, k)}"
             for k in reachable(bindings, root)]
    lines.append(f"{indent}n{root[1]}")
    return "\n" + "\n".join(lines)


def ident(p):
    return re.sub(r'\W', '_', os.path.splitext(os.path.basename(p))[0])


def build(template, dsps, verdicts=None, oracle=None, rates=None):
    out = [open(template).read(),
           "/-! # Generated section",
           "",
           "Everything below is produced by `scripts/sig2lean.py` from",
           "`faust-rs --dump-sig`. Do not edit by hand. -/",
           "",
           "namespace Faust.Signal.Generated",
           "open Faust.Signal",
           ""]
    names = []
    for d in dsps:
        src = open(d).read().strip()
        bindings, roots = dag_of(d)
        for k, root in enumerate(roots):
            name = f"{ident(d)}_out{k}"
            names.append(name)
            out.append(f"/-- `{src}` — output {k} -/")
            out.append(f"def {name} : Sig :={emit_dag(bindings, root)}\n")
        out.append(f"/-- `{src}` — the whole graph, for the rate analysis -/")
        out.append(f"def {ident(d)}_dag : Dag := {emit_nodes(bindings)}\n")
    stems = [ident(d) for d in dsps]
    if verdicts is None:
        out += [f'#eval s!"{n}|" ++ toString (certifyStableB {n}) ++ "|" '
                f'++ toString (certifyIndicesB {n}) ++ "|" '
                f'++ tableSiteVerdictsB {n}' for n in names]
        out += [f'#eval s!"{st}@{p}|" ++ srProbe {st}_dag .{p}'
                for st in stems for p in PRECISIONS]
    else:
        out.append("/-! ## Certification\n")
        out.append("Two independent analyses over the same imported graph.")
        out.append("`certifyStableB` reads the feedback coefficients and applies the")
        out.append("Jury criterion. `certifyIndicesB` checks every table read and")
        out.append("delay tap whose range follows from the graph structure alone;")
        out.append("`false` there means *not proven*, never *unsafe*. -/\n")
        # Prefix each report with the program name: Lean prints bare #eval
        # strings, and an unnamed verdict can only be attributed by counting
        # lines in fixture order.
        out += [f'#eval s!"{n}: " ++ certifyReport {n}' for n in names]
        out.append("")
        out += [f'#eval s!"{n}: " ++ indexReport {n}' for n in names]
        out.append("")
        out += [f"theorem {n}_stability : certifyStableB {n} = {verdicts[n][0]} := by decide"
                for n in names]
        out.append("")
        out += [f"theorem {n}_indices : certifyIndicesB {n} = {verdicts[n][1]} := by decide"
                for n in names]
        out.append("")
        out.append("/-! ## Stability at the rates of `check-precision`\n")
        out.append("Per program and precision, the verdict of every recursion group")
        out.append("(`n<k>`, the dump index of its `DEBRUIJNREC`) at 44.1, 48, 88.2, 96,")
        out.append("176.4 and 192 kHz: `S` stable, `U` linear but not proven stable,")
        out.append("`R` refused (outside the fragment: the reason follows). -/\n")
        for st in stems:
            for p in PRECISIONS:
                out.append(f"-- {st} {p}: {rates[(st, p)][1]}")
        out.append("")
        for st in stems:
            for p in PRECISIONS:
                groups = rates[(st, p)][0]
                body = ", ".join(f"({g}, {gv_list(l)})" for g, l, _ in groups)
                out.append(f"theorem {st}_rates_{p} : srVerdicts {st}_dag .{p} = [{body}] := by decide +kernel")
    if oracle:
        out.append("")
        out.append("/-! ## Compiler clamp oracle\n")
        out.append("Per program, Lean's as-written table verdicts confronted with the")
        out.append("clamps the compiler actually inserted (`--dump-sig-dag-prepared`,")
        out.append("`-ct 1` versus `-ct 0`). Recorded by `sig2lean.py`; a defect —")
        out.append("a `clampRequired` table left unclamped — fails generation instead")
        out.append("of being recorded here.")
        out.append("")
        for line in oracle:
            out.append(line)
        out.append("-/")
    out.append("\nend Faust.Signal.Generated")
    return "\n".join(out), names


def main():
    template, target, dsps = sys.argv[1], sys.argv[2], sys.argv[3:]
    probe, names = build(template, dsps)
    with tempfile.NamedTemporaryFile("w", suffix=".lean", delete=False) as f:
        f.write(probe)
        probe_path = f.name
    r = subprocess.run([LEAN, probe_path], capture_output=True, text=True)
    verdicts = {m[0]: (m[1], m[2], m[3]) for m in
                re.findall(r'"?(\w+)\|(true|false)\|(true|false)\|([^"\n]*)"?',
                           r.stdout)}
    missing = [n for n in names if n not in verdicts]
    if missing:
        sys.exit(f"probe failed for {missing}\n{r.stdout}\n{r.stderr}")
    rates = {}
    for m in re.finditer(r'"?(\w+)@(exact|double|single)\|([^"\n]*)"?', r.stdout):
        rates[(m.group(1), m.group(2))] = (parse_sr_probe(m.group(3)), m.group(3) or "no recursion")
    missing = [(st, p) for st in map(ident, dsps) for p in PRECISIONS if (st, p) not in rates]
    if missing:
        sys.exit(f"rate probe failed for {missing}\n{r.stdout}\n{r.stderr}")

    # Compiler clamp oracle: Lean's table verdicts vs the -ct clamps.
    oracle_lines, defects = [], []
    for d in dsps:
        stem = ident(d)
        site_verdicts = []
        for n in names:
            if n.startswith(f"{stem}_out"):
                for entry in filter(None, verdicts[n][2].split(";")):
                    size, verdict = entry.split(":")
                    site_verdicts.append((int(size), verdict))
        status, defect = clamp_oracle(d, site_verdicts)
        oracle_lines.append(f"{os.path.basename(d)}: {status}")
        if defect:
            defects.append(f"{os.path.basename(d)}: table sizes {defect}")
    if defects:
        sys.exit("clamp oracle DEFECT — Lean requires a clamp the compiler "
                 "did not insert:\n  " + "\n  ".join(defects))

    final, _ = build(template, dsps, verdicts, oracle=oracle_lines, rates=rates)
    open(target, "w").write(final)
    print(f"wrote {target}: {len(names)} signal(s), "
          f"{sum(v[0] == 'true' for v in verdicts.values())} certified stable, "
          f"{sum(v[1] == 'true' for v in verdicts.values())} with certified indices")
    for (st, p), (groups, text) in sorted(rates.items()):
        print(f"  rates {st} {p}: {text}")
    for line in oracle_lines:
        print(f"  clamp oracle: {line}")
    os.unlink(probe_path)


if __name__ == "__main__":
    main()
