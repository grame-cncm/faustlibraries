#!/usr/bin/env python3
"""Run the Lean rate analysis on every regression test.

`make certify` proves theorems about the small programs of tests/lean/. This
script applies the same analysis to every `*_test` of `tests/*.dsp`: for each
recursion group of the test's signal graph, is it stable at each of the six
rates of `make check-precision` (44.1 to 192 kHz), with the controls at their
default values, with its coefficients as the program computes them in exact,
double and single arithmetic? The analysis is `srVerdicts` of
formalisation/signal-import-formal-spec.lean (section "Stability at the sample
rates"); each group gets one letter per rate:

- S: stable;
- U: linear, but not proven stable (in single precision: the rounding of the
     coefficients can move the recursion out of the stable region);
- R: refused, with the reason (nonlinear, more than 2 states, integer
     recursion, groups coupled to each other...): outside what the analysis
     reads, not a defect.

The prelude is compiled once to an .olean, and each test is a small Lean file
that imports it and evaluates the verdicts with `#eval`. That runs the same
code as the theorems of `make certify`, but through Lean's evaluator rather
than its kernel: the suite run is a coverage and regression report, not a set
of kernel-checked theorems. `--kernel` also re-checks each verdict with
`decide +kernel`, which takes much longer.

A test fails when one of its groups is not proven stable (U) at more
(group, rate) slots than tests/certify-baseline.json accepts for it (none for
a test that is not in the file), in any of the three arithmetics. A refused
group (R) never fails: refusals measure the coverage of the analysis, and the
summary counts them. Baseline entries that are no longer needed are
reported, as with check_precision.py. Never add an entry to silence a failure
you caused; `--write-baseline` regenerates the file from a full run.

With the check-precision baseline (tests/precision-baseline.json) at hand, the
summary also confronts the two tools: a test that check-precision reports
non-finite in single precision at a rate where every recursion group of the
test is certified stable (S) must get its non-finite values outside its
recursions, or one of the two tools is wrong.

Usage:
    scripts/certify_tests.py [FILE.dsp ...] [-k REGEX] [-j JOBS] [--json FILE]
                             [--kernel] [--write-baseline]
    make certify-tests CERTIFY_ARGS="..."

Needs faust-rs (--dump-sig-dag) and lean 4.31 (FAUST_RS, LEAN).
"""

import argparse
import collections
import concurrent.futures as cf
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRELUDE = os.path.join(ROOT, "formalisation", "signal-import-formal-spec.lean")
TEST_RE = re.compile(r"^\s*([A-Za-z0-9_]+_test)\s*=", re.M)
PRECISIONS = ("exact", "double", "single")
RATES = [44100, 48000, 88200, 96000, 176400, 192000]

os.environ.setdefault("FAUST_RS", "faust-rs")
os.environ.setdefault("FAUST_LIBS", ROOT)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sig2lean  # noqa: E402

LEAN = os.environ.get("LEAN", "lean")


def test_specs(dsp_files):
    specs = []
    for path in dsp_files:
        with open(path) as f:
            for name in TEST_RE.findall(f.read()):
                specs.append((path, name))
    return specs


def default_dsp_files():
    try:
        out = subprocess.run(["git", "ls-files", "tests/*.dsp"], cwd=ROOT,
                             capture_output=True, text=True, check=True).stdout
        files = [os.path.join(ROOT, p) for p in out.split() if p.count("/") == 1]
    except (OSError, subprocess.CalledProcessError):
        files = glob.glob(os.path.join(ROOT, "tests", "*.dsp"))
    return sorted(files)


def compile_prelude(build_dir):
    """The prelude as module `FaustSignal`, compiled once."""
    src = os.path.join(build_dir, "FaustSignal.lean")
    shutil.copyfile(PRELUDE, src)
    r = subprocess.run([LEAN, "-o", "FaustSignal.olean", "-i", "FaustSignal.ilean",
                        "FaustSignal.lean"], cwd=build_dir, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"prelude does not compile:\n{r.stdout}{r.stderr}")


def shape(bindings, arg, memo):
    """Structural hash of a subgraph, independent of the node numbering: the
    same recursion in two tests (the os.osc of most test inputs) hashes the
    same."""
    kind, v = arg
    if kind == "leaf":
        return hash((v.tag, str(v.val)))
    if v not in memo:
        tag, args, rng, op = bindings[v]
        memo[v] = hash((tag, op, tuple(sorted((k, str(x)) for k, x in rng.items())),
                        tuple(shape(bindings, a, memo) for a in args)))
    return memo[v]


