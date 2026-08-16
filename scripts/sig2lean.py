#!/usr/bin/env python3
"""faust-rs `--dump-sig` output  ->  Lean 4 `Sig` terms + certification theorems.

    sig2lean.py <template.lean> <out.lean> <file.dsp> [<file.dsp> ...]

Runs in two passes: it emits the terms, asks Lean for each verdict via `#eval`,
then re-emits the file with a `by decide` theorem pinning each verdict. The
theorem is the artefact — Lean proves it, the script only predicts it.
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


def build(template, dsps, verdicts=None):
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
    if verdicts is None:
        out += [f'#eval s!"{n}|" ++ toString (certifyStableB {n}) ++ "|" '
                f'++ toString (certifyIndicesB {n})' for n in names]
    else:
        out.append("/-! ## Certification\n")
        out.append("Two independent analyses over the same imported graph.")
        out.append("`certifyStableB` reads the feedback coefficients and applies the")
        out.append("Jury criterion. `certifyIndicesB` checks every table read and")
        out.append("delay tap whose range follows from the graph structure alone;")
        out.append("`false` there means *not proven*, never *unsafe*. -/\n")
        out += [f"#eval certifyReport {n}" for n in names]
        out.append("")
        out += [f"#eval indexReport {n}" for n in names]
        out.append("")
        out += [f"theorem {n}_stability : certifyStableB {n} = {verdicts[n][0]} := by decide"
                for n in names]
        out.append("")
        out += [f"theorem {n}_indices : certifyIndicesB {n} = {verdicts[n][1]} := by decide"
                for n in names]
    out.append("\nend Faust.Signal.Generated")
    return "\n".join(out), names


def main():
    template, target, dsps = sys.argv[1], sys.argv[2], sys.argv[3:]
    probe, names = build(template, dsps)
    with tempfile.NamedTemporaryFile("w", suffix=".lean", delete=False) as f:
        f.write(probe)
        probe_path = f.name
    r = subprocess.run([LEAN, probe_path], capture_output=True, text=True)
    verdicts = {m[0]: (m[1], m[2]) for m in
                re.findall(r'"?(\w+)\|(true|false)\|(true|false)"?', r.stdout)}
    missing = [n for n in names if n not in verdicts]
    if missing:
        sys.exit(f"probe failed for {missing}\n{r.stdout}\n{r.stderr}")
    final, _ = build(template, dsps, verdicts)
    open(target, "w").write(final)
    print(f"wrote {target}: {len(names)} signal(s), "
          f"{sum(v[0] == 'true' for v in verdicts.values())} certified stable, "
          f"{sum(v[1] == 'true' for v in verdicts.values())} with certified indices")
    os.unlink(probe_path)


if __name__ == "__main__":
    main()
