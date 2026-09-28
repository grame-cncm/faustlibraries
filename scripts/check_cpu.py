#!/usr/bin/env python3
"""Measure the CPU cost of the regression tests, and compare two versions of the libraries.

`make check` and `make check-precision` say whether a change alters what a
test computes; this script says what it costs. For every `*_test` of the
given test files, it compiles the test with `arch/cpu_arch.cpp` and reports
the best time per frame, in ns, and the share of one core at the sample rate.

With --base REV, the same tests are also built against the libraries of
REV (a commit, a branch, origin/master...), and the table shows both times
and their ratio, new / base. With --new REV the new side is REV too, instead
of the working tree: `--base origin/master --new origin/some-branch` measures
a pull request without checking it out. The test files are always those of
the new side, so a test added by the change is measured against the base
libraries when they can compile it (otherwise the base column says why not).

The measurement is the "flash" judge of faustcompilerbenchtool (Yann
Orlarey, see arch/cpu_arch.cpp): LCG noise on the inputs, 512-frame blocks,
a spin that gets the process onto a performance core, warm-up, then the
minimum over repetitions. On top of it, this script:

- builds in parallel but times strictly one binary at a time;
- refuses to time on battery power (macOS: pmset), since frequency scaling
  biases even ratios measured side by side (--allow-battery overrides it);
- pauses after the builds, then times the tests one after the other, each
  over --rounds rounds in which the two sides run back to back, in an order
  that alternates from one round to the next; each side keeps the median of
  its rounds (each round being the minimum of one run), and the spread of the rounds, (max - min) / min, is reported so that a
  ratio can be read against the noise; a test whose spread exceeds 5% is
  re-raced once with as many rounds again, as fcautotool does;
- gives no ratio for a test that computes nothing per sample (below 0.1
  ns/frame on both sides: a constant output), whose ratio is noise;
- prints its progress every 30 s (and updates the --json file then); an
  interrupted run (Ctrl-C, kill) still reports the tests already measured;
- flags a test whose output is not finite: its time measures NaN handling;
- counts, in the generated code, what each sample executes that an embedded
  core pays dearly for: divisions, square roots and transcendental calls
  (pow, exp, log, sin, cos, tan...). An out-of-order desktop core overlaps
  them with the rest of the loop; a Cortex-M7 spends 14 cycles on a float
  division or square root, and tens to hundreds on a pow or a tan. The
  column `ops` gives div/sqrt/fn per sample, and `!` marks a test whose new
  side has more of any of them than its base: a ratio measured on the
  desktop does not show what such a change costs on a microcontroller;
- with --changed-only, times only the tests whose generated C++ differs
  between the two sides (metadata lines aside, such as the library
  versions): the others run the same code, so their ratio is 1 by
  construction and timing them measures noise. This makes an A/B over the
  whole suite affordable: a change of fi.lowpass reaches tests in many
  libraries, which --changed-only finds without guessing them.

The default compilation is the one users get from faust2xx scripts
(faustoptflags): `-O3 -ffast-math`, plus `-march=native` except on Apple
Silicon, with `faust -single`. --double, --faust-options and --cxx-options
change it; --rate sets the sample rate (48000 Hz by default).

A ratio depends on the compilation, not only a time: -ffast-math lets the
C++ compiler reassociate and turn divisions into multiplications, which a
direct-form filter profits from more than a state-variable one, and the
same change can measure 1.44 with it and 1.20 without. --matrix runs several
named compilations in turn (see CONFIGS below, --matrix all for every one):
a change that alters the structure of a computation reports at least
fast-math and strict.

Times are only comparable on one machine, one compiler and one run: the
identity line printed first (and stored with --json) names them. Never
compare numbers from two runs when a ratio from one run can be had.
"""

