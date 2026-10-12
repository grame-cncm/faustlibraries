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

For WebAssembly, the modules are also validated with Node
(`WebAssembly.validate`, the check a browser makes before running one): faust
can emit a module that does not validate although its compilation succeeds.
In October 2026, 107 tests did, all with a pow of two integers and a variable
exponent compiled in single precision; a compilation alone saw none of them.
A module that does not validate fails like a test that does not compile, with
V8's error.

The modules that validate are then run in Node, as the C++ harness of
`make check` runs the tests (arch/precision_arch.cpp): one second at 48 kHz,
the inputs at 0, the controls at their default values, the buttons and
checkboxes pressed for the first half and released for the second, in blocks
of 512 frames, the math functions imported from JavaScript's `Math` as in
faustwasm. A module that stops (a trap: an integer conversion of a NaN, an
access out of the memory) or writes a non-finite sample fails, with the
error and the frame. A validation sees neither: in October 2026 a module
stopped on `int()` of a NaN, which only an execution shows. Without node (or
with --no-validate) the modules are neither validated nor run, and
--no-run validates them without running them; the output says so.

For Cmajor, the code faust generates is also compiled and run by Cmajor
itself, with `cmaj render` (one second at 48 kHz after the silence `cmaj
render` starts with, the controls at their default values: `cmaj render`
cannot press a button): `faust -lang cmajor` succeeding does not mean that
Cmajor accepts the code. A patch that Cmajor rejects, that stops, or that
writes a non-finite sample fails. Without `cmaj` the patches are only
generated, which the output says.

