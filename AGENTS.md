# Agent instructions for faustlibraries

This repository is the Faust DSP standard library set: the `*.lib` files at
the root are the product. The online documentation is generated from their
comment blocks (`doc/`), and the regression tests are extracted from those
same blocks.

This file is the operational summary: the commands and the rules, stated
briefly. The reasons, the examples and the procedures live in
`doc/docs/contributing.md` (the section named at the end of each rule), and every
script is described in `scripts/README.md`. Read the section before working
in its area; when the two files disagree, fix the one that is wrong.

## Commands

```bash
make check-doc   # documentation & license gate - run before every commit
make check-usage # compile every #### Usage section (check-doc does the changed libraries)
make reference   # build the test references (needs faust + a C++ compiler)
make check       # run the regression tests against the references (-k to run all)
make check-vec   # the same with Faust's vectorized code generator
make check-precision  # every test in -single/-double at 44.1-192 kHz (no references); PRECISION_ARGS="tests/xx_tests.dsp"
make check-precision-matrix # the same with -O3 -ffast-math, Faust -vec and -lang ocpp
make check-extremes   # every test with its sliders at their extremes, all and one by one (about 2 min)
make check-jumps      # every test with its sliders jumping between their bounds during the run
make check-reinit     # every test after a second init(), same rate and rate change: equal to a fresh instance
make check-sr         # every test at 44.1, 96 and 192 kHz, noises made rate-independent: spectrum, level, decay must not move
make check-long       # every test rendered 2 min at 192 kHz, -single and -double: non-finite, growth, subnormals, drift
make check-weak       # every reference read: silent, below the tolerance, constant, settled, inputs unused (3 s)
make check-sanitize   # every test under ASan and UBSan, table guards off (about 30 min; DSP_FILES= to restrict)
make check-backends   # every test compiled for WebAssembly (validated and run), Cmajor (rendered), Julia, ... (check-doc does WebAssembly)
make check-backend-outputs # WebAssembly and Cmajor outputs compared with the C++ build in -single
make check-filter-claims # filters.lib/vaeffects.lib measured against their doc with faustprobe (faust-rs)
make check-tuning     # physmodels.lib instruments measured with faustprobe: pitch at 44.1-192 kHz (about 1 min)
make check-osc-claims # oscillators.lib and aanl.lib measured with faustprobe (about 1 min)
make verify-matched   # vaeffects.lib's matched filters: rewrites proved, coefficients at 60 digits
make check-mutation   # faults injected in a copy of the libraries: what do the tests detect? (about 1 h; MUTATION_ARGS="--lib xx.lib -n 50")
make check-cpu        # CPU cost of the tests, on an idle machine; CPU_ARGS="--base origin/master" for new/base ratios
make check-cpu-matrix # the same with the fast-math, strict and vec compilations
make check-plots      # regenerate every figure aside: stale figures, failed assertions (about 2 min)
make plots            # rewrite the figures whose rendering changed, rebuild the site
make build            # build the mkdocs site (doc pages + figure injection)
make doc-index-split  # the JSON export of the documentation (tests/faust-doc/)
make check-certify    # the Lean theorems regenerated and kernel-checked: a verdict moved? (10 s; check-doc does it when what it reads changed)
make certify          # the same, stricter: fails on any difference with tests/lean/certified.lean
make clean            # remove every test build and output, keep the references (distclean removes them too)
```

## Checks and references

- `make check-doc` must pass before committing. It rejects a new
  undocumented symbol, a doc block without `#### Usage` or reduced to a
  `#### Test`, a stale `doc/docs/standardFunctions.md` and a non-canonical
  license; with the tools installed, it also compiles the Usage sections,
  the tests for WebAssembly, reads the references (`check-weak`) and
  re-checks the Lean verdicts of what changed. *Testing the library*,
  *Formal certification*.
- **Baselines** (`tests/*-baseline.json`) pin accepted debt. A new test
  passes without an entry; a fix that makes an entry unnecessary removes it
  in the same commit; never add, loosen or regenerate an entry to silence a
  failure you caused. A lost Lean verdict is handled by
  `make certify-reference` in the same commit, never by rewording a rule.
- The references (`tests/reference/`) are local artifacts, never
  committed. They hold the bargraphs too. `make check` re-runs only the
  tests a change reaches, and a missing reference fails.
- A test failure means the change altered the output: a bug, or a
  deliberate fix. In the second case say so, delete only the affected
  `.ref` files and run `make reference`.