def run_lean(path, build_dir, timeout):
    env = dict(os.environ, LEAN_PATH=build_dir + os.pathsep + os.environ.get("LEAN_PATH", ""))
    return subprocess.run([LEAN, path], cwd=build_dir, env=env, capture_output=True,
                          text=True, timeout=timeout)


def check_test(spec, args):
    dsp, name = spec
    res = {"test": name, "file": os.path.relpath(dsp, ROOT), "groups": []}
    try:
        bindings, _ = sig2lean.dag_of(dsp, extra=["-pn", name], cwd=os.path.dirname(dsp),
                                      timeout=args.timeout)
    except Exception as e:  # noqa: BLE001 - reported per test
        res["error"] = "faust-rs: " + str(e).strip().splitlines()[-1][:200]
        return res
    base = os.path.join(args.build_dir, name)
    options = ["import FaustSignal", "open Faust.Signal", "set_option maxRecDepth 100000",
               "set_option maxHeartbeats 0", ""]
    # A Dag literal of 10 000 nodes takes a minute to elaborate: the evaluated
    # file reads the graph from a string instead (Dag.parse), and checks that
    # every node was read.
    text = sig2lean.emit_nodes_text(bindings)
    with open(base + ".lean", "w") as f:
        f.write("\n".join(options + [
            f'def dagText : String := "{text}"',
            "def dag : Dag := (Dag.parse dagText).getD #[]",
            "",
            '#eval s!"size|{dag.size}"'] +
            [f'#eval "{p}|" ++ probe dag .{p}' for p in PRECISIONS]) + "\n")
    t0 = time.time()
    try:
        r = run_lean(base + ".lean", args.build_dir, args.timeout)
    except subprocess.TimeoutExpired:
        res["error"] = f"lean: timeout after {args.timeout} s"
        return res
    res["seconds"] = round(time.time() - t0, 2)
    probes = dict(re.findall(r'"(exact|double|single)\|([^"\n]*)"', r.stdout))
    size = re.search(r'"size\|(\d+)"', r.stdout)
    if r.returncode == 0 and (not size or int(size.group(1)) != len(bindings)):
        res["error"] = f"lean: the graph text was not read ({size.group(1) if size else '?'} " \
                       f"of {len(bindings)} nodes)"
        return res
    if r.returncode != 0 or set(probes) != set(PRECISIONS):
        res["error"] = "lean: " + ((r.stderr or r.stdout).strip().splitlines() or ["?"])[-1][:200]
        return res
    groups = collections.OrderedDict()
    sites = collections.OrderedDict()
    res["finite"], res["finite_reason"] = {}, {}
    parsed = {}
    for p in PRECISIONS:
        gs, fin, fwhy, ss = sig2lean.parse_probe(probes[p])
        parsed[p] = (gs, fin, ss)
        res["finite"][p] = fin
        if fwhy:
            res["finite_reason"][p] = fwhy
        for node, letters in ss:
            sites.setdefault(node, {"node": node})[p] = letters
        for node, letters, why in gs:
            g = groups.setdefault(node, {"node": node, "reason": ""})
            g[p] = letters
            if why and why not in g["reason"]:
                g["reason"] = (g["reason"] + "; " if g["reason"] else "") + f"{p}: {why}"
    res["sites"] = list(sites.values())
    memo = {}
    for g in groups.values():
        g["shape"] = shape(bindings, ("ref", g["node"]), memo)
    res["groups"] = list(groups.values())
    if args.kernel:
        lines = options + [f"def dag : Dag := {sig2lean.emit_nodes(bindings)}", ""] + [
            f"example : verdicts dag .{p} = {sig2lean.verdicts_lit(*parsed[p][:2], parsed[p][2])} "
            ":= by decide +kernel" for p in PRECISIONS]
        with open(base + ".kernel.lean", "w") as f:
            f.write("\n".join(lines) + "\n")
        try:
            k = run_lean(base + ".kernel.lean", args.build_dir, args.kernel_timeout)
            res["kernel"] = "ok" if k.returncode == 0 else "FAILED"
        except subprocess.TimeoutExpired:
            res["kernel"] = "timeout"
    return res


def unproven(res):
    """Number of U slots (group x rate) per arithmetic."""
    return {p: sum(g.get(p, "").count("U") for g in res["groups"]) for p in PRECISIONS}


def domain(res):
    """Number of rates at which a time-invariant value may leave its domain (D)."""
    return {p: res.get("finite", {}).get(p, "").count("D") for p in PRECISIONS}


