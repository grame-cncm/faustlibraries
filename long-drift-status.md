# Working log: branch `long-drift`

State on 2026-10-12, 23:30. The working log of the branch, kept while it was
made and committed for its reviewers. The analysis itself is in
[long-drift-analysis.md](long-drift-analysis.md).

## The goal

Fix the single-precision drifts found by `make check-long`. Their causes are
analysed in `long-drift-analysis.md`. At the end, open a PR on
`grame-cncm/faustlibraries` and ask Julius for his opinion (Julius O.
Smith: `nlf2`, `oscr*` and `latch_demo` are his), and Yann Orlarey for his,
since he is working on compiler improvements.

The branch `long-drift` starts from `origin/master` (`f748824c`).

## Commits

| commit | content |
|---|---|
| `44cafed3` | `long-drift-analysis.md` (the analysis, updated since, see below) |
| `3eaba53e` | `check_long.py` executable |
| `9be9f344` | `check_precision.py`: `newest_source` also sees `dx7/*.lib` (before, a change in `dx7/` did not rebuild the tests) |
| `d9d06e1a` | **harness**: `-I dx7` everywhere (Makefile `FAUST_INCLUDES`, `check_precision`, `check_cpu`, `check_backends`, `check_usage`). Before, every harness tested the **installed** DX7 libraries (`/usr/local/share/faust`), not those of the repository |
| `bf22335d` | DX7: `m_hsp_phasor` = `os.lf_sawpos_phase_reset`; 33 baseline entries removed; reference of `operator_modulated_test` regenerated (3e-5) |
| `5c76078f` | `fd.hammer`: recursion on the step `v = u − u'`, a `min(ma.MAX)` barrier on the step; single/double gap from 3.5e-2 to 1.2e-7; 2 entries removed; `hammer*` references regenerated |
| `d7123142` | `phasor_modulated_test`: frequency built from integers; 1 entry removed |
| `0f481310` | `unwrap_test` unwraps a wrapped phase (`4*os.tosc(100)`); 1 entry removed |
| `3b52f5e0` | `dm.latch_demo`: `os.osc` instead of `os.oscr`/`os.oscrs`; 1 entry removed, and `latch_demo_test` leaves `precision-baseline.json` |
| `b754ce6e` | `faust-normalizer-issues.md`: the 8 normalizer rewrites the libraries work around |
| `6a1f00ce` | `no.lfnoise0`: triggered on the phase of `os.lf_sawpos`, not on the float sine (otherwise `lfnoise0_test` fails `check-precision` after the next commit) |
| `63a86268` | `os.oscrq` (so `oscrs`, `oscrc`, `oscrp`, `oscr`): amplitude correction `g = 1.5 − 0.5·(y0² + y1²)` at every step; 9 entries removed |
| `bd8f5ae0` | `si.smooth` becomes `imp(3)` (see below); 4 entries removed from `long-baseline.json`, 2 from `precision-baseline.json` |
| `a7c0fba3` | `long-drift-analysis.md`: "What the branch changed", the checks, the CPU cost |
| `3ac0f1cf` | `version.lib` 2.80.1 |

Library versions raised: `operator.lib` 2.0.2, `fds.lib` 1.1.3,
`oscillators.lib` 1.9.6, `maths.lib` 2.9.4, `demos.lib` 1.7.1,
`noises.lib` 1.9.1, `signals.lib` 1.8.1; `version.lib` 2.80.1, once for the
batch (PATCH: fixes only, as everything since 2.80.0).

## `si.smooth` (`bd8f5ae0`)

1. **`signals.lib`**: `si.smooth` becomes `imp(3)`, which smooths the error
   `e = y − x` and therefore has no dead band:

   ```faust
   (3,s) => \(x).(x + (fb ~ _ with { fb(e) = s * (e + (x' - x : min(ma.MAX))); }));
   ```

   The `min(ma.MAX)` barrier is needed: without it, clang `-ffast-math`
   reassociates `(x' − x) + e'` into `(x' + e') − x`, and the dead band comes
   back. There is also a comment above `smooth = imp(3)`.
