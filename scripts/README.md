# Scripts

The tools behind the `make` targets of this repository: regression and precision
tests, documentation checks, the JSON export for LLM tools, the documentation
figures, and the formal certification. Each script also documents itself: its
docstring (or header comment) is the reference, and every Python script with
options answers `-h`.

The scripts that work on the checkout find its root from their own location and
can be run from any directory, with two exceptions: `faust_doc_api.py` looks for
its default index under the current directory (run it from the root, or pass
`--index`), and `sig2lean.py` resolves its default `FAUST_RS` path from the
current directory (the make targets set it). The Python scripts need Python 3.9
or later.

| Script | What it does | Run by |
|---|---|---|
| **Tests** | | |
| [`extract_tests.sh`](#extract_testssh) | lists the `*_test` definitions of test files | `make reference`, `check`, `bench` |
| [`floatdiff.py`](#floatdiffpy) | compares a test output with its reference, within a tolerance | `make check` |
| [`check_precision.py`](#check_precisionpy) | renders every test in float and double at 44.1 to 192 kHz | `make check-precision` |
| [`check_extremes.py`](#check_extremespy) | renders every test with its sliders at their extremes, all and one by one | `make check-extremes` |
| [`check_jumps.py`](#check_jumpspy) | renders every test with its sliders jumping between their bounds during the run, all and one by one | `make check-jumps` |
| [`check_mutation.py`](#check_mutationpy) | injects small faults in a copy of the libraries and reports which ones the tests detect; a measure, no baseline | `make check-mutation` |
| [`check_reinit.py`](#check_reinitpy) | renders every test after a second `init()`, at the same rate and after a rate change: it must equal a fresh instance | `make check-reinit` |
| [`check_sr.py`](#check_srpy) | renders every test at 44.1, 96 and 192 kHz, its noises replaced by a signal that is the same at every rate: the shape of its spectrum, its level, its onset and decay must not move | `make check-sr` |
| [`check_long.py`](#check_longpy) | renders every test for 2 min at 192 kHz in float and double: non-finite, growth, subnormals, drift | `make check-long` |
| [`check_weak.py`](#check_weakpy) | flags the tests whose reference validates little: silent, below the tolerance, constant, settled, inputs unused | `make check-weak`, `check_doc.py` (`--changed --skip-missing`) |
| [`check_backends.py`](#check_backendspy) | compiles every test for WebAssembly, Cmajor, Julia, Codebox, C#, Java; with `--compare`, compares their outputs with the C++ build | `make check-backends`, `make check-backend-outputs` (`--compare`), `check_doc.py` (`--changed --lang wasm`) |
| [`check_tuning.py`](#check_tuningpy) | measures the pitch of the `physmodels.lib` models and MIDI instruments with faustprobe at 44.1 to 192 kHz, against a baseline | `make check-tuning` |
| [`check_osc_claims.py`](#check_osc_claimspy) | measures the oscillators of `oscillators.lib` and the antialiased functions of `aanl.lib` with faustprobe: pitch and waveform at 44.1 to 192 kHz, aliasing, float noise, against a baseline | `make check-osc-claims` |
| [`check_cpu.py`](#check_cpupy) | CPU cost of the tests, new / base ratio between two versions | `make check-cpu` |
| [`lib_tests.py`](#lib_testspy) | inventory of a library's tests; adds tests to its doc blocks and to `tests/*.dsp` | — |
| [`verify_matched2.py`](#verify_matched2py) | proves the rewrites of Vicanek's matched filters and checks their coefficients at 60 digits | `make verify-matched` |
| [`fit_fastmath.py`](#fit_fastmathpy) | fits the coefficients of `fastmath.lib`, in single and double precision | — |
| [`fastmath_accuracy.py`](#fastmath_accuracypy) | measures the error of every `fastmath.lib` function, in single and double precision | — |
| **Documentation checks** | | |
| [`check_doc.py`](#check_docpy) | documentation and license gate, against a baseline | `make check-doc` |
| [`check_usage.py`](#check_usagepy) | compiles the `#### Usage` sections: arity of the call, parameters; measures the io of the export | `make check-usage`, `check_doc.py` (`--changed`), `build_faust_doc_index.py` (`--measure-io`) |
| [`check_filter_claims.py`](#check_filter_claimspy) | measures the filters of `filters.lib` and `vaeffects.lib` against their documentation with faustprobe: sample-rate independence, -3 dB points, peaks, against a baseline | `make check-filter-claims` |
| [`audit2.py`](#audit2py) | documentation coverage per library | `check_doc.py` |
| [`audit.py`](#auditpy) | naive coverage audit, kept for comparison | — |
| [`build_standard_functions.py`](#build_standard_functionspy) | generates `doc/docs/standardFunctions.md` | `check_doc.py` (`--check`) |
| [`normalize_licenses.py`](#normalize_licensespy) | canonical SPDX license strings | `check_doc.py` (`--check`) |
| **JSON export** | | |
| [`build_faust_doc_index.py`](#build_faust_doc_indexpy) | builds the JSON documentation index, io counts computed by faust | `make doc-index*`, `check_doc.py` |
| [`faust_doc_api.py`](#faust_doc_apipy) | queries that index | — |
| **Figures** | | |
| [`plot_lib.py`](#plot_libpy) | `aanl.lib` figures | `make plots` |
| [`plot_families.py`](#plot_familiespy) | figures of the other libraries, with property assertions | `make plots` |
| [`check_plots.py`](#check_plotspy) | regenerates every figure aside: stale figures, failed assertions | `make check-plots`, `make plots` (`--update`) |
| **Formal certification** | | |
| [`sig2lean.py`](#sig2leanpy) | Faust signals to Lean 4 theorems | `make certify`, `certify-reference` |
| [`check_certify.py`](#check_certifypy) | regenerates the Lean theorems and compares their verdicts with the committed ones | `make check-certify`, `check_doc.py` (`--changed`) |

The scripts that turn the `.lib` files into the documentation pages
(`faustlib2md.awk`, `inject_plots.py`, `makeindex.awk`) are in `doc/scripts/` and
are run by `doc/Makefile`.

**Prerequisites**, by use:

- tests: `faust` and a C++17 compiler; `check_precision.py` also needs `numpy`,
  and `verify_matched2.py` needs `numpy`, `sympy` and `mpmath`
  (`pip install sympy mpmath`);
- `check_usage.py`, and `build_faust_doc_index.py --measure-io` (the
  `make doc-index*` targets): `faust` (`check_doc.py` skips the Usage check
  without it);
- figures: `faust`, `g++`, `numpy` and `matplotlib`; `check_plots.py` also
  needs `rsvg-convert` (librsvg) or the `cairosvg` module;
- `check_filter_claims.py`: `faustprobe`, the offline probe of `faust-rs`
  (`cargo build --release -p cranelift-ffi --bin faustprobe`), and the export
  with measured io (`make doc-index-split`, which the make target runs first);
- `check_tuning.py`: `faustprobe` and `numpy`;
- `check_osc_claims.py`: `faustprobe`, `numpy` and the export with measured
  io (`make doc-index-split`, which the make target runs first);
- `check_sr.py`: `faust`, a C++ compiler, `numpy` and the split export
  (`make doc-index-split`, which the make target runs first);
- certification: `faust-rs` and `lean` (4.31); `check_doc.py` skips the check
  of the verdicts without them;
- everything else: the Python standard library only.

---

## Tests

### `extract_tests.sh`

```
scripts/extract_tests.sh FILE.dsp [FILE.dsp ...]
```

Prints one `file:name` line per test, in file order:

```
tests/filters_butterworth_tests.dsp:lowpass_test
```

A test is a definition `name_test = ...` at the start of a line; commented lines,
such as the `#### Test` sections of the `.lib` files, are not listed. The
Makefile runs it on `tests/*.dsp` to build `TEST_SPECS`: each pair becomes
`tests/reference/<name>.ref` and `tests/output/<name>.out`, and
`faust -pn <name> <file>` compiles that test alone. Test names must therefore be
unique across all test files (`AGENTS.md`, rule 1).

### `floatdiff.py`

```
scripts/floatdiff.py REFERENCE OUTPUT [-t TOL]
scripts/floatdiff.py REFERENCE OUTPUT TOL
```

The comparator of `make check`. Both files are written by `arch/print_arch.cpp`:
one line per frame, the frame index, one sample per output, then the value of
each bargraph at the end of its block (a program with bargraphs runs in blocks
of 64 frames, so that a meter is checked over time). They match
when they have the same lines and tokens, and each pair of numbers satisfies
`math.isclose(a, b, rel_tol=TOL, abs_tol=TOL)`: `TOL` is an absolute tolerance
below 1 in magnitude and a relative one above. `make check` passes `FLOAT_TOL`
(1e-5). Every mismatch is printed with its line number. Exit status 0 when the
files match, 1 otherwise.

### `check_precision.py`

```
scripts/check_precision.py [TEST.dsp ...] [-k REGEX] [-j JOBS] [--json FILE]
                           [--faust-options=OPTS] [--cxx-options=OPTS] [--matrix NAMES|all]
make check-precision [PRECISION_ARGS="..."]
make check-precision-matrix [PRECISION_ARGS="..."]
```

`make check` runs in double precision at 48 kHz only. This script compiles every
test in `-single` and `-double` with `arch/precision_arch.cpp`, renders one
second at 44.1, 48, 88.2, 96, 176.4 and 192 kHz, and compares the two builds. It
needs no stored reference.

A test fails when an output is not finite, or when its **level gap** (relative
difference of the single and double RMS levels) exceeds 1e-3, unless
`tests/precision-baseline.json` accepts it. The sample-by-sample gap is only
reported, because `os.osc` drifts in phase in float: the tests use `os.tosc`,
whose integer phase is the same in both precisions, except those of the
oscillators themselves.
The script also reports baseline entries that a fix made unnecessary; a level
entry is reported only once its gap is below threshold / margin (5e-4), since
the last bits of a float result vary between compilers.

- Select tests with file arguments (`tests/vaeffects_tests.dsp`) or `-k REGEX`
  on test names.
- Builds are cached in `tests/build-precision/` and redone when a `.lib`, the
  test file or the architecture is newer, or when the compiler command
  changed. The whole suite takes about ten minutes on ten cores when
  everything is rebuilt, one minute otherwise.
- The builds use `faust -single|-double` and `c++ -O2`. A precision fix can
  depend on the compilation, since the Faust normalizer and a C++
  `-ffast-math` both reassociate floating-point expressions:
  `--faust-options=-vec` or `--cxx-options="-O3 -ffast-math"` change the
  flags of a run (with `=`, the value starting with a dash), and
  `--matrix all` (`make check-precision-matrix`) runs the named
  configurations in turn: `default` (`-O2`), `fast-math` (`-O3 -ffast-math`),
  `vec` (Faust `-vec`) and `ocpp` (Faust `-lang ocpp`). They are checked
  against the same baseline, each builds in its own subdirectory of the build
  directory, and the run fails if any of them fails. Unneeded baseline entries
  are reported from the `default` configuration only.
- `--json FILE` writes every measurement (per test and rate: finite, peak, gap,
  level, growth).
- `--write-baseline` rewrites the baseline from a run over all tests; it is for
  a change of rates, threshold or harness, never to silence a failure.

Exit status 0 when every test passes, 1 otherwise. See
`doc/docs/contributing.md`, section *Precision and sample rate*, and
`AGENTS.md`, rule 9.

### `check_extremes.py`

```
scripts/check_extremes.py [-k REGEX] [--rates 44100,192000] [--precision single|double]
                          [--growth 100] [--write-baseline] [--json FILE] [FILE.dsp ...]
make check-extremes [EXTREMES_ARGS="tests/xx_tests.dsp"]
```

Renders every test that has sliders or number entries with them at their
extremes: all at their minimum, all at their maximum, then each one alone at
each end, the others at their default. `arch/precision_arch.cpp` takes the
setting as a fourth argument (`min`, `max`, `min:I`, `max:I`; `list` prints
the controls). A run fails when its output is not finite or when its peak
exceeds `--growth` (100) times the larger of 1 and the default render's peak,
unless `tests/extremes-baseline.json` accepts that test and setting, with a
reason; an entry that no longer fails is reported. It uses the `-single`
builds of `check_precision.py`, in the same build directory: about two
minutes for the whole suite once they are built.

The harness takes, in the same argument and comma-separated, the options of
a second schedule, used by the scripts below and by `check_backends.py
--compare`: `block=N` (compute() in blocks of N frames from frame 0, the
buttons released at FRAMES/2 exactly, the block split there: the schedule of
the backend runners), `nopress` (the buttons never pressed, as under `cmaj
render`), `reinit=SR0` (first initialized at SR0 and run, then initialized
again at the rate of the run, which only is written) and `jump` or `jump:I`
(the sliders, or the I-th alone, at default, max, min, max, min, max, min,
default over the eighths of the run). Without them the schedule is that of
`print_arch.cpp`, unchanged.

### `check_jumps.py`

```
scripts/check_jumps.py [-k REGEX] [--rates 44100,192000] [--precision single|double]
                       [--growth 100] [--block 512] [--write-baseline] [--json FILE] [FILE.dsp ...]
make check-jumps [JUMPS_ARGS="tests/xx_tests.dsp"]
```

Renders every test that has sliders or number entries with them jumping
between their bounds while the program runs (`jump`): default, max, min, max,
min, max, min, default, one eighth of a second each at 44.1 and 192 kHz; all
of them together, then each one alone, the others at their default.
`check_extremes.py` holds a bound for the whole run, and only the tests named
`_jump_test` move a parameter during it: a recursive filter, an interpolated
delay or a smoother can be stable at every fixed setting and blow up when the
setting moves. A run fails when its output is not finite, or when its peak
exceeds `--growth` (100) times the largest of 1, the default render's peak and
the peaks of the renders held at the same bounds (a jump to a gain at its
maximum raises the level as much as the held maximum), unless
`tests/jumps-baseline.json` accepts that test and setting, with a reason. A
run whose held bound is already not finite is not judged:
`check_extremes.py` reports it. It uses the `-single` builds of
`check_precision.py`.

### `check_mutation.py`

```
scripts/check_mutation.py [--lib xx.lib] [--def NAME] [--op OP] [-n PER_LIB] [--seed S]
                          [--jobs J] [--max-compare N] [--max-render N] [--timeout S]
                          [--list] [--list-survivors] [--uncovered] [--self-check N] [--json FILE]
make check-mutation [MUTATION_ARGS="--lib filters.lib -n 50 --list-survivors"]
```

Measures what the tests detect. `make check` says that nothing moved and
`check-weak` that a reference holds information; neither says whether the suite
would see a bug. The script writes small faults into a copy of a library, one
at a time: a number moved (`0.7` to `0.707`, `3` to `4`), `+` and `-` or `*` and
`/` swapped, `<` to `<=`, `min` to `max`, `x'` to `x`, `@(d)` to `@(1+d)`. The
sample is drawn per library with a fixed seed.

For each mutant, the tests that may reach it (a call graph by names) are
compiled and compared with the C++ of the intact libraries, and only those whose
code changed are rendered against `tests/reference/`, as `make check` does. The
mutant is `killed` when a test fails, `survived` when the code of a test changed
and no test saw it, `unreached` when no test compiles to other code (code
without a test, or a change without effect), and `invalid` when faust refuses
it. The score is killed / (killed + survived + unreached).

The working tree is never touched: everything runs from mirrors in
`tests/build-mutation/`. `--uncovered` prints the documented symbols no test
reaches in the call graph, which a Test section in a multi-symbol block can
hide. `make check` runs in `-double` at 48 kHz, so what only shows in `-single`,
at another rate or at the extremes of a slider counts as not detected, and
`singleprecision`, `quadprecision` and `fixedpointprecision` definitions are
not mutated. A survivor is not always a gap: `<` to `<=` on a value a signal
never reaches is the same program.

### `check_reinit.py`

```
scripts/check_reinit.py [-k REGEX] [--precision single|double] [--block 512]
                        [--write-baseline] [--json FILE] [FILE.dsp ...]
make check-reinit [REINIT_ARGS="tests/xx_tests.dsp"]
```

Renders every test after a second `init()`, as a host calls it to reset a
plugin or when the sample rate changes, and compares it with a fresh
instance: 48 kHz after 48 kHz, 192 kHz after 44.1 kHz and 44.1 kHz after
192 kHz, one second each (`reinit=SR0` against the same schedule without it,
in blocks of 512 frames). Every other check initializes an instance once, so
a state that `instanceClear()` does not reset, a table filled at the first
rate only, or a constant computed from it, passes them all. Both renders
come from the same binary: they must be identical sample for sample
(non-finite samples at the same places); the first difference is reported
with its frame and size, unless `tests/reinit-baseline.json` accepts that
test and pair (`192000after44100`), with a reason. It uses the `-single`
builds of `check_precision.py`.

### `check_sr.py`

```
scripts/check_sr.py [-k REGEX] [--rates 44100,96000,192000] [--seconds 2] [--export DIR]
                    [--list-bound] [--write-baseline] [--json FILE] [FILE.dsp ...]
make check-sr [SR_ARGS="tests/xx_tests.dsp"]
```

Checks that every test sounds the same at 44.1, 96 and 192 kHz: a parameter
in Hz or in seconds must not move with the rate. `make check` runs at 48 kHz
only, `check-precision` compares float with double at each rate, and the
claims checks measure the filters, the instruments and the oscillators only:
in 2026, seven `physmodels.lib` models played up to 196 cents sharp at
192 kHz (issue #323), and `os.polyblep_triangle` leaked through a pole fixed
at 0.999, both right at 48 kHz.

Digital white noise is another sequence at each rate, and a noise burst
through a resonator measured on two seconds moves by 2 to 3 dB between rates
by chance alone. The tests are therefore built (`-double`, in
`tests/build-sr`) against a copy of the libraries, `tests/build-sr/lib`, where
`no.noise`, `no.multinoise` and `no.noises` are sums of 120 sines a semitone
apart from 20 Hz to 19.3 kHz, none folding at 44.1 kHz, with a white density,
the RMS level of `no.noise` and their own phases per channel: the same signal
at every rate.
Each test is rendered for two seconds per rate with `arch/precision_arch.cpp`
(inputs at zero, buttons pressed for the first half). For each output loud
enough, whose octave bands hold most of its power:

- `spectrum`: the power of the octaves from 125 Hz to 4 kHz, against their
  sum, moves by more than 1 dB (the bands above -30 dB of the sum);
- `level`: the power of those bands follows none of three laws within 1 dB:
  unchanged (a signal defined in time), lower by 10 log10(SR/44100) (white
  noise per sample, `ba.sAndH` of a hash), lower by 20 log10(SR/44100)
  (impulses of one sample, and a filter's response to them);
- `onset`, `decay`: the envelope (RMS over 20 ms) reaches -20 dB of its
  maximum, or stays below -20 or -40 dB of it, at times that differ by more
  than 40 ms and 10 %.

The periodogram has no window: a window would hide the start of the render,
where an impulse response lies, and the leakage of the rectangular one is the
same function of time at every rate. A constant output (`ma.SR_test`) has
nothing in the bands and is not judged.

A `_jump_test` is measured but not judged: the transient a jump leaves in the
state of a recursive filter depends on the rate, in a TPT form too.
`fi.highpass(4)` and `fi.SVFTPT` at 20 Hz and at 5 kHz, and a switch between
their two outputs, do not move; a jump of their cutoff between the two does.
A function whose parameter is a number of samples or a coefficient depends on
the rate by definition (`ba.pulse(p)`, `ba.slidingSum(n)`, `fi.pole(p)`, the
comb filters): `tests/sr-baseline.json` lists such symbols (`symbols`), each
with its reason, and their tests (the export's `testCode`) are measured but
not judged (`--list-bound`). Other tests are accepted by test and key
(`accepted`). `--write-baseline` proposes the symbols whose Usage parameter
reads as samples or a coefficient: proposals to check against the doc (the
`fi.tf*s` coefficients are those of the s-plane, independent of the rate).
About two minutes for all tests once built, five the first time.

The baseline comes from the triage of 2026-10-29, when 471 of the 2352 tests
moved, updated since: 77 symbols, and 164 tests accepted. A reason starting
with `fault:` marks a defect of the library to fix: 21 tests, 10 causes, listed
below. One test is still marked `not explained yet:`: the spectrum of
`pm.violinModel`, a harmonic next to the notch of the bow position, whose regime
changes with the rate.

Three were fixed on 2026-10-31, all anchored at 44.1 kHz. The output of the
first two does not change there, and drops by 0.74 dB at 48 kHz:

- `ve.crybaby`'s gain grew as the rate (+12.9 dB at 192 kHz): its numerator
  `1 - z^-1` and its bandwidth `d` are both in 1/SR, so the peak gain 1/d is
  in SR; `ve.autowah` inherited it;
- `pm.modeFilter`'s peak gain is 1/(1 - r), in t60*SR: the bells, the marimba,
  the djembe and `pm.modularInterpBody` were 12.8 dB louder at 192 kHz;
- `sy.combString` applied a pole per sample once per period, so its decay grew
  with the rate. The pole is that of 44.1 kHz at every rate: the loop gain per
  period is fixed, the T60 falls with pitch as for a plucked string, and the
  doc of `res` says so. `maxDel` holds 12 Hz at 192 kHz. Its sound at 44.1 kHz
  does not change.

The fourth is documented, not fixed: `webaudio.lib` keeps the normalized cutoff
at 0.01 or above, so no f0 below 220.5 Hz at 44.1 kHz, 960 Hz at 192 kHz.
Removing the limit alone shows the weakness of `fi.tf2` at low cutoffs in float:
it needs another realization.

`fi.oneEuro` moves too, but it is not a fault of the library: it follows the
published algorithm, whose derivative uses the previous filtered value, a
tracking error times SR. Its entries say so.

The triage of 2026-10-31 gave a cause to the other 44 tests marked `not explained
yet:`, each measured with a variant that removes it, or a calculation that gives
the figures. Those of `fault:`, each with a fix that leaves 44.1 kHz unchanged
unless said:

- `re.vital_rev`: the allpass delays are in samples, the feedback lines in time;
- `an.spectralCentroid`: the integrator is scaled by SR/2, so its loop gain
  grows with the rate; the settled value does not move;
- `an.band_center(M,ftop,N,0)`: the top band's center follows the rate, which
  moves `an.spectral_spread` (2659, 3476, 4641 Hz) and the onset of
  `an.spectral_centroid`;
- `dm.envelopes_demo`: a gate schedule in samples;
- `fi.dcblocker`: its pole is 0.995 per sample, a highpass from 35 to 153 Hz,
  seen in `no.colored_noise` and `pm.fluteModel`;
- `pm.fluteModel`: the two jet loops take their sample delays out of one fit;
- `pm.wBell`: `pow(p,44100/SR)` keeps the time constant, not the magnitude;
- `pm.violinModel`: the bow position moves with the rate;
- the granular delay: its 65536-sample line is too short at 192 kHz, and four
  times the memory fixes it;
- `fd.hammer`: `fIn` enters the displacement unscaled, a fix that changes the
  output at 44.1 kHz for callers with k = 1/SR.

The other entries are rate-dependent by construction, or come from the test:
string loop filters with fixed taps, the linear interpolation of the delay of
`sy.combString`, the constant 33 samples of `re.valhallaSupermassive` (those of
the plug-in), an approximation for fr << SR (`ve.moog_vcf`), the saturation of
`ve.oberheim` applied once per sample, the aliasing of a fold of noise or of an
FM at 44.1 kHz, a fixed k in the `fds.lib` tests, a test schedule in samples
(`ba.time`, `ba.pulse(64)`), a burst too short for its statistics
(`no.dnoise`, `no.sparse_noise`), and a chance hit of the modes of a long tail
on the tones of the multisine (the `t60m` tests of `re.zita_rev1`).

### `check_long.py`

```
scripts/check_long.py [-k REGEX] [--rate 192000] [--seconds 120] [--warmup 2] [--growth 100]
                      [--drift 1e-2] [--write-baseline] [--json FILE] [FILE.dsp ...]
make check-long [LONG_ARGS="tests/xx_tests.dsp"]
```

Renders every test for minutes, without references: what `make check` (one
second) never reaches. Each test is compiled in `-single` and `-double` with
`arch/long_arch.cpp`, which writes no samples (two minutes at 192 kHz would be
92 MB per channel) but prints, per second, the peak, the RMS, the non-finite
samples and the subnormal ones, with the control schedule of the other
harnesses (buttons pressed for the first half). The single-precision render
fails on a non-finite sample, on a peak beyond `--growth` (100) times the peak
of the first `--warmup` (2) seconds, and on subnormal output samples after
them (counted, not timed: a timing is noisy, and Apple Silicon computes
subnormals at little or no cost); a decay is not a failure. Its RMS is
compared, second by second after the warm-up, with the double render's: a
relative gap beyond `--drift` (1e-2) that is also more than 10 times the gap of
the `--early` (8) seconds after the warm-up, the seconds below `--floor`
(1e-5) left out, is a computation that degrades in single precision: a float
counter that stops at 2^24 (87 s at 192 kHz, 349 s at 48 kHz), a sliding sum
accumulating its rounding, an undamped rotation losing its amplitude, which
give finite samples and no growth; a gap that does not grow is the
float/double difference `check_precision.py` measures. The wrap of an `int32`
counter, 3.1 h away at 192 kHz, is out of reach. Failures are compared with
`tests/long-baseline.json` (`{test: {"kinds": [...], "reason": ...}}`, the
kinds `nonfinite`, `growth`, `subnormal`, `drift`): a new kind fails, an entry
that no longer happens is reported stale. Its builds are its own, in
`tests/build-long`, and cached.

### `check_weak.py`

```
scripts/check_weak.py [-k REGEX] [--tol 1e-5] [--changed] [--skip-missing]
                      [--write-baseline] [--json FILE] [FILE.dsp ...]
make check-weak [WEAK_ARGS="tests/xx_tests.dsp"]
```

Reads the references of `tests/reference/` and flags the tests that `make check`
validates little. `floatdiff.py` compares within `FLOAT_TOL` (1e-5), absolute
below 1 in magnitude: what stays within it of zero, or of a constant, is not
checked. Per test, over its channels (a channel with a non-finite sample is left
to `check_precision.py`):

- `silent`: every channel within the tolerance of zero, so `make check`
  accepts a silent output;
- `below-tolerance`: a channel with values, all within the tolerance of zero,
  the others not: `make check` sees 0 there (a precision point at 1e-9);
- `constant`: every channel constant within the tolerance although the program
  has state (`fRec`, `fVec`, `IOTA` members of `mydsp`): a counter pressed once,
  a smoothed constant. A program without state and inputs is constant by
  definition (`ma.PI`, a function at constant arguments) and is not flagged;
- `settles`: every channel within the tolerance of its last value before the
  middle of the render: an envelope or an impulse response that ends early, an
  output that stops at the release of the harness's buttons;
- `dead-input`: the test has inputs, which the harnesses feed with zeros.

The number of inputs and the state are read from the C++ that `faust -double`
generates for each test, cached in `tests/build-weak/` while it is newer than the
test file and the libraries (12 s for the whole suite, then 3 s). Findings are
compared with `tests/weak-baseline.json` (`{test: {"kinds": [...], "reason":
...}}`): a new kind fails, an entry that no longer happens is reported stale.
The reasons say `by definition` or `by design` for what is meant (an impulse, a
measure of a steady input) and `weak:` for a test that would check more with
another input or other arguments: those are to fix, the baseline only records
them. A test without reference fails (`--skip-missing` counts it instead), and
the references of tests that no longer exist are listed. `check_doc.py` runs it
with `--changed --skip-missing` when faust is installed.

### `check_backends.py`

```
scripts/check_backends.py [--lang L,L] [--changed] [--update-baseline] [--no-validate] [--no-run] [--run-julia] [-j N]
                          [--compare [--level-max 1e-3] [--gap-max 1e-2] [--cpp-build-dir DIR]] [FILE.dsp ...]
make check-backends [BACKENDS_ARGS="--lang wasm"]
make check-backend-outputs [BACKEND_OUTPUTS_ARGS="tests/xx_tests.dsp"]
```

Compiles every test with `faust -lang L` for the restricted backends: about
15 s per backend, a minute for the six of the baseline (`wasm`, `cmajor`,
`julia`, `codebox`, `csharp`, `java`), then runs what it can run (below).
The WebAssembly modules are also validated with Node
(`WebAssembly.validate`, the check of a browser before it runs one), in the
same 15 s: a compilation that succeeds can still emit a module that does not
validate (107 tests in October 2026, a pow of two integers with a variable
exponent in single precision), a bug of faust that the output points to.
The modules that validate are then run in Node, as `make check` runs the C++
(one second at 48 kHz, inputs at 0, default controls, buttons pressed for the
first half and released at frame 24000 exactly (the block split there), the math
functions from JavaScript's `Math`): a module that stops
(a trap, as `int()` of a NaN did in October 2026) or writes a non-finite
sample fails, with the error and the frame; a module that imports its memory
(a `soundfile` test) is validated, not run. This adds about 15 s, run in
parallel. `--no-run` validates without running, `--no-validate` compiles only;
without `node` both are skipped with a note. The Cmajor patches are compiled
and rendered by Cmajor itself (`cmaj render`, one second at 48 kHz after the
20000 frames of silence it starts with, cmajor-lang/cmajor#140; the controls
at their default values, since `cmaj render` cannot press a button): a patch
that Cmajor rejects (the error comes from `cmaj play --dry-run`, `cmaj render`
gives none), that stops or writes a non-finite sample fails; about a minute,
skipped with a note without `cmaj`. `--run-julia` also loads and runs the
Julia code, as for WebAssembly (about a minute: Julia compiles each program).
A failure recorded by a run is only expected from a run: with `--no-run`, or
Julia without `--run-julia`, its baseline entry is not reported as stale. These accept only the whitelisted foreign functions, so a library
function that calls `ma.cbrt` anywhere below it fails here although it passes
every C++ check. The failures are compared with `tests/backend-baseline.json`,
the accepted debt per backend (the test and faust's error): an unlisted failure
is a regression, and a listed test that compiles again must be removed. A
backend the baseline does not list is reported, not checked; one this faust is
built without (the interpreter, LLVM) is skipped with a note. `--changed` does
nothing unless a tracked `.lib` or `tests/*.dsp` differs from `HEAD`:
`check_doc.py` runs it that way on WebAssembly. Exit status: 0, 1 on a
regression, 2 without faust. Compilations run from the repository root, since
faust looks for libraries in the current directory first. `AGENTS.md`, rule 12,
and `doc/docs/contributing.md`, section *Backends and foreign functions*, say
why.

With `--compare` (`make check-backend-outputs`, WebAssembly and Cmajor; add
`--lang wasm,cmajor,julia --run-julia` for Julia), the outputs of the backends
that run are written (`tests/build-backends/`) and compared with the C++
build in `-single` without FMA contraction (`-ffp-contract=off`, as the
backends compute), rendered by `arch/precision_arch.cpp` with the same
schedule (`block=512`, `nopress` for Cmajor). Everything above only asks a
backend for finite samples, which hid Cmajor's slider defaults snapped to
their step and its `sinh`/`atanh` without precision near 0
(cmajor-lang/cmajor#141). A test fails when its shape differs, its level gap
(as `check_precision.py` measures it) exceeds `--level-max` (1e-3), or its
sample gap (the largest difference, relative to the C++ peak) `--gap-max`
(1e-2), unless `tests/backend-output-baseline.json` accepts it with a
reason; an entry that matches again is reported. The C++ builds are those of
`check_precision.py` (`--cpp-build-dir`).

### `check_cpu.py`

```
scripts/check_cpu.py [TEST.dsp ...] [-k REGEX] [--base REV [--new REV] [--changed-only]]
                     [--matrix NAMES|all] [--rounds N] [--rate SR] [--double] [--json FILE]
                     [--fail-above RATIO]
make check-cpu [CPU_ARGS="..."]
make check-cpu-matrix [CPU_ARGS="..."]
```

Measures what the tests cost: each test is compiled with `arch/cpu_arch.cpp`
and the table gives the best time per frame (ns) and the share of one core at
the sample rate (48 kHz by default). With `--base REV`, the same tests are also
built against the libraries of REV and the table adds the ratio new / base;
`--new REV` measures REV instead of the working tree, so
`--base origin/master --new origin/some-branch` measures a pull request without
checking it out. The test files are those of the new side: a test that only the
new libraries can compile gets an error on the base side, not a ratio. A test
file can be named alone (`filters_adaptive_tests.dsp` is looked up in `tests/`);
a file of the repository is taken from the new side, so that with `--new REV`
the tests are those of REV; any other file, a program of your own, is taken as
it is.

- **The measurement** is the "flash" judge of Yann Orlarey's
  [faustcompilerbenchtool](https://github.com/orlarey/faustcompilerbenchtool)
  (`flasharch_footer.cpp`, copied with its MIT license into `arch/cpu_arch.cpp`):
  noise on the inputs, 512-frame blocks, a spin that gets the process onto a
  performance core before anything is timed, warm-up, and the minimum over
  repetitions. Buttons and checkboxes are held pressed for the whole timing,
  so that an instrument test is not timed on silence (`print_arch.cpp` and
  `precision_arch.cpp` release them halfway through the render instead).
- **The protocol** around it: builds in parallel, timing strictly sequential;
  no timing on battery power (macOS, `--allow-battery` to override); a pause
  after the builds; then each test in turn, over `--rounds` rounds (3) in which
  its two sides run back to back, in an order that alternates between rounds.
  Each side keeps the **median** of its rounds, each round being the minimum
  of one run. The minimum across runs is not robust: each process gets its own
  core, frequency and memory layout, and an occasional run is faster than all
  the others (with the minimum, an A/A comparison of identical code measured
  1.27). The `spread` column, (max - min) / min over the rounds, is the noise a
  ratio is to be read against; a test whose spread exceeds 5% is re-raced once
  with as many rounds again (marked `*`), as `fcautotool` does.
- **An idle machine.** The measurements are meant for a machine that does
  nothing else: on AC power, with no build, test suite (`make check`,
  `check-precision`) or other heavy job in parallel. The tool cannot make a
  timing on a loaded machine reliable. It only reports what it sees:
  - **The load average** is printed with the identity lines, with a warning
    when, at the start, it exceeds the number of performance cores. It is also
    recorded before and after the timing, without a warning: those one-minute
    averages still hold the run's own parallel builds (a run of 756 builds
    showed 34 just before timing). It is information, not a guarantee: a one-minute average misses a
    burst of a few seconds, and on Apple Silicon a load on the efficiency
    cores does not disturb a test timed on a performance core.
  - **A ratio whose spread is still above 20% after the re-race** was timed
    while the machine was disturbed. It is marked `?`, left out of the summary
    line, and listed at the end, to be measured again (with `-k`). In two
    full runs of the suite (848 ratios), this flagged 6. Among them were the
    only two ratios that differed between the runs by more than 9%: a
    `lowshelf_modulated_test` timed at 0.81 in one run and at 1.04 in the
    other, while a few seconds of another load tripled its rounds.
  - **Two runs agree.** Between two full runs on an idle machine, the median
    change of a ratio was 0.2% to 0.5%, and 90% of them moved by less than
    2.5%. A ratio quoted in a pull request comes from a run where it is not
    marked `?`, and preferably from two runs that agree.
- **The noise floor**, measured by A/A comparisons (the same libraries on both
  sides) of 61 tests spread over the suite: ratios from 0.98 to 1.02 on a quiet
  machine, 0.96 to 1.04 on a busy one. Read a ratio within 3%, or within its
  spread, as no difference.
- A test that computes nothing per sample (below 0.1 ns/frame: its output is a
  constant computed at init) gets no ratio.
- **The `ops` column** counts, in the code Faust generates, what each sample
  executes that an embedded core pays dearly for: divisions, square roots and
  transcendental calls (`pow`, `exp`, `log`, `sin`, `cos`, `tan`...), as
  `div/sqrt/fn`, for each side, and `!` marks a test whose new side has more of
  any of them. A desktop core overlaps these operations with the rest of the
  loop when they are off its recursion; a Cortex-M7 spends 14 cycles on a float
  division or square root, and tens to hundreds on a `pow` or a `tan`, so a
  ratio measured on the desktop can hide what a change costs on a
  microcontroller. With its cutoff modulated at every sample, the `tf3slf`
  rewrite of #272 goes from `2/0/1` to `5/1/2` per sample (the modulator of the
  test contributes one `pow` to both); the `tf2s` rewrite of #273 takes
  `resonlp` from `6/0/2` to `1/0/2`. The count is static (one occurrence in the
  per-sample loop is one operation per sample, loops over `count`, or over
  `vsize` in the first block of `-vec` code), does not depend on the C++
  options, and is stored in the JSON with the name of each function.
- **`--changed-only`** (with `--base`) times only the tests whose generated C++
  differs between the two sides, the metadata lines (library versions) aside.
  The others run the same code: their ratio is 1 by construction, and timing
  them only measures noise. A change reaches further than the tests one would
  think of (a new `fi.lowpass` changes filter banks, analyzers, reverbs and
  physical models), and this finds them all without guessing: an A/B of the
  whole suite then times only the changed tests, 421 of 4335 builds across the
  three compilations of `--matrix all` for a week of filter rewrites, in about
  40 minutes. The summary line gives the number of tests left out.
- **Non-finite output** is flagged `NaN` next to the time: that time measures
  NaN arithmetic, not the filter. The check reads the output through volatile
  accesses, since `-ffast-math` lets the compiler assume that no value is NaN.
- **The compilation** is by default the one faust2xx scripts use
  (`faustoptflags`): `faust -single`, `c++ -O3 -ffast-math`, plus
  `-march=native` except on Apple Silicon. A ratio depends on it:
  `-ffast-math` lets the C++ compiler turn divisions into multiplications and
  reassociate sums, which a direct-form filter profits from more than a
  state-variable one (a `tf2s` rewrite measured 1.44 with it and 1.20 without),
  and Faust `-vec` can change a ratio more still. `--matrix all`
  (`make check-cpu-matrix`) runs `fast-math`, `strict` (`-O3`) and `vec`
  (Faust `-vec`) in turn; `--double`, `--faust-options` and `--cxx-options`
  set a single compilation.
- The libraries of a revision are extracted with `git archive` into
  `tests/build-cpu/src/<commit>/`, once, and every build is cached under
  `tests/build-cpu/` like those of `check_precision.py`.
- `--json FILE` writes the identity (machine, compilers with their paths,
  compilations, rate, revisions) and every measurement, rounds included. The
  progress is printed, and the JSON file updated, every 30 s; an interrupted
  run (Ctrl-C, kill) still reports the tests already measured, and its JSON
  says `"complete": false`.
- `--fail-above RATIO` exits with 1 if a ratio exceeds RATIO. It is off by
  default: a slower test is a trade-off to state, not an error.

Times are comparable only within one run: machine, compiler and load all
change them, so the identity lines are printed first and a pull request quotes
ratios measured side by side, not two separate runs. Each run takes 0.25 s
or more (the spin alone is 0.2 s), so a comparison costs 1 to 3 s per test and
compilation and the whole suite about an hour: select the tests you touched
and their main callers (`-k`, file arguments), or let `--changed-only` find
them.

`make bench` (`faustbench-llvm` on every test, MBytes/s into `tests/bench.log`)
remains for an overview of the whole suite through the LLVM JIT; it compares
nothing.

Exit status 0, or 1 with `--fail-above` when a ratio exceeds it. See
`doc/docs/contributing.md`, section *CPU cost*, and `AGENTS.md`, rule 10.

### `lib_tests.py`

```
scripts/lib_tests.py inventory LIB [--missing]
scripts/lib_tests.py add LIB SPEC.dsp [--tests-file FILE] [--dry-run]
```

Every test lives in two places (`AGENTS.md`, rule 8): in the `#### Test` section
of the function's doc block, then, verbatim and under the same name, in a
`tests/*.dsp` file. A function whose parameters are meant to vary at run time has
three tests, `name_test`, `name_slider_test` and `name_modulated_test`, and a
recursive filter a fourth, `name_jump_test` (see `doc/docs/contributing.md`,
section *Constant, slider, modulated and jump tests*). This script checks and
maintains both places.

**`inventory LIB`** lists, for every symbol documented in LIB, where each of the
four tests exists: `both`, `lib` or `dsp` (one side only), or `-`. The tests
present on one side only break rule 8 and are listed first; the exit status is
then 1. `--missing` hides the symbols that have the first three; a missing
`_jump_test` does not count, since only recursive filters need one. Whether a
function needs the slider, modulated and jump variants is a judgement, which the
inventory leaves to you: its parameters must be meant to vary at run time.

The inventory reads the titles with or without a prefix (`(tu.)name` or
`name`, as in tubes.lib, tonestacks.lib, instruments.lib and maxmsp.lib),
counts the tests of a generic `name[N]` or `name[N]suffix` from any of its
instances (`fdelay2a_test` for `fdelay[N]a`), and accepts a test named after
the library's alias when the natural name is taken (`tu_inverse_test`, rule
1 of `AGENTS.md`); a test found only in `tests/*.dsp` counts for the library
only if it calls the function through that alias. A test commented out in
`tests/*.dsp` on purpose, such as the nondeterministic `no.rnoise`, shows as
`off`.

```bash
scripts/lib_tests.py inventory filters.lib --missing
```

**`add LIB SPEC.dsp`** inserts the tests of SPEC.dsp wherever they are missing.
SPEC.dsp is an ordinary Faust file, with one definition per line: `xx =
library("...");` imports, `*_test` definitions (a `with { }` on the same line
is fine), and the helper definitions the tests use (`src = os.tosc(440);`). It
compiles as it is, so write it, check it, then add it:

```bash
scripts/check_precision.py new_tests.dsp       # every new test must pass
scripts/lib_tests.py add filters.lib new_tests.dsp --dry-run
scripts/lib_tests.py add filters.lib new_tests.dsp
```

- **Which function a test belongs to.** It is the documented function whose
  name is the longest prefix of the test name: `resonlp_slider_test` belongs
  to `resonlp`, `highpass_plus_lowpass_even_modulated_test` to
  `highpass_plus_lowpass_even` and not to `highpass`. A test whose name starts
  with no documented function is an error.
- **In the .lib**, the test is appended to the `#### Test` section of that
  function's doc block. When the block has no such section, one is created,
  before `#### References` or at the end of the block. The imports and helper
  definitions the test uses and the section lacks are added with it.
- **In `tests/*.dsp`**, the test goes after the last test of the same
  function, in the file that holds its `name_test`. The imports and helpers it
  needs are added to that file. A function with no test file yet goes to
  `--tests-file`, which is created when needed, with a header and the imports.
- **What is already there stays.** A test already present on one side is not
  touched on that side, so `add` also repairs a test that exists only in
  `tests/*.dsp`: give it the test as written there, and it is copied into the
  .lib. A test name already used for another function is an error, since
  names are unique across `tests/*.dsp`.

After `add`, the usual steps of a test change apply:
- generate the new references with `make reference`, which builds only the
  missing ones, and check that none is all zeros;
- run `make check-precision` on the touched test files: a new test must pass
  without a baseline entry;
- raise the library's version (a PATCH for tests alone) and regenerate its
  page with `make -C doc md`;
- run `make check-doc`.

### `verify_matched2.py`

```
scripts/verify_matched2.py [identities|coefficients] [--quick] [--old] [--json FILE]
                           [--faust-options=OPTS] [--cxx-options=OPTS]
make verify-matched [VERIFY_ARGS="..."]
```

The six matched filters of `vaeffects.lib` (`lowpass2Matched`,
`highpass2Matched`, `bandpass2Matched`, `peaking2Matched`, `lowshelf2Matched`,
`highshelf2Matched`) compute Vicanek's coefficients through rewritten formulas
that avoid cancellation, so that they stay accurate in single precision when the
poles come close to z = 1. This script backs every claim made about them, and
fails (exit status 1) if one no longer holds:

- `identities`: the algebraic identities the rewrites rely on, proved with
  `sympy`, and the trigonometric and hyperbolic ones, evaluated with `mpmath`
  at 120 digits at random points, where they must agree to 40 digits.
- `coefficients`: the coefficient environments of the actual Faust code
  (`_lowpass2MatchedCoefs`, ..., `_shelf2Matched`), compiled in `-single` and
  `-double` and rendered at the six rates, against Vicanek's original formulas
  evaluated at 60 digits, over 8 CF (20 Hz to 20 kHz), 9 Q (0.1 to 30) and
  4 to 9 G. It fails above 2e-5 in float and 1e-8 in double. Each filter is
  compared in the form that matters when the poles are close to z = 1:
  `P = 1 + a1 + a2`, `fq = 1 - a2`, and its numerator.
- `--old` adds the same table for the original code, emulated with `numpy` in
  float32 and float64. `--quick` runs a small grid.
  `--faust-options` and `--cxx-options` check other compilations
  (`--cxx-options="-O3 -ffast-math"`, `--faust-options=-vec`).

Run it after any change to these filters or to `_matched2`, `_shelf2Matched`
or `_matchedRun`. It takes a few seconds.

### `fit_fastmath.py`

```
scripts/fit_fastmath.py
```

Prints, as Faust definitions, the coefficients of the polynomials and rational
functions of `fastmath.lib`, with the error of each fit. Single precision and
the `faster` tier: minimax by Lawson's algorithm in float64 (rational functions
by Loeb's linearization). Double precision: Chebyshev interpolation in `mpmath`
at 50 digits, of a degree that brings the error below 1e-17, checked on 2001
points with the coefficients rounded to double. The errors are those of the
exact formulas; `fastmath_accuracy.py` measures the compiled code. A few
seconds.

### `fastmath_accuracy.py`

```
scripts/fastmath_accuracy.py [--precision single|double|both] [-k REGEX] [--json FILE]
```

Compiles every function of `fastmath.lib` over a sweep of 2^20 points of its
domain (the build and the architecture of `check_precision.py`), and prints its
largest relative or absolute error against `numpy`'s float64 function, in
`-single` and `-double`: the figures of the doc blocks. The references reduce
their argument exactly where `numpy` would round it (`sin(2 pi x)` from
`x - round(x)`, `tan(pi x)` near its pole from `1/2 - |x|`), and in double
precision numpy's own error (half an ulp) is part of what is measured. Run it
after a change of `fastmath.lib`, and update the doc blocks. About 20 s.

## Documentation checks

### `check_doc.py`

```
scripts/check_doc.py [--update-baseline]
make check-doc
```

The gate to pass before every commit. It fails on:

1. an undocumented symbol, or a doc block without `#### Usage`, that is not
   already recorded in `tests/doc-baseline.json` (measured by `audit2.py`);
2. any block reduced to a `#### Test` section;
3. a stale `doc/docs/standardFunctions.md` (`build_standard_functions.py
   --check`);
4. a non-canonical license string (`normalize_licenses.py --check`);
5. a drop in the number of symbols of the JSON export
   (`build_faust_doc_index.py`), which means the doc-block format drifted away
   from what the exporter understands;
6. a `#### Usage` section, in a library that differs from `HEAD`, that
   `check_usage.py --changed` rejects (when `faust` is installed).

`--update-baseline` records the current debt as accepted. Never use it to hide a
gap you introduced. Exit status 1 on any regression.

### `check_usage.py`

```
scripts/check_usage.py [--lib xx.lib] [--symbol xx.name] [--changed] [-v] [-j JOBS]
scripts/check_usage.py --update-baseline
make check-usage [USAGE_ARGS="..."]
```

Compiles the `#### Usage` section of every symbol of the JSON export. A
Usage line such as `_ : lowpass(N,fc) : _` is a Faust expression: once `N`
and `fc` have values, `faust -e` evaluates it, and its sequential
compositions fail when the buses do not match the arity of the call. Each
Usage line that names the symbol becomes `process = <line>;`, where:

- `(fi.)lowpass` and the bare names of the symbol's library are qualified
  (`fi.lowpass`), and `hslider(...)` reads as a control input `_`;
- the parameters of the library's calls take the values of the same calls in
  the `#### Test` section, whose definitions are in scope; a definition line
  of the Usage (`index = 1.69;`) is kept;
- a name still without a value reads as a signal `_` on a bus
  (`excitation : bowTable(offset,slope) : _`) and as an arbitrary value, 2,
  in an argument (`isnan(x)`); a failure after such an arbitrary value is
  reported as `unbound`, since the value may be the cause;
- a bus written with `...` (`_,_, ... : f(N) : _,_, ...`) states a variable
  channel count: it is dropped, and only the call is checked;
- prose lines are skipped, but the `` `code` `` they quote is checked; a
  statement may continue over several lines, and `-> result` ends it.

It then checks that the arguments of the call and the bullets of `Where:`
name the same parameters. A symbol fails as `arity`, `unbound` (a name with
no value: a parameter the Test section does not exercise, or an unqualified
name such as `bus` for `si.bus`), `syntax`, `pseudo` (a `...` placeholder in
an argument list), `missing` (no Usage line names it), `params` (Usage and
`Where:` disagree), `prefix` (a name of the symbol's own library written
with its prefix, `si.bus` in `signals.lib`) or `error`. A bullet may belong
to another function of the same block. The values of a Test call come with
the definitions of the `with { }` around it, and when a call does not give
the values (`par(i, 3, f(0.5 + i))`), the next call of the Test section is
tried. A `params` failure on a bullet that documents an input is fixed by
naming the input in the call (`expm1(x) : _`), not by deleting the bullet. The accepted debt is pinned symbol by symbol,
with its kind of failure, in `tests/usage-baseline.json`: a symbol that is not
there must pass, an entry must still fail the same way, and an entry that
passes is reported, to be removed in the commit that fixes it.

`--symbol` prints the programs it compiled. A full run takes about a minute
(`dx.algorithms` alone, 50 s); `check_doc.py` runs it with `--changed`, on the
libraries that differ from `HEAD` or are new. Exit status 1 on any
regression.

### `check_tuning.py`

```
scripts/check_tuning.py [--faustprobe PATH] [--jobs N] [--only pm.xx ...]
                        [--write-baseline] [--json FILE]
make check-tuning [TUNING_ARGS="--only pm.ks pm.violin_ui_MIDI"]
```

Measures what a pitched instrument promises: a model given `f2l(freq)`, or a
MIDI instrument given its `freq` slider, sounds at `freq`, at every sample
rate. Neither `make check` (48 kHz, references made by the same code) nor
`make check-precision` (float against double, at one rate) can see a wrong
pitch: in 2026, seven models of `physmodels.lib` corrected their loop delay,
a number of samples, by a length in meters, and played up to 196 cents sharp
at 192 kHz (issue #323).

The cases are the models of the script's `MODELS` table, plucked by an
impulse or driven by a constant pressure or bow, and every `*_ui_MIDI` of
`physmodels.lib`, found in the library, its `freq` slider set and its `gate`
pressed. Each one is rendered by faustprobe in double precision at the six
rates of `check-precision`, for 110, 220, 440 and 880 Hz within the slider's
range, and its fundamental is the spectral peak within six semitones of the
note (Hann window over one second, zero-padded 8 times, interpolated on the
log magnitude; 0.02 cent on a Karplus-Strong string). Keys:

- `sr`: one note spreads over more than 1 cent across the rates: something
  is counted in samples where it should be in seconds, or the reverse;
- `tune`: a pitch more than 1 cent from the note, or no peak within six
  semitones;
- `silent`, `nonfinite`: the analysed second is silent or not finite.

`tests/tuning-baseline.json` accepts deviations by case and key, each with its
reason; an entry no longer needed is reported. A new pitched instrument is
covered as soon as it is a `*_ui_MIDI`; a model is added to `MODELS`. Exit
status 0, 1 on a deviation the baseline does not accept, 2 without
faustprobe. About a minute.

### `check_osc_claims.py`

```
scripts/check_osc_claims.py [--export DIR] [--faustprobe PATH] [--jobs N] [--only os.xx aa.xx ...]
                            [--table] [--write-baseline] [--json FILE]
make check-osc-claims [OSC_CLAIMS_ARGS="--only os.sawN aa.tanh1"]
```

Measures what an oscillator promises: given `freq`, it sounds at `freq` with
the same waveform at every sample rate, and an aliasing-suppressed one
aliases less than the naive waveform it replaces. The tests of
`oscillators.lib` play at 220 or 440 Hz at 48 kHz, where aliasing is too low
to see, and their references come from the same code: in October 2026,
`os.polyblep_triangle` leaked through a pole fixed at 0.999 (7 Hz at
44.1 kHz, 31 Hz at 192 kHz), identical to the fixed version at 48 kHz, and its
triangle at 20 Hz had a peak of 0.91 at 44.1 kHz and 0.41 at 192 kHz.

The oscillators are found in the export: every symbol of `oscillators.lib`
whose Usage is a call without input with a `freq` parameter (or `fund`, given
`lf_sawpos(freq)`), valued by its Test section (a `reset` held at 0). They
are rendered by faustprobe in double precision at the six rates of
`check-precision`, at 55, 220, 880 and 3520.37 Hz, one second after 0.25 s.
The antialiased functions of `aanl.lib` are those of the script's
`NONLINEAR` table, each driven by a sine at 2637.13 Hz scaled into its domain
and past its knee, with its naive static function where the table gives it.
The aliasing of a render is the energy outside the harmonics of its
fundamental against the energy in them (Blackman-Harris window, 8 bins each
side of every harmonic: the floor is -91 dB, a pure sine). Keys:

- `tune`: a pitch more than 1 cent from the note;
- `sr`: a harmonic below 4 kHz spreads over more than 0.5 dB across the
  rates, or the mean moves with the rate; weak harmonics, buried in the
  aliasing of a naive waveform, and the mean of a naive waveform sampled on
  another grid are given their margin;
- `alias`: a symbol whose summary says it suppresses aliasing gains less than
  6 dB on the naive `lf_` waveform of its family at 3520.37 Hz at 44.1 kHz
  (an `aanl.lib` function, less than 3 dB on its static function at
  2637.13 Hz);
- `order`: order N+1 of an `N` family (`sawN`, `squareN`, `triangleN`,
  `pulsetrainN`, `imptrainN`, N = 1 to 4), or the second order of an
  `aanl.lib` function, gains less than 1 dB on the order below;
- `level`: the aliasing at 44.1 or 96 kHz is 1 dB worse than the level
  recorded in the baseline (`levels`); a level that improved by as much is
  listed, to be recorded with `--write-baseline` once the change is known to
  be deliberate;
- `noise`: in `-single`, at 44.1, 96 or 192 kHz, the aliasing stands above
  -80 dB and 6 dB above the `-double` render: rounding takes the suppression
  away (the second-order ADAA, whose divided differences cancel as
  consecutive inputs come closer; the recursive sine oscillators);
- `tune-single`: an oscillator more than 1 cent off in `-single` (the
  coefficient of a recursive oscillator, rounded to float, sets its
  frequency: `os.oscw` is 4 cents flat at 55 Hz at 192 kHz);
- `silent`, `nonfinite`, `error`.

`--table` prints every measurement. `tests/osc-claims-baseline.json` accepts
deviations by case and key, each with its reason, and records the aliasing
levels; an entry no longer needed is reported. A new oscillator is covered as
soon as its Usage and Test give a call with `freq`; a new `aanl.lib` function
is added to `NONLINEAR`. Exit status 0, 1 on a deviation the baseline does
not accept, 2 without faustprobe or the export. About a minute.

### `check_filter_claims.py`

```
scripts/check_filter_claims.py [--export DIR] [--faustprobe PATH] [--jobs N] [--only fi.xx ...]
                               [--write-baseline] [--json FILE]
make check-filter-claims [FILTER_CLAIMS_ARGS="--only fi.lowpass"]
```

Measures what the documentation of the filters says. For every `fi.*` and
`ve.*` symbol with a frequency parameter and an input, the Usage call is valued
with the parameter values of its `#### Test` section (the export's
`io.parameterValues`) and measured with faustprobe's `--freqresp`, which also
refuses a nonlinear or time-varying program (such symbols are listed as
skipped). Two checks:

- sample-rate independence: the magnitude responses at 44.1 and 96 kHz, from
  20 Hz to 6 kHz, may differ by 0.5 dB below 1.5 kHz and 3 dB above, where
  both are above -40 dB: a parameter in Hz or seconds must not move with the
  rate (key `sr`);
- claims: the filter type is read from the name and summary; the DC and
  near-Nyquist gains, the gain at the nominal frequency (`normFreq` is
  `20*1000^normFreq` Hz) and the peak or dip are compared with what the doc
  states: `-3dB`, `allpass`, `unity`, `peak`, `dip`.

`tests/filter-claims-baseline.json` accepts deviations by symbol and key, each
with its reason (frequency warping of a filter bank, a -3 dB point the doc
places away from `fc`...); an entry no longer needed is reported. Exit status
0, 1 on a deviation the baseline does not accept, 2 without faustprobe or
export. About 15 s with the export already built.

### `audit2.py`

```
scripts/audit2.py [OUTPUT.json]
```

Documentation coverage of the git-tracked `.lib` files at the root. It
understands the conventions of the doc blocks: multi-symbol titles, generic
patterns (`fdelay[N]`), `library()` and `environment` aliases, `/* */`
comments, and `_name` internals. It prints one row per library (lines,
definitions, doc blocks, undocumented symbols, coverage, blocks without
`#### Usage`, blocks with a test only), and writes the details as JSON when
given a file. Always exits 0.

### `audit.py`

```
scripts/audit.py [OUTPUT.json]
```

A first, naive coverage audit that matches one doc marker per line and does not
understand multi-symbol titles, generic patterns or aliases. It over-reports
undocumented symbols. It is kept to show what the conventions cost a naive
parser; `audit2.py` gives the real numbers. Not used by any target.

### `build_standard_functions.py`

```
scripts/build_standard_functions.py [--check]
```

Generates `doc/docs/standardFunctions.md` from the `` `name` is a standard
Faust function `` lines of the `.lib` files. The section, label and description
of a function already listed are kept from the current page; a new one gets a
generated row. Without options, rewrites the page; with `--check`, writes
nothing and exits 1 if the page is out of date.

### `normalize_licenses.py`

```
scripts/normalize_licenses.py [--check]
```

Rewrites the `declare ... license "..."` strings of the `.lib` files to one
canonical SPDX identifier per license (`MIT`, `BSD-3-Clause`,
`LGPL-2.1-or-later`, `LicenseRef-STK-4.3`, ...). Ambiguous versions are mapped conservatively (a bare
"GPLv3" becomes `GPL-3.0-only`). With `--check`, writes nothing and exits 1 on
any non-canonical string. The mapping table is at the top of the script.

## JSON export

### `build_faust_doc_index.py`

```
scripts/build_faust_doc_index.py [--repo-root DIR] [--stdlib FILE] [--output FILE]
                                 [--split-output-dir DIR] [--pretty]
                                 [--license-policy all|commercial-compatible]
                                 [--license-allowlist-file F] [--license-denylist-file F]
                                 [--measure-io [--jobs N]]
make doc-index | doc-index-split | doc-index-commercial [DOC_INDEX_IO=]
```

Extracts the documentation from the `.lib` sources, not from the generated
pages. Starting from `stdfaust.lib` and the libraries it has no prefix for
(`STANDALONE_LIBRARIES`: `ts`, `tu`, `inst`, `mm`), it follows `library()` and
`import()`, finds the doc-block titles, and parses each block into summary, usage,
parameters (`Where:`), test code, references and license. The result is a JSON
index that LLM tools (the MCP servers, `faust_doc_api.py`) search without loading
the libraries.

- `--output` writes the whole index as one file (default
  `dist/faust-doc-index.json`; the make targets use `tests/faust-doc-index.json`).
- `--split-output-dir DIR` also writes a compact `DIR/index.json` and one
  detailed `DIR/modules/<module>.json` per library, which suits retrieval (the
  make targets use `tests/faust-doc/`).
- `--license-policy commercial-compatible` keeps only the symbols whose license
  matches a conservative allow-list; the allow and deny lists can be extended
  with newline-separated files.
- `--measure-io` computes each symbol's `io` with the Faust compiler instead
  of guessing it from the Usage text. The call of the Usage, valued as
  `check_usage.py` values it (from the `#### Test` section), is compiled as
  `process = inputs(call), outputs(call);`, which `faust -e` reduces to two
  constants: `fi.wgr(440,0.995)` gives 1 input and 2 outputs where the text
  `_ : wgr(f,r) : _` said 1 and 1, `an.ifft(8)` 16 and 16 where it said 1
  and 1. A measured `io` has `"source": "faust"`, the parameter values the
  arity holds for (`parameterValues`, from the Test section or the Usage) and
  those neither gave (`assumedValues`, set to 2); the others keep the guess,
  `"source": "usage"` (a pseudo-code Usage, an environment like `fi.svf`).
  About 1050 of the 1194 symbols are measured, in about a minute. It needs
  `faust`, and measures the libraries of the checkout the script belongs to.
  The make targets pass it; `DOC_INDEX_IO=` builds the export without
  `faust`, with guessed counts. `check_doc.py` does not measure (it only
  counts the symbols).

The last line printed is a JSON summary, including `symbolsCount`, which
`check_doc.py` compares with its baseline. After a change to the doc-block
format, regenerate the export and check the touched symbols (`AGENTS.md`,
rule 7).

### `faust_doc_api.py`

```
scripts/faust_doc_api.py [--index PATH] [--pretty] [--format json|text] [--repo-root DIR] COMMAND ...
```

Queries an index built by `build_faust_doc_index.py`, with the operations of the
Faust-library MCP tools. `--index` is an index file or a split directory; by
default `tests/faust-doc/index.json`, then `tests/faust-doc-index.json`. Every
command prints JSON; `--format text` prints a compact rendering for LLM
context instead (one line per symbol in searches and lists: qualified name,
`in->out` signals, usage, own license).

| Command | Result |
|---|---|
| `search_faust_lib QUERY... [--limit N] [--module M] [--inputs N] [--outputs N] [--license-policy P]` | ranked symbols matching a free-text query |
| `get_faust_symbol SYMBOL` | the full entry of a symbol (`lowpass` or `fi.lowpass`) and close alternatives |
| `list_faust_module MODULE [--limit N]` | the symbols of a module |
| `get_faust_examples SYMBOL_OR_MODULE [--limit N]` | the `#### Test` snippets of a module, else of a symbol |
| `explain_faust_symbol_for_goal SYMBOL GOAL` | a short recommendation built from the stored documentation |
| `get_faust_source SYMBOL [--max-lines N]` | the doc block and the definition, read from the `.lib` file under `--repo-root` (default: this checkout) |

A module is named by its file stem, its file name or its prefix: `physmodels`,
`physmodels.lib` or `pm`.

`search_faust_lib` first returns the symbols whose name, qualified name,
summary or source file contains the whole query (`"match": "phrase"`, the
faustforge ranking), then those where every word of the query appears, in any
order, in the name, summary, usage, parameters or notes (`"match": "words"`):
`lowpass butterworth` finds `fi.lowpass`, `hard clip` finds `aa.hardclip`.
`--inputs` / `--outputs` filter on the exported `io` counts, and
`--license-policy commercial-compatible` applies the export's license filter at
query time. Each hit carries its `io` and, after `limit`, `total` says how many
matched.

```bash
make doc-index-split
scripts/faust_doc_api.py --pretty get_faust_symbol fi.lowpass
scripts/faust_doc_api.py --format text search_faust_lib reverb --outputs 2 --license-policy commercial-compatible
scripts/faust_doc_api.py --format text get_faust_source fi.dcblocker
```

## Figures

Both scripts write SVG files to `doc/docs/img/` (`--out` to change it), where
`doc/scripts/inject_plots.py` embeds each one in its function's page by naming
convention. `make plots` runs both through `check_plots.py --update`, which
rewrites only the figures whose rendering changed, then rebuilds the
documentation. The figures
are generated files: regenerate them, do not edit them (`AGENTS.md`, rule 6).

### `plot_lib.py`

```
scripts/plot_lib.py [--out DIR] [--only NAME,NAME]
```

One figure per function documented in `aanl.lib`, `aa_<name>.svg`: the transfer
curve from a slow ramp, and the spectrum of a driven sine with its true
harmonics marked, so that aliasing shows as energy off the marks. `--only` takes
`aanl.lib` names (`hardclip,tanh1`). The probes are written in Faust and rendered
with `arch/print_arch.cpp` (`faust -double`, `g++ -O2`, 48 kHz) by `run_probe`,
which `plot_families.py` reuses. A function whose probe does not compile is
skipped and listed; the exit status is 0.

### `plot_families.py`

```
scripts/plot_families.py [--out DIR] [--only STEM,STEM]
```

The figures of the other libraries: frequency responses, envelopes, noise
spectra, compressor curves, aliasing, and more. Each figure checks a property
(a Butterworth lowpass is at -3 dB at its cutoff, a compressor's slope matches
its ratio, ...). A figure that contradicts its function's documentation is still
written, for inspection, but the script ends with the number of failed
assertions and exit status 1. Success ends with "all figures generated, all
property assertions hold". `--only` takes figure stems: the file name without
`.svg` (`fi_lowpass,co_compressor_mono`).

### `check_plots.py`

```
scripts/check_plots.py [--only STEM,STEM] [--update] [--keep DIR]
make check-plots | plots   [PLOTS_ARGS="--only STEM,STEM"]
```

Regenerates every figure with both scripts (side by side, about 2 minutes)
in a temporary directory and compares each one with its copy in
`doc/docs/img/`. Their text cannot decide it: matplotlib writes the date,
its version and random ids into every SVG, and the last digits of a
coordinate move with the platform. The two files are therefore rasterized
at 96 dpi and compared pixel by pixel; a figure is stale when a pixel moves
by more than 0.25 (renderings of the same data by two matplotlib versions
stay below 0.05). It fails on a failed property assertion, a stale figure,
a figure generated but not in `doc/docs/img/`, and a committed figure no
generator writes any more. The functions `plot_lib.py` skips by design
(`aa.ADAA1`, the folders with parameters) are listed, not counted.

`--update` copies the stale and new figures into `doc/docs/img/` and leaves
the others untouched, so that only figures whose rendering changed show in
the diff; it updates nothing while an assertion fails. `make plots` is
`--update` followed by the documentation build. `--keep DIR` keeps
the regenerated figures for inspection. `AGENTS.md`, rule 11, says when to
run it.

Both generators compile their probes from the repository root: faust looks
for libraries in the current directory before the `-I` ones, so a probe
compiled elsewhere would plot the libraries found there.

## Formal certification

### `sig2lean.py`

```
scripts/sig2lean.py TEMPLATE.lean OUT.lean FILE.dsp [FILE.dsp ...]
make certify | certify-reference
```

Compiles each program with `faust-rs --dump-sig-dag`, translates its signals
into Lean 4 terms, asks Lean for the verdicts (stability of linear recursions,
index bounds of table reads and delays), and writes `OUT.lean` with one
`by decide` theorem pinning each verdict. It also compares Lean's table verdicts
with the clamps the compiler actually inserts (`-ct 1` against `-ct 0`), and
fails if a table that needs a clamp was left unclamped.

- Environment: `FAUST_RS` (compiler, default `target/release/faust-rs`),
  `FAUST_LIBS` (library directory passed with `-I`), `LEAN` (default `lean`).
- `make certify` writes `tests/build/certified.lean`, kernel-checks it and
  diffs it with the committed `tests/lean/certified.lean`.
- `make certify-reference` rewrites the committed file.

The workflow and the meaning of the verdicts are in `doc/docs/contributing.md`,
section *Formal certification*.

### `check_certify.py`

```
scripts/check_certify.py [--changed]
make check-certify
```

Regenerates the theorems with `sig2lean.py`, kernel-checks them, and compares
their verdicts with `tests/lean/certified.lean`: the Boolean of each theorem and
the lines of the clamp oracle. A verdict that moved, or a program added without
`make certify-reference`, fails; terms that differ with the same verdicts pass
with a note, where `make certify` fails on them. About 10 s.

`check_doc.py` runs it with `--changed`: nothing happens unless a library,
`tests/lean/`, `formalisation/` or the generator differs from HEAD, and it stays
out of the way (exit 0, one clause in the summary line) when `lean` or `faust-rs`
is missing, or when `lean` is not the version of
`formalisation/mathlib/lean-toolchain`.

- Environment: `FAUST_RS` (default `faust-rs`), `LEAN` (default `lean`).