import argparse
import concurrent.futures as cf
import glob
import json
import os
import platform
import re
import shlex
import shutil
import signal
import statistics
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARCH = os.path.join(ROOT, "arch", "cpu_arch.cpp")
# A test is a top-level definition named *_test, as for check_precision.py.
TEST_RE = re.compile(r"^\s*([A-Za-z0-9_]+_test)\s*=", re.M)
# The single line printed by cpu_arch.cpp.
RESULT_RE = re.compile(r"([0-9.]+) ns/frame finite=([01])")
# Passed to cpu_arch.cpp: fewer repetitions than the original flash defaults
# (30 x 200 blocks), since the rounds already repeat each measurement. These
# are the values fcautotool uses for its races.
FLASH_ENV = {"FLASH_REPS": "10", "FLASH_BLOCKS": "100", "FLASH_WARM": "120"}
# A test whose rounds spread more than this on one side is re-raced once, with
# as many rounds again: a spike in one round should not decide its minimum.
RERACE_SPREAD = 0.05
# Below this time per frame a test computes nothing per sample (its output is a
# constant computed at init): its ratio is noise and is not reported.
TRIVIAL_NS = 0.1


def default_cxx_options():
    """The optimization flags of faustoptflags, which the faust2xx scripts use."""
    if platform.system() == "Darwin" and platform.machine() == "arm64":
        return "-O3 -ffast-math"
    return "-O3 -ffast-math -march=native"


def strict_cxx_options():
    """faustoptflags without -ffast-math: IEEE semantics, no reassociation."""
    return " ".join(o for o in default_cxx_options().split() if o != "-ffast-math")


# Named compilations for --matrix: (Faust options, C++ options).
CONFIGS = {
    "fast-math": ("", default_cxx_options()),
    "strict": ("", strict_cxx_options()),
    "vec": ("-vec", default_cxx_options()),
}


class Config:
    """One way of compiling the tests: its name and its Faust and C++ options."""

    def __init__(self, name, faust_options, cxx_options):
        self.name = name
        self.faust_options = faust_options
        self.cxx_options = cxx_options

    def describe(self, double):
        faust = f"faust {'-double' if double else '-single'} {self.faust_options}".strip()
        return f"{faust}, c++ {self.cxx_options}"

    def slug(self, double):
        """Build subdirectory of the compilation, named after its options."""
        text = f"{'double' if double else 'single'} {self.faust_options} {self.cxx_options}"
        return "cfg_" + re.sub(r"[^A-Za-z0-9.+-]+", "_", text).strip("_")


def git(*args, cwd=ROOT):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True,
                          check=True).stdout.strip()


def export_rev(rev, build_dir):
    """The libraries and tests of REV, extracted once per commit (never modified).

    `git archive` rather than a worktree: nothing is registered in the
    repository, and the extraction, keyed by the commit, is reused by later
    runs. Only what a test build needs is extracted: every .lib (dx7/ and the
    other subdirectories included) and tests/. The .complete marker is
    written last, so that an interrupted extraction is redone.
    """
    sha = git("rev-parse", "--verify", rev + "^{commit}")
    dest = os.path.join(build_dir, "src", sha[:12])
    if not os.path.exists(os.path.join(dest, ".complete")):
        shutil.rmtree(dest, ignore_errors=True)
        os.makedirs(dest)
        archive = subprocess.run(["git", "archive", sha, "--", ":(glob)**/*.lib", "tests"],
                                 cwd=ROOT, capture_output=True, check=True).stdout
        subprocess.run(["tar", "-x", "-C", dest], input=archive, check=True)
        open(os.path.join(dest, ".complete"), "w").close()
    return sha, dest


class Side:
    """One version of the libraries: where they are, and where its builds go.

    `label` is "base" or "new"; `lib_dir` is the directory the libraries are
    compiled from (the working tree itself, or an extracted commit); `desc`
    is what the identity lines print.
    """

    def __init__(self, label, rev, build_dir):
        self.label = label
        if rev is None:
            self.rev, self.lib_dir = "working tree", ROOT
            # Say so when the libraries differ from HEAD: the measurement is
            # then of uncommitted code.
            dirty = git("status", "--porcelain", "--untracked-files=no", "--", "*.lib")
            self.desc = f"working tree ({git('rev-parse', '--short=12', 'HEAD')}"
            self.desc += ", modified .lib)" if dirty else ")"
            self.tracked = True
            self.build_dir = os.path.join(build_dir, "work")
        else:
            sha, self.lib_dir = export_rev(rev, build_dir)
            self.rev, self.desc = sha, f"{rev} ({sha[:12]})"
            self.tracked = False
            self.build_dir = os.path.join(build_dir, sha[:12])


