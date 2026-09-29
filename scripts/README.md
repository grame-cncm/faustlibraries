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
| [`check_cpu.py`](#check_cpupy) | CPU cost of the tests, new / base ratio between two versions | `make check-cpu` |
| [`lib_tests.py`](#lib_testspy) | inventory of a library's tests; adds tests to its doc blocks and to `tests/*.dsp` | — |
| **Documentation checks** | | |
| [`checkdoc.py`](#checkdocpy) | documentation and license gate, against a baseline | `make checkdoc` |
| [`audit2.py`](#audit2py) | documentation coverage per library | `checkdoc.py` |
| [`audit.py`](#auditpy) | naive coverage audit, kept for comparison | — |
| [`build_standard_functions.py`](#build_standard_functionspy) | generates `doc/docs/standardFunctions.md` | `checkdoc.py` (`--check`) |
| [`normalize_licenses.py`](#normalize_licensespy) | canonical SPDX license strings | `checkdoc.py` (`--check`) |
| **JSON export** | | |
| [`build_faust_doc_index.py`](#build_faust_doc_indexpy) | builds the JSON documentation index | `make doc-index*`, `checkdoc.py` |
| [`faust_doc_api.py`](#faust_doc_apipy) | queries that index | — |
| **Figures** | | |
| [`plot_lib.py`](#plot_libpy) | `aanl.lib` figures | `make plots` |
| [`plot_families.py`](#plot_familiespy) | figures of the other libraries, with property assertions | `make plots` |
| **Formal certification** | | |
| [`sig2lean.py`](#sig2leanpy) | Faust signals to Lean 4 theorems | `make certify`, `certify-reference` |
| [`certify_tests.py`](#certify_testspy) | the Lean rate analysis on every regression test | `make certify-tests` |
| [`lyapunov_oracle.py`](#lyapunov_oraclepy) | untrusted Lyapunov certificates for the rate analysis | `sig2lean.py`, `certify_tests.py` |

The scripts that turn the `.lib` files into the documentation pages
(`faustlib2md.awk`, `inject_plots.py`, `makeindex.awk`) are in `doc/scripts/` and
are run by `doc/Makefile`.

**Prerequisites**, by use:

- tests: `faust` and a C++17 compiler; `check_precision.py` also needs `numpy`;
- figures: `faust`, `g++`, `numpy` and `matplotlib`;
- certification: `faust-rs` and `lean` (4.31); the Lyapunov certificates
  also need `numpy` and `scipy` (without them, the groups they would prove
  stay not proven);
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
one line per frame, the frame index and then one sample per output. They match
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
reported, because `os.osc`, the input of many tests, drifts in phase in float.
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
  repetitions. Buttons are pressed, as in `print_arch.cpp`, so that an
  instrument test is not timed on silence.
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
three tests: `name_test`, `name_slider_test` and `name_modulated_test` (see
`doc/docs/contributing.md`, section *Constant, slider and modulated tests*). This
script checks and maintains both places.

**`inventory LIB`** lists, for every symbol documented in LIB, where each of the
three tests exists: `both`, `lib` or `dsp` (one side only), or `-`. The tests
present on one side only break rule 8 and are listed first; the exit status is
then 1. `--missing` hides the symbols that have all three. Whether a function
needs the slider and modulated variants is a judgement, which the inventory
leaves to you: its parameters must be meant to vary at run time.

```bash
scripts/lib_tests.py inventory filters.lib --missing
```

**`add LIB SPEC.dsp`** inserts the tests of SPEC.dsp wherever they are missing.
SPEC.dsp is an ordinary Faust file, with one definition per line: `xx =
library("...");` imports, `*_test` definitions (a `with { }` on the same line
is fine), and the helper definitions the tests use (`src = os.osc(440);`). It
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
- run `make checkdoc`.

## Documentation checks

### `checkdoc.py`

```
scripts/checkdoc.py [--update-baseline]
make checkdoc
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
   from what the exporter understands.

`--update-baseline` records the current debt as accepted. Never use it to hide a
gap you introduced. Exit status 1 on any regression.

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
make doc-index | doc-index-split | doc-index-commercial
```

Extracts the documentation from the `.lib` sources, not from the generated
pages. Starting from `stdfaust.lib`, it follows `library()` and `import()`,
finds the doc-block titles, and parses each block into summary, usage,
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

The last line printed is a JSON summary, including `symbolsCount`, which
`checkdoc.py` compares with its baseline. After a change to the doc-block
format, regenerate the export and check the touched symbols (`AGENTS.md`,
rule 7).

### `faust_doc_api.py`

```
scripts/faust_doc_api.py [--index PATH] [--pretty] COMMAND ...
```

Queries an index built by `build_faust_doc_index.py`, with the operations of the
Faust-library MCP tools. `--index` is an index file or a split directory; by
default `tests/faust-doc/index.json`, then `tests/faust-doc-index.json`. Every
command prints JSON.

| Command | Result |
|---|---|
| `search_faust_lib QUERY [--limit N] [--module M]` | ranked symbols matching a free-text query |
| `get_faust_symbol SYMBOL` | the full entry of a symbol (`lowpass` or `fi.lowpass`) and close alternatives |
| `list_faust_module MODULE [--limit N]` | the symbols of a module |
| `get_faust_examples SYMBOL_OR_MODULE [--limit N]` | the `#### Test` snippets of a module, else of a symbol |
| `explain_faust_symbol_for_goal SYMBOL GOAL` | a short recommendation built from the stored documentation |

A module is named by its file stem, its file name or its prefix: `physmodels`,
`physmodels.lib` or `pm`.

```bash
make doc-index-split
scripts/faust_doc_api.py --pretty get_faust_symbol fi.lowpass
```

## Figures

Both scripts write SVG files to `doc/docs/img/` (`--out` to change it), where
`doc/scripts/inject_plots.py` embeds each one in its function's page by naming
convention. `make plots` runs both, then rebuilds the documentation. The figures
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

## Formal certification

### `sig2lean.py`

```
scripts/sig2lean.py TEMPLATE.lean OUT.lean FILE.dsp [FILE.dsp ...]
make certify | certify-reference
```

Compiles each program with `faust-rs --dump-sig-dag`, translates its signals
into Lean 4 terms, asks Lean for the verdicts (stability of linear recursions,
index bounds of table reads and delays, and stability of each recursion group
at the six rates of `check-precision` in exact, double and single arithmetic),
and writes `OUT.lean` with one `by decide` theorem pinning each verdict. For
the rate analysis it also emits the whole graph as a `Dag` (one node per dump
binding) and prints the verdicts per program and precision
(`rates lowpass3 single: n26:SSSSSS;n49:SSSSSS`). It also compares Lean's table verdicts
with the clamps the compiler actually inserts (`-ct 1` against `-ct 0`), and
fails if a table that needs a clamp was left unclamped. For the groups that
Jury and the small-gain test leave unproven, it passes the linear systems
Lean prints to `lyapunov_oracle.py`, runs Lean again with the certificates,
and pins them in `OUT.lean` as `X_wit_p` definitions, one line each.

- Environment: `FAUST_RS` (compiler, default `target/release/faust-rs`),
  `FAUST_LIBS` (library directory passed with `-I`), `LEAN` (default `lean`).
- `make certify` writes `tests/build/certified.lean`, kernel-checks it and
  diffs it with the committed `tests/lean/certified.lean`, without the
  certificate lines: their floats may differ from one platform to another.
- `make certify-reference` rewrites the committed file.

The workflow and the meaning of the verdicts are in `doc/docs/contributing.md`,
section *Formal certification*.

### `certify_tests.py`

```
scripts/certify_tests.py [TEST.dsp ...] [-k REGEX] [-j JOBS] [--json FILE]
                         [--kernel] [--write-baseline]
make certify-tests [CERTIFY_ARGS="..."]
```

`make certify` proves theorems about the small programs of `tests/lean/`. This
script runs the same rate analysis (`srVerdicts`, see `sig2lean.py`) on every
`*_test` of `tests/*.dsp`. For each recursion group of a test, it gives one
letter per rate from 44.1 to 192 kHz, in exact, double and single arithmetic,
with the controls at their default values:

- `S`: stable;
- `U`: linear but not proven stable. It can be a marginal recursion (an
  integrator, a counter, a sine oscillator by rotation: a pole on the unit
  circle); a coefficient whose rounding in single precision can cross the
  stability limit (a direct-form section at a low frequency and a high rate);
  or a loss of precision of the analysis (two exclusive conditions each
  bounded in [0, 1]);
- `R`: refused, with the reason, such as nonlinear, integer recursion or a
  coefficient that cannot be bounded. A refusal measures the coverage of the
  analysis and never fails.

The probe also gives, per rate, a verdict on the time-invariant values (`F`
finite, `D` an operation may leave its domain or overflow, `?` not bounded)
and one on each table read and delay tap (`I` in range for every value of
the controls, `N` not proven). The summary counts them.

A test fails when it has more `U` slots, counted as (group, rate) pairs, or
more `D` rates than `tests/certify-baseline.json` accepts for it in one of
the three arithmetics. Indices never fail: `N` often means an index computed
from a signal whose range is unknown. A new test is not in that file, so it must have none. Baseline
entries that are no longer needed are reported, and `--write-baseline`
regenerates the file from a full run. The summary counts the structurally
distinct recursion groups, so that the `os.osc` of most test inputs counts
once. It also confronts the non-finite entries of
`tests/precision-baseline.json` with the verdicts at the same rates.

- The prelude is compiled once to an `.olean` in `tests/build-certify/`, and
  each test is a small Lean file that imports it and evaluates the verdicts
  with `#eval`. The graph is passed as a string read by `Dag.parse`: a `Dag`
  literal of 10 000 nodes takes a minute to elaborate. The whole suite takes
  about six minutes on ten cores (the tests with Lyapunov certificates run
  twice).
- This runs the code of the theorems through Lean's evaluator, not its
  kernel. The suite run is a coverage and regression report; `--kernel` also
  re-checks every verdict with `decide +kernel`, which takes much longer.
- `--json FILE` writes every verdict, per test and group, with the refusal
  reasons, and the number of Lyapunov requests and certificates per test.
- A test with requests runs twice: the oracle answers between the two runs
  (`.lean`, then `.w.lean`).

### `lyapunov_oracle.py`

```
scripts/lyapunov_oracle.py < requests > answers
```

The untrusted half of the Lyapunov certificates of the rate analysis (section
*Lyapunov–Krasovskii certificates* of the prelude). Each request line
`L|group|rate|nx nl|output:delay ...|rows` is the linear system Lean built for
a recursion group: `nx` states, `nl` delay-line channels, and the sparse rows
of `G = [[A, B], [Cx, Cz]]` with interval coefficients. The script answers
`W|group|rate|D|P` with dyadic rationals: `D`, block diagonal with one block
per delay length, weights the energy of the delay lines, and `P` weights the
energy of the states.

- `D` minimizes the peak over frequency of the scaled loop gain, by L-BFGS on
  a smoothed maximum.
- `P` solves the Riccati equation of the bounded-real lemma for that `D`.
  The script tries a few margins and keeps the first whose float estimate
  survives the box of the coefficients.

Lean checks every answer exactly and trusts none. The script needs `numpy` and
`scipy`; `sig2lean.py` and `certify_tests.py` import it, and skip the
certificates without it.