With --run-julia, the Julia code is also loaded and run (one second at 48 kHz,
as for WebAssembly, buttons included), in a few Julia processes run in
parallel: Julia compiles each program, 0.3 to 3 s, so this takes minutes and
is not done by default. A program that does not load (an undefined name: in
October 2026 the constant INFINITY), that throws (InexactError: the
conversion of a NaN to an integer) or that writes a non-finite sample fails.

    scripts/check_backends.py                    # the backends of the baseline
    scripts/check_backends.py --lang wasm,java   # these backends
    scripts/check_backends.py --changed          # only if a .lib or test differs from HEAD
    scripts/check_backends.py --update-baseline  # record the current debt
    scripts/check_backends.py --no-validate      # compile only, do not validate wasm modules
    scripts/check_backends.py --no-run           # validate the wasm modules, run nothing
    scripts/check_backends.py --run-julia        # also load and run the Julia code
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
import array
import concurrent.futures as cf
import json
import math
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
NODE = os.environ.get("NODE", "node")
CMAJ = os.environ.get("CMAJ", "cmaj")
JULIA = os.environ.get("JULIA", "julia")
SR = 48000
# cmaj render writes this many frames of silence before the patch's output (measured with
# Cmajor 1.0: 20480 at a block size of 512); the render is that much longer
CMAJ_SILENCE = 20480
# A top-level definition `name_test = ...` at the start of a line, as in
# scripts/extract_tests.sh and check_precision.py.
TEST_RE = re.compile(r"^[ \t]*([A-Za-z_][A-Za-z0-9_]*_test)[ \t]*=", re.M)
NOT_BUILT = ("not supported since", "cannot find backend")
# Reads {"run": bool, "paths": [.wasm paths]} on stdin, prints {path: [kind, error]} for the
# modules that do not validate ("invalid") and, with run, for those that stop or write a
# non-finite sample ("run"). A module runs as in arch/precision_arch.cpp: SR frames at SR
# (one second), inputs at 0, default controls, buttons and checkboxes at 1 for the first half
# and at 0 for the second, in blocks of BLOCK frames. Its JSON (faust writes it next to the
# module) gives the size of the DSP, the channels and the offsets of the controls.
WASM_JS = r"""
const fs = require("fs");
const SR = 48000, BLOCK = 512;
const rint = (x) => { const r = Math.round(x); return (r - x === 0.5 && r % 2 !== 0) ? r - 1 : r; };
const special = {
    exp10: (x) => Math.pow(10, x), fmod: (x, y) => x % y, rint, nearbyint: rint,
    remainder: (x, y) => x - rint(x / y) * y, round: (x) => Math.sign(x) * Math.round(Math.abs(x)),
    isnan: (x) => (Number.isNaN(x) ? 1 : 0),
    isinf: (x) => (Number.isFinite(x) || Number.isNaN(x) ? 0 : 1),
    copysign: (x, y) => ((y < 0 || Object.is(y, -0)) ? -Math.abs(x) : Math.abs(x)),
};
function imports(module) {
    const env = {};
    for (const imp of WebAssembly.Module.imports(module)) {
        if (imp.kind !== "function") throw new Error(`harness: no ${imp.kind} import ${imp.name}`);
        const name = imp.name.replace(/^_/, "");
        const fn = special[name] ?? Math[name] ?? special[name.slice(0, -1)] ?? Math[name.slice(0, -1)];
        if (typeof fn !== "function") throw new Error(`harness: no import for ${imp.name}`);
        env[imp.name] = fn;
    }
    return { env };
}
function switches(items, out = []) {
    for (const it of items || []) {
        if (it.items) switches(it.items, out);
        else if ((it.type === "button" || it.type === "checkbox") && it.index !== undefined) out.push(Number(it.index));
    }
    return out;
}
function run(path, module) {
    const json = JSON.parse(fs.readFileSync(path.replace(/\.wasm$/, ".json"), "utf8"));
    const dsp = new WebAssembly.Instance(module, imports(module)).exports;
    const nins = Number(json.inputs), nouts = Number(json.outputs);
    const real = json.compile_options && /-double/.test(json.compile_options) ? 8 : 4;
    const base = (Number(json.size) + 15) & ~15;
    const ptrIns = base, ptrOuts = ptrIns + 4 * nins;
    const bufIns = (ptrOuts + 4 * nouts + 15) & ~15, bufOuts = bufIns + real * BLOCK * nins;
    const end = bufOuts + real * BLOCK * nouts;
    const mem = dsp.memory;
    if (end > mem.buffer.byteLength) mem.grow(Math.ceil((end - mem.buffer.byteLength) / 65536));
    const h32 = new Int32Array(mem.buffer);
    const out = real === 8 ? new Float64Array(mem.buffer) : new Float32Array(mem.buffer);
    for (let i = 0; i < nins; i++) h32[(ptrIns >> 2) + i] = bufIns + real * BLOCK * i;
    for (let i = 0; i < nouts; i++) h32[(ptrOuts >> 2) + i] = bufOuts + real * BLOCK * i;
    dsp.init(0, SR);
    const sw = switches(json.ui);
    const set = (v) => { for (const index of sw) dsp.setParamValue(0, index, v); };
    set(1);
    for (let done = 0; done < SR; done += BLOCK) {
        if (sw.length && done === SR / 2) set(0);
        const n = Math.min(BLOCK, SR - done);
        new (real === 8 ? Float64Array : Float32Array)(mem.buffer, bufIns, BLOCK * nins).fill(0);
        try { dsp.compute(0, n, ptrIns, ptrOuts); }
        catch (e) { return `${e.message}, in frames ${done} to ${done + n - 1}`; }
        for (let c = 0; c < nouts; c++)
            for (let k = 0; k < n; k++) {
                const v = out[(bufOuts / real) + c * BLOCK + k];
                if (!Number.isFinite(v)) return `non-finite output ${v} on channel ${c} at frame ${done + k}`;
            }
    }
    return null;
}
const { run: doRun, paths } = JSON.parse(fs.readFileSync(0, "utf8"));
const bad = {};
for (const p of paths) {
    const bytes = fs.readFileSync(p);
    if (!WebAssembly.validate(bytes)) {
        try { new WebAssembly.Module(bytes); bad[p] = ["invalid", "invalid module"]; }
        catch (e) { bad[p] = ["invalid", e.message]; }
        continue;
    }
    if (!doRun) continue;
    const module = new WebAssembly.Module(bytes);
    // A program with a soundfile imports its memory, which faustwasm's JavaScript glue
    // provides and fills with the sound files: without it, a run means nothing.
    if (WebAssembly.Module.imports(module).some((i) => i.kind === "memory")) { bad[p] = ["skip", "imports its memory"]; continue; }
    try { const e = run(p, module); if (e) bad[p] = ["run", e]; }
    catch (e) { bad[p] = ["run", e.message]; }
}
process.stdout.write(JSON.stringify(bad));
"""


def dsp_files(paths):
    if paths:
        return [Path(p).resolve() for p in paths]
    out = subprocess.run(["git", "ls-files", "tests/*.dsp"], cwd=ROOT,
                         capture_output=True, text=True).stdout.split()
    return sorted(ROOT / p for p in out if p.count("/") == 1)