def verdict(res, baseline):
    if "error" in res:
        return "error", res["error"]
    if res.get("kernel") not in (None, "ok"):
        return "kernel", f"decide +kernel: {res['kernel']}"
    allowed = baseline.get("unproven", {}).get(res["test"], {})
    over = [f"{p}: {n} unproven (group, rate) > {allowed.get(p, 0)}"
            for p, n in unproven(res).items() if n > allowed.get(p, 0)]
    allowed_d = baseline.get("domain", {}).get(res["test"], {})
    over += [f"{p}: may leave its domain at {n} rates > {allowed_d.get(p, 0)} "
             f"({res['finite_reason'].get(p, '')[:160]})"
             for p, n in domain(res).items() if n > allowed_d.get(p, 0)]
    if over:
        why = "; ".join(g["reason"] for g in res["groups"] if "U" in "".join(
            g.get(p, "") for p in PRECISIONS) and g["reason"])
        return "unproven", "; ".join(over) + (f" ({why})" if why else "")
    return "ok", ""


def stale_baseline(res, baseline):
    if "error" in res:
        return []
    out = []
    for key, count in (("unproven", unproven), ("domain", domain)):
        allowed = baseline.get(key, {}).get(res["test"])
        if allowed:
            now = count(res)
            out += [f"{key} {p}: {now[p]}, baseline {n}" for p, n in allowed.items() if now[p] < n]
    return out


def make_baseline(results):
    entries, dom = {}, {}
    for r in results:
        if "error" in r:
            continue
        u = {p: n for p, n in unproven(r).items() if n}
        if u:
            entries[r["test"]] = u
        d = {p: n for p, n in domain(r).items() if n}
        if d:
            dom[r["test"]] = d
    return {
        "comment": "Accepted verdicts of the Lean rate analysis, see scripts/certify_tests.py: "
                   "unproven = (group, rate) slots not proven stable, domain = rates at which a "
                   "time-invariant value may leave its domain, per arithmetic.",
        "rates": RATES,
        "unproven": dict(sorted(entries.items())),
        "domain": dict(sorted(dom.items())),
    }


def cross_check(results):
    """Tests check-precision reports non-finite in single at a rate where every
    recursion group of the test is certified stable in single."""
    path = os.path.join(ROOT, "tests", "precision-baseline.json")
    if not os.path.exists(path):
        return []
    with open(path) as f:
        nonfinite = json.load(f).get("nonfinite", {})
    out = []
    for r in results:
        rates = nonfinite.get(r["test"])
        if not rates or "error" in r or not r["groups"]:
            continue
        for sr in rates:
            k = RATES.index(sr) if sr in RATES else None
            if k is not None and all(g.get("single", "")[k:k + 1] == "S" for g in r["groups"]):
                out.append(f"{r['test']}: non-finite in single at {sr} Hz (check-precision), "
                           "every recursion group certified stable there")
            elif k is not None:
                states = ", ".join(f"n{g['node']}:{g.get('single', '?')[k]}" for g in r["groups"])
                fin = r.get("finite", {}).get("single", "")[k:k + 1] or "?"
                out.append(f"{r['test']}: non-finite in single at {sr} Hz (check-precision); "
                           f"groups at that rate: {states}; time-invariant values: {fin}")
    return out


