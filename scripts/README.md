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

The scripts that turn the `.lib` files into the documentation pages
(`faustlib2md.awk`, `inject_plots.py`, `makeindex.awk`) are in `doc/scripts/` and
are run by `doc/Makefile`.

**Prerequisites**, by use:

- tests: `faust` and a C++17 compiler; `check_precision.py` also needs `numpy`;
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
make check-precision [PRECISION_ARGS="..."]
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
  test file or the architecture is newer. The whole suite takes about ten
  minutes on ten cores when everything is rebuilt, one minute otherwise.
- `--json FILE` writes every measurement (per test and rate: finite, peak, gap,
  level, growth).
- `--write-baseline` rewrites the baseline from a run over all tests; it is for
  a change of rates, threshold or harness, never to silence a failure.

Exit status 0 when every test passes, 1 otherwise. See
`doc/docs/contributing.md`, section *Precision and sample rate*, and
`AGENTS.md`, rule 9.

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
