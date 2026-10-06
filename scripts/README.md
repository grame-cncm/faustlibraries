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
| [`verify_matched2.py`](#verify_matched2py) | proves the rewrites of Vicanek's matched filters and checks their coefficients at 60 digits | `make verify-matched` |
| **Documentation checks** | | |
| [`checkdoc.py`](#checkdocpy) | documentation and license gate, against a baseline | `make checkdoc` |
| [`check_usage.py`](#check_usagepy) | compiles the `#### Usage` sections: arity of the call, parameters; measures the io of the export | `make check-usage`, `checkdoc.py` (`--changed`), `build_faust_doc_index.py` (`--measure-io`) |
| [`audit2.py`](#audit2py) | documentation coverage per library | `checkdoc.py` |
| [`audit.py`](#auditpy) | naive coverage audit, kept for comparison | — |
| [`build_standard_functions.py`](#build_standard_functionspy) | generates `doc/docs/standardFunctions.md` | `checkdoc.py` (`--check`) |
| [`normalize_licenses.py`](#normalize_licensespy) | canonical SPDX license strings | `checkdoc.py` (`--check`) |
| **JSON export** | | |
| [`build_faust_doc_index.py`](#build_faust_doc_indexpy) | builds the JSON documentation index, io counts computed by faust | `make doc-index*`, `checkdoc.py` |
| [`faust_doc_api.py`](#faust_doc_apipy) | queries that index | — |
| **Figures** | | |
| [`plot_lib.py`](#plot_libpy) | `aanl.lib` figures | `make plots` |
| [`plot_families.py`](#plot_familiespy) | figures of the other libraries, with property assertions | `make plots` |
| **Formal certification** | | |
| [`sig2lean.py`](#sig2leanpy) | Faust signals to Lean 4 theorems | `make certify`, `certify-reference` |

The scripts that turn the `.lib` files into the documentation pages
(`faustlib2md.awk`, `inject_plots.py`, `makeindex.awk`) are in `doc/scripts/` and
are run by `doc/Makefile`.

**Prerequisites**, by use:

- tests: `faust` and a C++17 compiler; `check_precision.py` also needs `numpy`,
  and `verify_matched2.py` needs `numpy`, `sympy` and `mpmath`
  (`pip install sympy mpmath`);
- `check_usage.py`, and `build_faust_doc_index.py --measure-io` (the
  `make doc-index*` targets): `faust` (`checkdoc.py` skips the Usage check
  without it);
- figures: `faust`, `g++`, `numpy` and `matplotlib`;
- certification: `faust-rs` and `lean` (4.31);
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
- run `make checkdoc`.

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
and `fc` have values, `faust -e` evaluates its input/output counts, and its
sequential compositions fail when the buses do not match the arity of the
call. Each Usage line that names the symbol becomes
`process = inputs(<line>), outputs(<line>);`. This avoids printing the
expanded graph of large DSPs. In that expression:

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

Run the evaluator regression tests with `python3 tests/test_check_usage.py`
(requires `faust` on PATH).

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
(`dx.algorithms` alone, 50 s); `checkdoc.py` runs it with `--changed`, on the
libraries that differ from `HEAD` or are new. Exit status 1 on any
regression.

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
  `faust`, with guessed counts. `checkdoc.py` does not measure (it only
  counts the symbols).

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
