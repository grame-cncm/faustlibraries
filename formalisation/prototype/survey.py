#!/usr/bin/env python3
"""Coverage survey (writes survey.json, or $SURVEY_JSON): for every *_test of tests/*.dsp, classify each recursion
group of its signal graph at 48 kHz, controls at their default values:
linear (affine in its state, with its state size and stability verdict in
double and single) or refused (with the reason)."""
import collections, concurrent.futures as cf, json, os, re, subprocess, sys
import numpy as np, warnings
warnings.filterwarnings('ignore')

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import float_sr_spike as K  # noqa: E402

REPO = K.REPO
TESTS = os.path.join(REPO, "tests")
TEST_RE = re.compile(r"^\s*([A-Za-z0-9_]+_test)\s*=", re.M)
MAX_STATES = 16


def graph_of(f, name):
    r = subprocess.run(["faust-rs", "--dump-sig-dag", "-I", REPO, "-pn", name, f],
                       cwd=TESTS, capture_output=True, text=True, timeout=300)
    if r.returncode != 0:
        raise RuntimeError((r.stderr or r.stdout).strip().splitlines()[-1][:120])
    g = K.Graph.__new__(K.Graph)
    g.b, g.roots, g.isint = parse(r.stdout), [], {}
    return g


def parse(text):
    bindings = {}
    for line in text.splitlines():
        m = K.S.BIND.match(line)
        if not m:
            continue
        idx, tag, rest = int(m.group(1)), m.group(2), m.group(3)
        args, rng, op = [], {}, None
        for a in K.S.split_args(rest):
            kv = K.S.KV.match(a)
            if kv and kv.group(1) == "op":
                op = kv.group(2).split()[0]
            elif kv:
                rng[kv.group(1)] = K.S.Fraction(kv.group(2))
            elif re.fullmatch(r"n\d+", a):
                args.append(("ref", int(a[1:])))
            else:
                args.append(("leaf", K.S.parse(a)))
        bindings[idx] = (tag, args, rng, op)
    return bindings


def shash(g, a, memo):
    """Structural hash of a subgraph (node numbering independent)."""
    kind, v = a
    if kind == "leaf":
        return hash((v.tag, str(v.val)))
    if v in memo:
        return memo[v]
    tag, args, rng, op = g.b[v]
    h = hash((tag, op, tuple(sorted((k, str(x)) for k, x in rng.items())),
              tuple(shash(g, x, memo) for x in args)))
    memo[v] = h
    return h


def classify(spec):
    f, name = spec
    out = {"test": name, "file": f, "groups": []}
    try:
        g = graph_of(f, name)
    except Exception as e:  # noqa: BLE001
        out["error"] = str(e)
        return out
    controls = {k: K.Iv(float(v[2]["init"])) for k, v in g.b.items() if v[0] in K.CONTROLS}
    recs = [k for k, v in g.b.items() if v[0] == "DEBRUIJNREC"]
    for rec in recs:
        res = {}
        w0 = K.Walker(g, K.Box(K.Iv(48000.0), controls), K.Prec("double"))
        bodies = w0.cons_list(g.b[rec][1][0])
        res["int"] = all(g.arg_int(b) for b in bodies)
        res["hash"] = shash(g, ("ref", rec), {})
        for pr in ("double", "single"):
            w = K.Walker(g, K.Box(K.Iv(48000.0), controls), K.Prec(pr))
            try:
                forms = w.group(rec)
                states, lo, hi = K.state_matrix(forms)
                if not states:
                    res[pr] = "nostate"
                elif len(states) > MAX_STATES:
                    res[pr] = f"linear:{len(states)}:big"
                else:
                    ok, gm, cond, rho = K.lyapunov(lo, hi, frozen=True)
                    res[pr] = f"linear:{len(states)}:{'stable' if ok else 'unproven'}:{rho:.6f}"
            except K.Refuse as e:
                res[pr] = "refused:" + re.sub(r"SIG\w+(/\w+)?", lambda m: m.group(0), str(e))
            except Exception as e:  # noqa: BLE001
                res[pr] = "error:" + type(e).__name__ + ":" + str(e)[:60]
        out["groups"].append(res)
    return out


def main():
    specs = []
    for f in sorted(os.listdir(TESTS)):
        if f.endswith("_tests.dsp"):
            for n in TEST_RE.findall(open(os.path.join(TESTS, f)).read()):
                specs.append((f, n))
    if len(sys.argv) > 1:
        specs = [s for s in specs if re.search(sys.argv[1], s[1])]
    results = []
    with cf.ThreadPoolExecutor(max_workers=os.cpu_count()) as pool:
        for i, r in enumerate(pool.map(classify, specs)):
            results.append(r)
            if (i + 1) % 200 == 0:
                print(f"{i + 1}/{len(specs)}", flush=True)
    json.dump(results, open(os.environ.get("SURVEY_JSON", "survey.json"), "w"), indent=1)
    groups = [grp for r in results for grp in r["groups"]]
    c = collections.Counter()
    for grp in groups:
        d = grp["double"]
        c[d.split(":")[0] + (":" + d.split(":")[2] if d.startswith("linear") else ":" + d.split(":", 1)[1][:50] if d.startswith("refused") else "")] += 1
    print(f"{len(results)} tests, {sum(1 for r in results if 'error' in r)} errors, {len(groups)} recursion groups")
    for k, v in c.most_common():
        print(f"{v:6d}  {k}")


if __name__ == "__main__":
    main()