## Hard rules for library changes

1. **A new public function** comes, in the same commit, with a full doc
   block (description, `#### Usage` as a Faust expression that compiles,
   `_ : wgr(f,r) : _,_`, with the library's own names unprefixed and the
   meaningful inputs named, `Where:` for each parameter, `#### Test`), its
   tests in `tests/*.dsp` with their references, and a
   `declare name license "ID";` with a canonical SPDX id. The block title
   names every documented symbol exactly, each in its own backquotes. Test
   names are unique across `tests/*.dsp`, also ignoring case, and every test
   has a nonzero output. *New Functions*, *Documentation*.
2. **Internal helpers** that cannot live in a `with`/`environment` are
   prefixed `_name`; never use another library's `_` symbols. A symbol
   hidden or renamed keeps its old name as a deprecated alias for one
   published release; check first that nothing uses it (another library, an
   example, `os[SAFE=1;]`). *Variables and identifiers scoping*.
3. **Naming**: existing symbols keep their names; new code follows the
   dominant style of the file or section. *Function Naming*.
4. **Versioning**: raise the library's `declare version` in the same commit
   (MAJOR breaking, MINOR additions, PATCH fixes and `_` work), and
   `version.lib` per batch. Removing a deprecated alias is MAJOR and waits
   one published release. *Versioning*.
5. **Calls**: another library's functions through its prefix (`ma.PI`), the
   library's own by their bare name, never its own prefix; the prefix stays
   in Test sections, examples and `tests/*.dsp`. Check collisions with
   `import("all.lib"); process = _;`. *Variables and identifiers scoping*,
   *Library Import*.
6. **Generated files are regenerated, never edited**: `doc/docs/libs/*.md`
   and `index.md` (`make -C doc build`, not `md` alone),
   `doc/docs/standardFunctions.md` (`scripts/build_standard_functions.py`),
   the figures (`make plots`). *Documentation*.
7. **Keep the JSON exports working**: after a change of documentation
   format, regenerate them and check the touched symbols with
   `scripts/faust_doc_api.py get_faust_symbol xx.name`; a new function's
   `io` must come out with `"source": "faust"`. *Faust Library JSON Exports*.
8. **Tests are written in the library first**, in the `#### Test` section,
   then copied verbatim into `tests/*.dsp` (`scripts/lib_tests.py add`). A
   behavior fix comes with a test the old code fails. A parameter meant to
   vary at run time gets `_slider_test` and `_modulated_test` variants, a
   recursive filter a `_jump_test`, a VCF an `_audio_modulated_test`;
   modulate with `ba.period`, not `os.osc`. *Constant, slider, modulated and
   jump tests*.
9. **Check float and double, from 44.1 to 192 kHz**: `make check-precision`
   on the test files you touched, `make check-extremes`, and
   `make check-precision-matrix` for a fix that relies on an evaluation
   order. Prefer `no.noise` or `os.tosc` as test input. Report what was
   checked in the pull request. *Precision and sample rate*.
10. **Measure what a structural change costs**: `make check-cpu-matrix
    CPU_ARGS="--base origin/master ..."` on an idle machine, on the tests
    touched and their costly callers; report `fast-math` and `strict`, the
    identity lines, and any `!` in the `ops` column. *CPU cost*.
11. **Keep the figures in step**: a change of output runs the whole
    `make check-plots` before committing and regenerates the stale figures
    with `make plots` in the same commit; also before every `version.lib`
    bump. *Figures*.
12. **Library code compiles on every backend**: the only foreign functions
    allowed are `acosh`, `asinh`, `atanh`, `cosh`, `sinh`, `tanh`, `isnan`,
    `isinf` and `copysign`, however deep the call (`ma.expm1`, `ma.log1p`
    are portable). A backend that rejects valid code or diverges from the
    C++ `-single` build is a faust or runtime bug to report, not debt.
    *Backends and foreign functions*.

## Git history

The history is linear: no merge commits since December 2020. *Git history*.

- Never `git merge` a diverged branch: `git rebase master my-branch`, then
  `git merge --ff-only my-branch`. Pull with `git pull --rebase`.
- One commit per coherent change (library edit, tests, regenerated
  documentation, version bumps); squash work in progress. Rewrite only what
  is not pushed.
- Never commit build artifacts (`.gitignore` covers them; never `git add -f`),
  and never stage with `git add -A` or `git commit -a`: the working tree
  holds untracked scratch files. Name the files you mean.