def test_specs(dsp_files):
    """(test file, test name) for every *_test definition of the files."""
    specs = []
    for path in dsp_files:
        with open(path) as f:
            for name in TEST_RE.findall(f.read()):
                specs.append((path, name))
    return specs


def default_dsp_files(side):
    """The test files of a side: tests/*.dsp, the tracked ones for the working tree.

    The working tree holds local scratch files next to the tests
    (tests/filters_tests.dsp...); an extracted commit holds tracked files only.
    """
    if side.tracked:
        out = git("ls-files", "tests/*.dsp")
        return sorted(os.path.join(ROOT, p) for p in out.split() if p.count("/") == 1)
    return sorted(glob.glob(os.path.join(side.lib_dir, "tests", "*.dsp")))


def newest_source(lib_dir, dsp):
    """The newest input of a build: a library, the test file or the architecture."""
    # The libraries and their subdirectories (dx7/...), not the builds and the
    # extracted commits below tests/, which would force a rebuild every time.
    libs = glob.glob(os.path.join(lib_dir, "*.lib")) + glob.glob(os.path.join(lib_dir, "*", "*.lib"))
    return max(os.path.getmtime(p) for p in libs + [dsp, ARCH])


def build(spec, side, cfg, args):
    """Build one test against one side with one compilation; return (exe, error).

    Each side and compilation has its own build directory. A build is reused
    when it is newer than its sources and was made by the same commands from
    the same test file (the .cmd stamp); otherwise it is redone.
    """
    dsp, name = spec
    cfg_dir = os.path.join(side.build_dir, cfg.slug(args.double))
    os.makedirs(cfg_dir, exist_ok=True)
    exe = os.path.join(cfg_dir, name)
    # The test file is copied next to the build, so that the only libraries in
    # sight are those of the side: faust looks in the current directory (set
    # to lib_dir below) and in the -I directory.
    src = os.path.join(cfg_dir, name + ".dsp")
    shutil.copyfile(dsp, src)
    cpp = exe + ".cpp"
    faust_cmd = [args.faust, *shlex.split(cfg.faust_options),
                 "-double" if args.double else "-single", "-t", "0", "-I", side.lib_dir,
                 "-a", ARCH, "-pn", name, src, "-o", cpp]
    cxx_cmd = [args.cxx, *shlex.split(cfg.cxx_options), "-std=c++17", cpp, "-o", exe]
    # The stamp holds the test file's content too: the copy above refreshes
    # its mtime at every run, so the mtime alone cannot tell it changed.
    stamp = exe + ".cmd"
    stamp_text = json.dumps([faust_cmd, cxx_cmd, open(dsp).read()])
    if (os.path.exists(exe) and os.path.getmtime(exe) >= newest_source(side.lib_dir, dsp)
            and os.path.exists(stamp) and open(stamp).read() == stamp_text):
        return exe, None
    r = subprocess.run(faust_cmd, capture_output=True, text=True, cwd=side.lib_dir)
    if r.returncode != 0:
        # Faust's last line is the error itself (an unknown symbol when the
        # base libraries lack a function the test uses, for instance).
        return None, "faust: " + (r.stderr.strip().splitlines() or ["?"])[-1]
    r = subprocess.run(cxx_cmd, capture_output=True, text=True)
    if r.returncode != 0:
        return None, "c++: " + (r.stderr.strip().splitlines() or ["?"])[0]
    with open(stamp, "w") as f:
        f.write(stamp_text)
    return exe, None