2. **`signals.lib` and `tests/signals_tests.dsp`**: the new test
   `smooth_deadband_test`, which pins the fix:

   ```faust
   smooth_deadband_test = x : si.smooth(ba.tau2pole(0.01)) <: _, (ba.time > 0.9*ma.SR) * (abs(_ - x) > 1e-15) with { x = 0.7; };
   ```

   Its second output is 0 with the new form, in both precisions and under
   `-ffast-math`; it is 1 for the whole last 0.1 s with the old one. Its
   reference is generated.

### Checks on the whole branch, `si.smooth` included

- `make check`: 2325 tests; no reference changes beyond those regenerated
  in their commits.
- `check-precision`, `check-extremes`, `check-backends`, all complete: no
  new failure.
- **The precision matrix** on `signals`, `demos` and `physmodels`:

  ```bash
  scripts/check_precision.py tests/signals_tests.dsp tests/demos_tests.dsp tests/physmodels_tests.dsp --matrix all
  ```

  256 tests × 4 configurations: the only failure is
  `[fast-math] fdnrev0_demo_test`, which **already exists on
  `origin/master`** and is unrelated to the branch (reported in the PR, not
  fixed here). `reverbTank_demo_test` and `vital_rev_demo_test` leave
  `precision-baseline.json` (`si.smooth` makes them unnecessary: checked on
  the branch without it). Careful: `FileNotFoundError`s in an earlier run
  came from two matrices started at the same time in the same build
  directory. **Never run two checks that share `tests/build-precision`.**
- **`check-long` on every test** (`scripts/check_long.py -j 6`, 33 min):
  0 new failure, 4 entries made unnecessary and removed from
  `tests/long-baseline.json`:
  - `flute_ui_MIDI_test`, `virtual_analog_oscillator_demo_test`, and the
    `drift` of `sawtooth_demo_test` (its `growth` stays), as expected;
  - the `subnormal` of `violin_ui_MIDI_test`: 11.2 million subnormal output
    samples after the release before, none now, checked to come from
    `si.smooth` on the branch without it. **Mechanism not analysed**: a new
    `subnormal` was rather expected, since the state `e` also decays
    geometrically towards 0.
- `make check-plots`: 160 figures up to date, all property assertions hold.
- `make checkdoc` before each commit.

## The two memory saturations (12 October, 21:10 and 21:55)

The machine ran out of memory twice (over 100 GB, one reboot). The cause was
`faust -lang ocpp` in the precision matrix, growing without bound on
`spectral_level_demo_test` and `mth_octave_spectral_level_demo_test` (the
`.cpp` files stayed empty), once `si.smooth` was `imp(3)`. On
`origin/master`, ocpp compiles that test in 1 s.

- The trigger on the faust side (an ocpp bug): an `x` reused outside a
  recursion (`y = x + e`, or even `x + 0.5*(x' - x)` without a recursion),
  placed in the cascade of `an.mth_octave_analyzer6e`, then in a
  `vbargraph` + `attach`. The growth is exponential in the number of bands
  N: 790 MB at N = 12, over 3 GB at N = 20. With `-lang cpp` it is
  instantaneous.
- Every error-state form tried has it: with or without the barrier, `d`
  computed first, `y` computed as a second output of the recursion. `imp(0)`
  does not.
