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


def dumps_of(dsp):
    cmd = [FAUST_RS, "--dump-sig"] + (["-I", LIBS] if LIBS else []) + [dsp]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"{dsp}: {r.stderr.strip()}")
    return [re.sub(r'^\[\d+\] ', '', l) for l in r.stdout.splitlines()
            if re.match(r'^\[\d+\] ', l)]


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
        for k, line in enumerate(dumps_of(d)):
            name = f"{ident(d)}_out{k}"
            names.append(name)
            out.append(f"/-- `{src}` — output {k} -/")
            out.append(f"def {name} : Sig :=\n  {emit(parse(line))}\n")
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