def summarize(results):
    """Counts per test, and per structurally distinct recursion group: a test
    input such as os.osc(440) is one group, however many tests use it."""
    tests = collections.Counter()
    groups = collections.Counter()
    reasons = collections.Counter()
    distinct = {}
    for r in results:
        if "error" in r:
            tests["error"] += 1
            continue
        if not r["groups"]:
            tests["no recursion"] += 1
            continue
        letters = {p: "".join(g.get(p, "") for g in r["groups"]) for p in PRECISIONS}
        if all(set(v) <= {"S"} for v in letters.values()):
            tests["every recursion stable, in the 3 arithmetics"] += 1
        elif "U" in letters["exact"] + letters["double"]:
            tests["some recursion not proven stable in exact or double"] += 1
        elif "U" in letters["single"]:
            tests["stable in exact and double, not proven in single"] += 1
        else:
            tests["some recursion refused, the others stable"] += 1
        for g in r["groups"]:
            distinct.setdefault(g["shape"], g)
    for g in distinct.values():
        for p in PRECISIONS:
            v = g.get(p, "")
            groups[(p, "S" if set(v) == {"S"} else "R" if "R" in v else "U")] += 1
        if "R" in g.get("double", ""):
            why = g["reason"].split(": ", 1)[-1].split(";")[0]
            reasons[why] += 1
    finite = collections.Counter()
    sites = collections.Counter()
    for r in results:
        if "error" in r:
            continue
        for p in PRECISIONS:
            f = r.get("finite", {}).get(p, "")
            finite[(p, "D" if "D" in f else "?" if "?" in f else "F")] += 1
            for st in r.get("sites", []):
                v = st.get(p, "")
                sites[(p, "I" if v and set(v) == {"I"} else "N")] += 1
    return tests, groups, reasons, len(distinct), finite, sites


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("dsp", nargs="*", help="test files (default: the tracked tests/*.dsp)")
    p.add_argument("-k", "--filter", help="regex on test names")
    p.add_argument("-j", "--jobs", type=int, default=os.cpu_count())
    p.add_argument("--timeout", type=int, default=300, help="seconds per test and tool")
    p.add_argument("--kernel", action="store_true",
                   help="also re-check every verdict with decide +kernel (slow)")
    p.add_argument("--kernel-timeout", type=int, default=1800)
    p.add_argument("--baseline", default=os.path.join(ROOT, "tests", "certify-baseline.json"))
    p.add_argument("--write-baseline", action="store_true",
                   help="write the accepted unproven slots from this (full) run")
    p.add_argument("--build-dir", default=os.path.join(ROOT, "tests", "build-certify"))
    p.add_argument("--json", help="write every verdict to this file")
    args = p.parse_args()
    args.build_dir = os.path.abspath(args.build_dir)
    if args.write_baseline and (args.dsp or args.filter):
        p.error("--write-baseline needs a run over all tests")
    baseline = {}
    if os.path.exists(args.baseline):
        with open(args.baseline) as f:
            baseline = json.load(f)
    os.makedirs(args.build_dir, exist_ok=True)
    compile_prelude(args.build_dir)

    specs = test_specs([os.path.abspath(f) for f in args.dsp] or default_dsp_files())
    if args.filter:
        specs = [s for s in specs if re.search(args.filter, s[1])]
    t0, last = time.time(), time.time()
    results, failures, stale = [], [], []
    with cf.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(check_test, s, args): s for s in specs}
        for fut in cf.as_completed(futures):
            res = fut.result()
            res["verdict"], res["reason"] = verdict(res, baseline)
            results.append(res)
            if res["verdict"] != "ok":
                failures.append(res)
                print(f"[fail] {res['test']} ({res['file']}): {res['verdict']}, {res['reason']}",
                      flush=True)
            else:
                stale += [f"{res['test']}: {w}" for w in stale_baseline(res, baseline)]
            if time.time() - last > 30:
                last = time.time()
                print(f"[certify-tests] {len(results)}/{len(specs)} tests", flush=True)
    results.sort(key=lambda r: r["test"])
    if args.json:
        with open(args.json, "w") as f:
            json.dump({"rates": RATES, "results": results}, f, indent=1)
    if args.write_baseline:
        with open(args.baseline, "w") as f:
            json.dump(make_baseline(results), f, indent=1)
            f.write("\n")
        print(f"[baseline] written to {os.path.relpath(args.baseline, ROOT)}")
    if stale:
        print("\nBaseline entries no longer needed (lower or remove them in "
              f"{os.path.relpath(args.baseline, ROOT)}):")
        for line in sorted(stale):
            print("  " + line)

    tests, groups, reasons, ndistinct, finite, sites = summarize(results)
    print("\nTests:")
    for k, v in tests.most_common():
        print(f"  {v:5d}  {k}")
    print(f"{ndistinct} structurally distinct recursion groups, "
          "stable at every rate / not proven at some rate / refused:")
    for pr in PRECISIONS:
        print(f"  {pr:6s} S {groups[(pr, 'S')]:5d}  U {groups[(pr, 'U')]:5d}  R {groups[(pr, 'R')]:5d}")
    print("Time-invariant values (tests): finite at every rate / may leave the domain / "
          "not bounded:")
    for pr in PRECISIONS:
        print(f"  {pr:6s} F {finite[(pr, 'F')]:5d}  D {finite[(pr, 'D')]:5d}  ? {finite[(pr, '?')]:5d}")
    print("Table reads and delay taps (per test): in range at every rate / not proven:")
    for pr in PRECISIONS:
        print(f"  {pr:6s} I {sites[(pr, 'I')]:5d}  N {sites[(pr, 'N')]:5d}")
    print("Refusal reasons (distinct groups, double):")
    for k, v in reasons.most_common(12):
        print(f"  {v:5d}  {k}")
    confront = cross_check(results)
    if confront:
        print("Against check-precision's non-finite entries:")
        for line in confront:
            print("  " + line)
    print(f"\n[certify-tests] {len(specs)} tests in {time.time() - t0:.0f} s: "
          f"{len(failures)} failed")
    return 1 if failures and not args.write_baseline else 0


if __name__ == "__main__":
    sys.exit(main())