# Per-sample operations that are expensive on in-order and embedded cores.
DIV_RE = re.compile(r"(?<=[\w)\]]) / (?=[\w(])")
SQRT_RE = re.compile(r"\b(?:std::)?sqrtf?\(")
FN_RE = re.compile(r"\b(?:std::)?(pow|exp|exp2|exp10|expm1|log|log2|log10|log1p|sin|cos|tan|"
                   r"asin|acos|atan|atan2|sinh|cosh|tanh|asinh|acosh|atanh|cbrt|hypot|fmod|"
                   r"remainder)f?\(")
LOOP_RE = re.compile(r"for \(int (\w+) = 0; \1 < (count|vsize);")


def matching_brace(text, i):
    """Index of the brace closing the one at text[i]."""
    depth = 0
    for j in range(i, len(text)):
        depth += {"{": 1, "}": -1}.get(text[j], 0)
        if depth == 0:
            return j
    return len(text)


def loop_ops(exe):
    """Divisions, square roots and transcendental calls executed per sample.

    Counted in the code Faust generates, inside the per-sample loops of
    compute(): `i < count` in scalar code; in -vec code, the `i < vsize`
    loops of the first block only (the code for the remaining frames repeats
    them). The count is static: one occurrence in the loop is one operation
    per sample. It does not depend on the C++ options, although -ffast-math
    may still turn a division by a loop invariant into a multiplication.
    """
    with open(exe + ".cpp") as f:
        text = f.read()
    start = text.find("virtual void compute(")
    if start < 0:
        return None
    body = text[start:start + matching_brace(text, text.index("{", start)) - start]
    if "vindex" in body:
        cut = body.find("if (vindex < count)")
        body = body[:cut] if cut >= 0 else body
    div = sqrt = 0
    fns = {}
    for m in LOOP_RE.finditer(body):
        i = body.index("{", m.end())
        loop = body[i:matching_brace(body, i)]
        div += len(DIV_RE.findall(loop))
        sqrt += len(SQRT_RE.findall(loop))
        for name in FN_RE.findall(loop):
            fns[name] = fns.get(name, 0) + 1
    return {"div": div, "sqrt": sqrt, "fn": sum(fns.values()), "fns": fns}


def code_of(exe):
    """The generated C++ of a build, without the metadata lines (library
    versions, file names), which differ between sides that compute the same."""
    with open(exe + ".cpp") as f:
        return [line for line in f if "m->declare(" not in line]


def run_once(exe, args):
    """One timed run of a build: ((best ns/frame, finite), error)."""
    env = dict(os.environ, **FLASH_ENV, FLASH_SR=str(args.rate))
    try:
        r = subprocess.run([exe], capture_output=True, text=True, env=env, timeout=600)
    except subprocess.TimeoutExpired:
        return None, "timeout"
    m = RESULT_RE.search(r.stdout)
    if r.returncode != 0 or not m:
        return None, f"exit {r.returncode}"
    return (float(m.group(1)), m.group(2) == "1"), None


def on_battery():
    """True on a Mac running on battery (pmset); False when it cannot tell."""
    if platform.system() != "Darwin":
        return False
    try:
        out = subprocess.run(["pmset", "-g", "batt"], capture_output=True, text=True).stdout
    except OSError:
        return False
    return "Battery Power" in out


def first_line(cmd):
    """First line of a command's output (a --version), or "?"."""
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return ((out.stdout or out.stderr).strip().splitlines() or ["?"])[0]
    except (OSError, subprocess.TimeoutExpired):
        return "?"


def identity(args, sides, configs):
    """What a time depends on: machine, compilers (path and version), options, rate, sides.

    The compiler's path matters as much as its version: the c++ found first on
    the PATH is not necessarily the system one, and two clangs can differ by
    tens of percent on the same source.
    """
    if platform.system() == "Darwin":
        cpu = first_line(["sysctl", "-n", "machdep.cpu.brand_string"])
    else:
        cpu = platform.processor() or platform.machine()
    return {
        "machine": f"{cpu}, {platform.system()} {platform.release()}",
        "faust": f"{shutil.which(args.faust) or args.faust} ({first_line([args.faust, '--version'])})",
        "cxx": f"{shutil.which(args.cxx) or args.cxx} ({first_line([args.cxx, '--version'])})",
        "compilations": {c.name: c.describe(args.double) for c in configs},
        "rate": args.rate,
        "sides": {s.label: s.desc for s in sides},
    }