def test_specs(files):
    return [(f, name) for f in files for name in TEST_RE.findall(f.read_text())]


def compile_error(lang, path, name, out=os.devnull):
    """None when the test compiles for `lang` (the code written to `out`), else faust's error line."""
    r = subprocess.run([FAUST, "-lang", lang, "-I", str(ROOT), "-pn", name, str(path),
                        "-o", str(out)], cwd=ROOT, capture_output=True, text=True)
    if r.returncode == 0:
        return None
    lines = [line.strip() for line in r.stderr.splitlines()
             if "ERROR" in line or "ASSERT" in line]
    return (lines or [r.stderr.strip() or "failed"])[0]


def bad_modules(paths, run):
    """{path: (kind, error)} for the WebAssembly modules that do not validate ("invalid",
    V8's error) and, with run, for those that stop or write a non-finite sample ("run") and
    those not run because they import their memory ("skip": a soundfile)."""
    r = subprocess.run([NODE, "-e", WASM_JS],
                       input=json.dumps({"run": run, "paths": [str(p) for p in paths]}),
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError("node: " + (r.stderr.strip().splitlines() or ["failed"])[-1])
    # "WebAssembly.Module(): Compiling function #2 failed: ... @+477": the prefix and the
    # byte offset say nothing about the test
    return {Path(p): (kind, re.sub(r"^WebAssembly\.Module\(\): | @\+\d+$", "", e))
            for p, (kind, e) in json.loads(r.stdout or "{}").items()}


def wasm_errors(specs, pool, run):
    """compile_error for wasm, plus the validation and, with run, the execution of the modules
    that compiled, in chunks run by node in parallel; and the names of the tests not run."""
    with tempfile.TemporaryDirectory() as tmp:
        outs = [Path(tmp) / f"{i}.wasm" for i in range(len(specs))]
        errors = list(pool.map(lambda s, o: compile_error("wasm", *s, o), specs, outs))
        ok = [o for o, e in zip(outs, errors) if e is None]
        chunks = [ok[i::os.cpu_count() or 1] for i in range(os.cpu_count() or 1)]
        bad = {}
        for part in pool.map(lambda c: bad_modules(c, run) if c else {}, chunks):
            bad.update(part)
    label = {"invalid": "invalid module, a faust bug", "run": "the module fails when run"}
    skipped = [name for (_, name), o in zip(specs, outs) if bad.get(o, ("",))[0] == "skip"]
    return [e or (f"{label[bad[o][0]]}: {bad[o][1]}" if o in bad and bad[o][0] != "skip"
                  else None) for o, e in zip(outs, errors)], skipped


def wav_samples(path):
    """(channels, float32 samples interleaved) of the WAV file cmaj render writes."""
    data = Path(path).read_bytes()
    i, channels, samples = 12, 0, b""
    while i + 8 <= len(data):
        cid, size = data[i:i + 4], int.from_bytes(data[i + 4:i + 8], "little")
        if cid == b"fmt ":
            channels = int.from_bytes(data[i + 10:i + 12], "little")
        elif cid == b"data":
            samples = data[i + 8:i + 8 + size]
        i += 8 + size + (size & 1)
    a = array.array("f")
    a.frombytes(samples[:len(samples) // 4 * 4])
    return channels, a


def cmajor_run_error(code):
    """None when Cmajor compiles and renders the generated patch with finite samples."""
    outs = len(re.findall(r"^\s*output stream ", code.read_text(), re.M))
    if outs == 0:
        return None
    patch = code.with_suffix(".cmajorpatch")
    patch.write_text(json.dumps({"CmajorVersion": 1, "ID": "dev.faust.check", "version": "1.0",
                                 "name": code.stem, "source": code.name}))
    wav = code.with_suffix(".wav")
    r = subprocess.run([CMAJ, "render", f"--length={SR + CMAJ_SILENCE}", f"--rate={SR}",
                        f"--channels={outs}", "--blockSize=512", f"--output={wav}", str(patch)],
                       capture_output=True, text=True, timeout=300)
    if r.returncode != 0 or not wav.exists():
        # cmaj render exits with 1 without saying why: building the patch alone prints the error
        d = subprocess.run([CMAJ, "play", "--dry-run", str(patch)], capture_output=True,
                           text=True, timeout=300)
        lines = [re.sub(r"^.*?:\d+:\d+: ", "", line.strip())
                 for line in (r.stdout + r.stderr + d.stdout + d.stderr).splitlines()
                 if "error" in line.lower()]
        return "Cmajor rejects the code: " + (lines or ["cmaj render failed"])[0]
    channels, a = wav_samples(wav)
    for k, v in enumerate(a):
        if not math.isfinite(v):
            return (f"the patch fails when run: non-finite output {v} on channel"
                    f" {k % channels} at frame {k // channels - CMAJ_SILENCE}")
    return None


def cmajor_errors(specs, pool, run):
    """compile_error for cmajor, plus, with run, the compilation and the render by Cmajor."""
    with tempfile.TemporaryDirectory() as tmp:
        outs = [Path(tmp) / f"t{i}.cmajor" for i in range(len(specs))]
        errors = list(pool.map(lambda s, o: compile_error("cmajor", *s, o), specs, outs))
        if run:
            ran = list(pool.map(lambda o, e: None if e else cmajor_run_error(o), outs, errors))
            errors = [e or r for e, r in zip(errors, ran)]
    return errors


# Reads the paths of the generated files in ARGS, prints one line per file: its path, a tab,
# then "ok" or the error. Each program is loaded in a module of its own, with the base types
# and UI functions of architecture/julia defined there, then run as WASM_JS runs a module.
JULIA_JS = r"""
function run_one(path)
    m = Module(:FaustCheck)
    Core.eval(m, quote
        const FAUSTFLOAT = Float32
        abstract type dsp end
        abstract type FMeta end
        abstract type UI end
        openTabBox!(ui::UI, label) = nothing
        openHorizontalBox!(ui::UI, label) = nothing
        openVerticalBox!(ui::UI, label) = nothing
        closeBox!(ui::UI) = nothing
        declare!(x, args...) = nothing
        addButton!(ui::UI, args...) = nothing
        addCheckButton!(ui::UI, args...) = nothing
        addHorizontalSlider!(ui::UI, args...) = nothing
        addVerticalSlider!(ui::UI, args...) = nothing
        addNumEntry!(ui::UI, args...) = nothing
        addHorizontalBargraph!(ui::UI, args...) = nothing
        addVerticalBargraph!(ui::UI, args...) = nothing
        addSoundfile!(ui::UI, args...) = nothing
    end)
    try
        Base.include(m, path)
        Core.eval(m, quote
            mutable struct SwitchUI <: UI; zones::Vector{Symbol}; end
            addButton!(ui::SwitchUI, label, p::Symbol) = push!(ui.zones, p)
            addCheckButton!(ui::SwitchUI, label, p::Symbol) = push!(ui.zones, p)
            function faust_check_run(SR, BLOCK)
                d = mydsp{REAL}()
                init!(d, Int32(SR))
                ui = SwitchUI(Symbol[])
                buildUserInterface!(d, ui)
                set(v) = for z in ui.zones; setproperty!(d, z, FAUSTFLOAT(v)); end
                set(1)
                ins = zeros(FAUSTFLOAT, BLOCK, getNumInputs(d))
                outs = zeros(FAUSTFLOAT, BLOCK, getNumOutputs(d))
                done = 0
                while done < SR
                    (!isempty(ui.zones) && done == SR ÷ 2) && set(0)
                    n = min(BLOCK, SR - done)
                    compute!(d, Int32(n), ins, outs)
                    for c in 1:size(outs, 2), k in 1:n
                        isfinite(outs[k, c]) || return "non-finite output $(outs[k, c]) on channel $(c - 1) at frame $(done + k - 1)"
                    end
                    done += n
                end
                "ok"
            end
        end)
        return Base.invokelatest(m.faust_check_run, SR_VALUE, 512)
    catch e
        return first(split(sprint(showerror, e), '
'))
    end
end
for p in ARGS
    r = run_one(p)
    println(p, "	", replace(r, '
' => ' '))
    flush(stdout)
end
""".replace("SR_VALUE", str(SR))


def julia_errors(specs, pool, run):
    """compile_error for julia, plus, with run, the loading and the run of the code by Julia,
    in chunks run by Julia processes in parallel."""
    with tempfile.TemporaryDirectory() as tmp:
        outs = [Path(tmp) / f"t{i}.jl" for i in range(len(specs))]
        errors = list(pool.map(lambda s, o: compile_error("julia", *s, o), specs, outs))
        if run:
            runner = Path(tmp) / "faust_check_runner.jl"
            runner.write_text(JULIA_JS)
            ok = [o for o, e in zip(outs, errors) if e is None]
            n = os.cpu_count() or 1
            chunks = [ok[i::n] for i in range(n)]

            def run_chunk(chunk):
                if not chunk:
                    return {}
                r = subprocess.run([JULIA, "--startup-file=no", "--depwarn=no", str(runner),
                                    *map(str, chunk)], capture_output=True, text=True)
                res = {}
                for line in r.stdout.splitlines():
                    path, _, verdict = line.partition("\t")
                    res[Path(path)] = verdict
                for o in chunk:  # a file the process did not reach: it died on the one before
                    res.setdefault(o, "julia stopped: " + ((r.stderr.strip().splitlines()
                                                            or ["no output"])[-1]))
                return res

            bad = {}
            for part in pool.map(run_chunk, chunks):
                bad.update(part)
            errors = [e or (None if bad.get(o) == "ok" else f"the code fails when run: {bad[o]}")
                      for o, e in zip(outs, errors)]
    return errors


RUN_FAILURES = ("fails when run", "rejects the code", "invalid module")


def is_run_failure(error):
    """True for a failure that only the toolchain of the backend sees: a validation or a run."""
    return any(k in error for k in RUN_FAILURES)


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
    p.add_argument("--no-validate", action="store_true",
                   help="do not validate (nor run) the WebAssembly modules with node")
    p.add_argument("--no-run", action="store_true",
                   help="validate the WebAssembly modules, run nothing (nor Cmajor's render)")
    p.add_argument("--run-julia", action="store_true",
                   help="also load and run the Julia code (minutes: Julia compiles each test)")
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

    validate = not args.no_validate and shutil.which(NODE)
    failures, notes, ran = {}, [], set()
    with cf.ThreadPoolExecutor(args.jobs) as pool:
        for lang in langs:
            if not backend_built(lang):
                notes.append(f"{lang}: skipped, this faust is built without that backend")
                continue
            if lang == "wasm" and validate:
                errors, skipped = wasm_errors(specs, pool, not args.no_run)
                ran.update(["wasm"] if not args.no_run else [])
                if args.no_run:
                    notes.append("wasm: modules validated, not run")
                elif skipped:
                    notes.append(f"wasm: {len(skipped)} module(s) validated, not run: they import"
                                 f" their memory, as a soundfile does ({', '.join(skipped)})")
            elif lang == "cmajor":
                run = not args.no_run and shutil.which(CMAJ)
                if not run:
                    notes.append("cmajor: patches generated, not compiled nor run by Cmajor"
                                 + ("" if args.no_run else f" ({CMAJ} not found)"))
                errors = cmajor_errors(specs, pool, run)
                ran.update(["cmajor"] if run else [])
            elif lang == "julia":
                run = args.run_julia and not args.no_run and shutil.which(JULIA)
                if args.run_julia and not run:
                    notes.append("julia: code generated, not run"
                                 + ("" if args.no_run else f" ({JULIA} not found)"))
                errors = julia_errors(specs, pool, run)
                ran.update(["julia"] if run else [])
            else:
                if lang == "wasm":
                    notes.append("wasm: modules compiled, neither validated nor run"
                                 + ("" if args.no_validate else f" ({NODE} not found)"))
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
        # an entry recorded by a run (or by the backend's own compiler) is only expected
        # when this run did it
        expected = {name for name, e in accepted.items() if lang in ran or not is_run_failure(e)}
        problems += [f"{lang}: {name} now compiles: remove it from {BASELINE.name}"
                     for name in sorted(expected) if name in covered and name not in failed]

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
        if any(k in line for line in problems
               for k in ("invalid module", "fails when run", "rejects the code")):
            print("Code that compiles but that the backend's own toolchain rejects (a WebAssembly"
                  " module that does not validate, Cmajor or Julia code that does not load), or"
                  " that stops or writes a non-finite sample where the C++ build in single"
                  f" precision does not, is a bug of faust, not of the libraries"
                  f" ({shutil.which(FAUST)}): check with the current faust (FAUST=...), and"
                  " report it if it persists. A non-finite sample that the C++ build in -single"
                  f" gives too (ma.MIN * 1e307) is the test's: record it in {BASELINE.name}.")
        return 1
    accepted = sum(len(baseline[lang]) for lang in failures if lang in baseline)
    print(f"check_backends: OK ({len(specs)} tests: {summary}; accepted debt: {accepted})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