- **The bug**: `ScalarCompiler::displayExpr` inlined the block-rate tail of
  a bargraph with no sharing, so a node used twice was written out twice:
  2^D copies for D shared levels. Fixed on the faust branch
  `display-tail-sharing` (`122875dfa`), grame-cncm/faust#1347, review asked
  of Yann, with a comment saying it is a quick fix to unblock these tests,
  with no guarantee it is the right one. With it, the test compiles in under
  90 MB, and the matrix above was run with that faust. faust's Gate 1
  (`cpp-core`, `ocpp`, `ocpp-float`) shows no failure caused by the fix,
  but no impulse program goes through the changed code either (results
  posted on #1347).
- To probe faust on its own, always run it under a memory watchdog, and one
  that reads the memory footprint (`top`'s `MEM`, as Activity Monitor), not
  the RSS, which leaves out compressed memory.

## What stays in the `check-long` baseline, and why

- `saw4_jump_test`: the float rounding of `f/SR`, made audible by a 100:1
  jump. Two other sets of frequencies were tried, without effect.
- `lf_imptrain_test`: a measurement artifact (one impulse moves from one
  second to the next). 3.1 Hz would not have helped.
- `sawtooth_demo_test` `growth`: the checkboxes select the noise input
  during the hold. It is expected.
- The RMS compressors (sliding sums), the 67 remaining `subnormal` and
  `FTZ_test`/`MIN_test`: already explained before the branch.

## CPU cost

Measured against `origin/master` with `scripts/check_cpu.py --matrix all`
(fast-math, strict, vec) on the touched tests and on the callers that
multiply them (the spectral-level demos, `vocoder_demo`). The table is in
`long-drift-analysis.md`, section "CPU cost". In short: `os.oscrq`'s
correction costs about 3 ns per sample (×1.4 to ×2.3 on the bare
oscillator, 4 to 6% in `greyhole_demo`); `si.smooth` at most 0.5 ns per
smoother, and less with a coefficient from a slider; no test computes more
divisions, square roots or transcendental calls per sample.

## Pitfalls met

- `make check` caches its outputs: `rm -rf tests/output` before a full
  validation. To regenerate a reference, delete its `.ref` first, then
  `make reference TESTS=test_name`.
- The outputs of failing tests are deleted: rerun the binary
  `tests/build/<test> 48000 48000 > file` to compare with
  `scripts/floatdiff.py`.
- A running check rereads the `.lib` files at each compilation: do not edit
  a library while it runs. Nor rebase the branch: rewritten files get a new
  date, which makes every test rebuild.
- `check_precision.py` does not take the faust binary into account in its
  build cache (the stamp only holds the version string): after installing
  another faust of the same version, delete the build directory of the
  configurations it affects (`tests/build-precision/cfg_-lang_ocpp_-O2` for
  an ocpp fix).
- A `make` variable holding a regex with `$` and quotes breaks the shell
  quoting of `CPU_ARGS`: call `scripts/check_cpu.py` directly.
- The second-by-second profiling tool fits in twenty lines around
  `check_long.render`:

  ```python
  # from the root: python3 profile.py TEST_NAME [--dsp FILE] [--seconds 120]
  import argparse, glob, os, re, sys
  ROOT = os.getcwd()
  sys.path.insert(0, os.path.join(ROOT, "scripts"))
  import check_long as cl, check_precision as cp
  p = argparse.ArgumentParser(); p.add_argument("test"); p.add_argument("--dsp")
  p.add_argument("--seconds", type=int, default=120); p.add_argument("--rate", type=int, default=192000)
  a = p.parse_args()
  dsp = a.dsp or next(f for f in glob.glob(os.path.join(ROOT, "tests", "*.dsp"))
                      if re.search(rf"^{re.escape(a.test)}\s*=", open(f).read(), re.M))
  cp.ARCH = cl.LONG_ARCH
  args = argparse.Namespace(faust="faust", cxx="c++", seconds=a.seconds, rate=a.rate, timeout=3600)
  cfg = cp.Config("long", "", "-O2", os.path.join(ROOT, "tests", "build-long"))
  s, _ = cl.render((os.path.abspath(dsp), a.test), "single", cfg, args)
  d, _ = cl.render((os.path.abspath(dsp), a.test), "double", cfg, args)
  for (sec, pk, rs, *_), (_, _, rd, *_) in zip(s, d):
      print(sec, rs, rd, abs(rs - rd) / max(rs, rd, 1e-30), pk)
  ```

## Outside this branch, on the faust side

- faust's `master-dev` is pushed up to `1a52f7785` (version 2.90.8).
- grame-cncm/faust#1347 (the ocpp bargraph tail, above) is open, awaiting
  Yann's review.
- PR grame-cncm/faust#1346 is closed, with a reply to Yann.
- The full Gate 1 did not run on what is pushed to `master-dev`: it was
  stopped.
- The test `input-interval-folding.py` stays on the branch
  `fix-input-constant-folding`; it is not on `master-dev`.
- Decision pending: non-finite constants for Codebox (RNBO has no `inf`
  constant).