def interrupt(signum, frame):
    raise KeyboardInterrupt


def spread(times):
    """(max - min) / min of a side's rounds: the noise a ratio is read against.

    Deliberately pessimistic: the median reported ignores the extreme rounds
    that make the spread.
    """
    return (max(times) - min(times)) / min(times) if times and min(times) > 0 else None


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("dsp", nargs="*",
                   help="test files (default: tests/*.dsp of the new side)")
    p.add_argument("-k", "--filter", help="regex on test names")
    p.add_argument("--base", metavar="REV", help="compare with the libraries of REV")
    p.add_argument("--new", metavar="REV",
                   help="measure REV instead of the working tree (with --base)")
    p.add_argument("--rounds", type=int, default=3,
                   help="timed rounds per test and side (default: %(default)s)")
    p.add_argument("--rate", type=int, default=48000,
                   help="sample rate, for the DSP and the %%-of-a-core column (default: %(default)s)")
    p.add_argument("--double", action="store_true", help="compile with faust -double")
    p.add_argument("--faust-options", default="",
                   help='extra Faust options, e.g. --faust-options=-vec (default: none)')
    p.add_argument("--cxx-options", default=default_cxx_options(),
                   help='C++ optimization options (default: "%(default)s", as faustoptflags)')
    p.add_argument("--matrix", metavar="NAMES",
                   help="run the named compilations in turn, comma-separated, or all: "
                        + "; ".join(f"{n} = faust {f or '(no option)'}, c++ {c}"
                                    for n, (f, c) in CONFIGS.items()))
    p.add_argument("--faust", default=os.environ.get("FAUST", "faust"),
                   help="Faust compiler (default: $FAUST, else faust)")
    p.add_argument("--cxx", default=os.environ.get("CXX", "c++"),
                   help="C++ compiler (default: $CXX, else c++)")
    p.add_argument("-j", "--jobs", type=int, default=os.cpu_count(),
                   help="parallel builds (the timing is always sequential; default: %(default)s)")
    p.add_argument("--build-dir", default=os.path.join(ROOT, "tests", "build-cpu"),
                   help="builds and extracted revisions (default: tests/build-cpu)")
    p.add_argument("--json", help="write the identity and every measurement to this file")
    p.add_argument("--changed-only", action="store_true",
                   help="with --base: time only the tests whose generated C++ differs")
    p.add_argument("--fail-above", type=float, metavar="RATIO",
                   help="exit with 1 if a ratio new / base exceeds RATIO")
    p.add_argument("--allow-battery", action="store_true",
                   help="time even on battery power (results biased)")
    args = p.parse_args()
    if args.new and not args.base:
        p.error("--new needs --base")
    if args.changed_only and not args.base:
        p.error("--changed-only needs --base")
    if args.rounds < 1:
        p.error("--rounds must be at least 1")

    # The compilations: the default one, one set by the options, or a matrix.
    custom = args.faust_options or args.cxx_options != default_cxx_options()
    if args.matrix:
        if custom:
            p.error("--matrix and --faust-options/--cxx-options are exclusive")
        names = list(CONFIGS) if args.matrix == "all" else args.matrix.split(",")
        unknown = [n for n in names if n not in CONFIGS]
        if unknown:
            p.error(f"unknown compilation {', '.join(unknown)} (known: {', '.join(CONFIGS)})")
        configs = [Config(n, *CONFIGS[n]) for n in names]
    elif custom:
        configs = [Config("custom", args.faust_options, args.cxx_options)]
    else:
        configs = [Config("fast-math", *CONFIGS["fast-math"])]

    # The sides: the new one alone, or base then new. The build directory is
    # made absolute, since faust runs from each side's library directory.
    args.build_dir = os.path.abspath(args.build_dir)
    os.makedirs(args.build_dir, exist_ok=True)
    new = Side("new", args.new, args.build_dir)
    sides = [Side("base", args.base, args.build_dir), new] if args.base else [new]
    dsp_files = [os.path.abspath(f) for f in args.dsp] or default_dsp_files(new)
    specs = test_specs(dsp_files)
    if args.filter:
        specs = [s for s in specs if re.search(args.filter, s[1])]
    if not specs:
        p.error("no test selected")

    ident = identity(args, sides, configs)
    for key, value in ident.items():
        if isinstance(value, dict):
            for k, v in value.items():
                print(f"[cpu] {k}: {v}")
        else:
            print(f"[cpu] {key}: {value}")
    # Checked before building, so that a refused run costs nothing.
    if on_battery() and not args.allow_battery:
        sys.exit("[cpu] refused: on battery power (pmset); plug in, or --allow-battery "
                 "(results biased by frequency scaling)")

    # results[(test, compilation)] collects everything about one test in one
    # compilation; each side adds its own entry, ["base" | "new"], with either
    # an error or the times.
    t0 = time.time()
    results = {(s[1], c.name): {"test": s[1], "config": c.name,
                                "file": os.path.relpath(s[0], new.lib_dir)
                                if s[0].startswith(new.lib_dir) else s[0]}
               for c in configs for s in specs}

    # 1. Build every (test, side, compilation) in parallel. A test the base
    #    cannot compile (it uses a function the change adds) keeps an error on
    #    that side only.
    exes = {}
    with cf.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(build, spec, side, cfg, args): (spec, side, cfg)
                   for cfg in configs for spec in specs for side in sides}
        for fut in cf.as_completed(futures):
            (dsp, name), side, cfg = futures[fut]
            try:
                exe, err = fut.result()
            except Exception as e:  # report it, keep going
                exe, err = None, repr(e)
            if err:
                results[(name, cfg.name)][side.label] = {"error": err}
            else:
                exes[(name, cfg.name, side.label)] = exe
    # With --changed-only, a test whose two sides generate the same code is
    # not timed: it is reported as identical and left out of the table.
    identical = set()
    if args.changed_only:
        for s in specs:
            for cfg in configs:
                keys = [(s[1], cfg.name, side.label) for side in sides]
                if all(k in exes for k in keys) and code_of(exes[keys[0]]) == code_of(exes[keys[1]]):
                    identical.add((s[1], cfg.name))
                    results[(s[1], cfg.name)]["identical"] = True
                    for k in keys:
                        del exes[k]
        print(f"[cpu] --changed-only: {len(identical)} of {len(specs) * len(configs)} "
              "test builds generate the same code on both sides, not timed", flush=True)
    print(f"[cpu] {len(specs)} tests x {len(configs)} compilations built in "
          f"{time.time() - t0:.0f} s; timing {args.rounds} rounds", flush=True)
    time.sleep(4)  # thermal pause after the build burst

    # 2. Time them, one binary at a time, one test after the other: all the
    #    rounds of a test, then the next test, so that whatever has been
    #    measured survives an interruption. Within a round, the two sides run
    #    back to back, so that they see the same machine state; their order
    #    alternates from one round to the next, so that neither always runs
    #    first. A run that fails drops that (test, compilation, side) from the
    #    later rounds.
    def finish(name, cfg, times, finite):
        """Step 3 for one test: each side's median over the rounds.

        Inside a run, the flash judge keeps the minimum over its repetitions:
        there, noise only ever adds time. Across runs it does not: each process
        gets its own core, frequency and memory layout, and some runs are
        faster than all the others (an A/A comparison of identical code
        measured 1.27 with the minimum, one base run at 1.86 ns among 2.37s).
        The median ignores such a run in either direction. A test is finite
        only if every round was.
        """
        row = results[(name, cfg.name)]
        for label, ts in times.items():
            if ts and (name, cfg.name, label) in exes:
                ns = statistics.median(ts)
                row[label] = {"ns": ns, "min": min(ts), "rounds": ts, "spread": spread(ts),
                              "ops": loop_ops(exes[(name, cfg.name, label)]),
                              "finite": finite[label],
                              # ns/frame * frames/s = ns per second of audio
                              "core_percent": ns * args.rate * 1e-7}
        b, n = row.get("base", {}), row.get("new", {})
        if "ns" in b and "ns" in n and max(b["ns"], n["ns"]) >= TRIVIAL_NS:
            row["ratio"] = n["ns"] / b["ns"]
        if b.get("ops") and n.get("ops"):
            row["more_ops"] = any(n["ops"][k] > b["ops"][k] for k in ("div", "sqrt", "fn"))

    def write_json(complete):
        if args.json:
            with open(args.json, "w") as f:
                json.dump({"identity": ident, "rounds": args.rounds, "flash": FLASH_ENV,
                           "complete": complete,
                           "configs": {c.name: {"faust_options": c.faust_options,
                                                "cxx_options": c.cxx_options} for c in configs},
                           "results": [r for r in results.values() if measured(r)]},
                          f, indent=1)

    def measured(row):
        return any(s.label in row for s in sides) and not row.get("identical")

    # A kill (SIGTERM) is handled like Ctrl-C: report what was measured.
    signal.signal(signal.SIGTERM, interrupt)
    total, done, interrupted = len(specs) * len(configs) - len(identical), 0, False
    t1 = last = time.time()
    try:
        for cfg in configs:
            for dsp, name in specs:
                if (name, cfg.name) in identical:
                    continue
                times = {s.label: [] for s in sides}
                finite = {s.label: True for s in sides}

                def rounds(first, count):
                    for r in range(first, first + count):
                        order = sides if r % 2 == 0 else list(reversed(sides))
                        for side in order:
                            key = (name, cfg.name, side.label)
                            if key not in exes:
                                continue
                            res, err = run_once(exes[key], args)
                            if err:
                                results[(name, cfg.name)][side.label] = {"error": f"run: {err}"}
                                del exes[key]
                                continue
                            times[side.label].append(res[0])
                            finite[side.label] = finite[side.label] and res[1]

                rounds(0, args.rounds)
                # The re-race of fcautotool: a noisy test gets as many rounds
                # again, once. Trivial tests are not worth it.
                noisy = any(len(ts) > 1 and min(ts) >= TRIVIAL_NS and spread(ts) > RERACE_SPREAD
                            for ts in times.values())
                if noisy:
                    rounds(args.rounds, args.rounds)
                    results[(name, cfg.name)]["reraced"] = True
                finish(name, cfg, times, finite)
                done += 1
                # Progress, and the JSON so far, every 30 s.
                now = time.time()
                if now - last >= 30 and done < total:
                    left = (now - t1) / done * (total - done)
                    print(f"[cpu] {done}/{total} timed in {(now - t1) / 60:.0f} min, "
                          f"about {left / 60:.0f} min left ({cfg.name}, {name})", flush=True)
                    write_json(False)
                    last = now
    except KeyboardInterrupt:
        interrupted = True
        print(f"\n[cpu] interrupted: {done} of {total} timed, reported below", flush=True)

    # 4. Report: one table and one summary line per compilation, then the
    #    JSON. The ratios are summarized by their geometric mean, the mean
    #    that treats x2 and /2 symmetrically. After an interruption, only the
    #    tests measured are reported (a build error counts as measured).
    summaries, rows = [], []
    for cfg in configs:
        crows = [results[(s[1], cfg.name)] for s in specs]
        crows = [r for r in crows if measured(r)]
        if not crows:
            summaries.append(f"{cfg.name}: no test to report (every build generates the same "
                             "code on both sides, or none was measured)")
            continue
        rows += crows
        print(f"\n[{cfg.name}] {cfg.describe(args.double)}")
        report(crows, args)
        ratios = [r["ratio"] for r in crows if "ratio" in r]
        errors = sum(1 for r in crows for s in sides if "error" in r.get(s.label, {}))
        line = f"{cfg.name}: {len(crows)} tests"
        if ratios:
            geo = 1.0
            for x in ratios:
                geo *= x
            geo **= 1.0 / len(ratios)
            line += (f", ratio new / base {min(ratios):.2f} to {max(ratios):.2f}, "
                     f"geometric mean {geo:.2f}")
        if errors:
            line += f", {errors} build or run errors"
        same = sum(1 for s in specs if (s[1], cfg.name) in identical)
        if same:
            line += f"; {same} more generate the same code on both sides (not timed)"
        summaries.append(line)
    write_json(not interrupted)
    print(f"\n[cpu] {'interrupted' if interrupted else 'done'} after {time.time() - t0:.0f} s")
    for line in summaries:
        print(f"[cpu] {line}")
    if interrupted:
        return 130
    # Only on request: a ratio is a measurement to discuss, not a verdict,
    # and a fix that buys precision may be worth a slower test.
    if args.fail_above is not None:
        above = [r for r in rows if r.get("ratio", 0) > args.fail_above]
        if above:
            print(f"[cpu] {len(above)} results above {args.fail_above:g}: "
                  + ", ".join(f"{r['test']} ({r['config']})" for r in above))
            return 1
    return 0


def cell(side):
    """A side's time for the table: ns, with NaN when the output was not finite."""
    if not side:
        return "-"
    if "error" in side:
        return "error"
    text = f"{side['ns']:.2f}"
    if not side["finite"]:
        text += " NaN"
    return text


def ops_cell(side):
    ops = side.get("ops")
    return f"{ops['div']}/{ops['sqrt']}/{ops['fn']}" if ops else "-"


def report(rows, args):
    """Print the table, then the errors with their reason.

    The % core column is the new side's; the spread column is the worst of
    the two sides, since a ratio is only as reliable as its noisier side, and
    is marked * when the test was re-raced. A trivial test (below TRIVIAL_NS
    on both sides) has no ratio.
    """
    compare = args.base is not None
    width = max([len(r["test"]) for r in rows] + [4])
    head = f"{'test':<{width}}  "
    head += f"{'base ns':>10}  {'new ns':>10}  {'ratio':>6}" if compare else f"{'ns':>10}"
    head += f"  {'% core':>7}  {'spread':>6}  "
    head += f"{'ops base > new':>16}" if compare else f"{'ops':>8}"
    print("\n" + head)
    for r in rows:
        n = r.get("new", {})
        line = f"{r['test']:<{width}}  "
        if compare:
            ratio = f"{r['ratio']:.2f}" if "ratio" in r else "-"
            line += f"{cell(r.get('base')):>10}  {cell(n):>10}  {ratio:>6}"
        else:
            line += f"{cell(n):>10}"
        core = f"{n['core_percent']:.3f}" if "ns" in n else "-"
        spreads = [s.get("spread") for s in (r.get("base", {}), n) if s.get("spread") is not None]
        worst = f"{100 * max(spreads):.0f}%" if spreads else "-"
        if r.get("reraced"):
            worst += "*"
        line += f"  {core:>7}  {worst:>6}  "
        if compare:
            ops = f"{ops_cell(r.get('base', {}))} > {ops_cell(n)}"
            ops += " !" if r.get("more_ops") else "  "
            line += f"{ops:>16}"
        else:
            line += f"{ops_cell(n):>8}"
        print(line)
    print("ops: divisions / square roots / transcendental calls per sample, in the generated loop"
          + ("; ! = more on the new side" if compare else ""))
    if any(r.get("reraced") for r in rows):
        print(f"* spread above {100 * RERACE_SPREAD:.0f}% after --rounds rounds: "
              "re-raced with as many rounds again")
    for r in rows:
        for label in ("base", "new"):
            if "error" in r.get(label, {}):
                print(f"[error] {r['test']} ({label}): {r[label]['error']}")


if __name__ == "__main__":
    sys.exit(main())
