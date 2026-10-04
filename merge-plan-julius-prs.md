# Merge plan for Julius's open PRs

Analysis of the merge order of the 22 open PRs of Julius (#269 to #299),
made on 2026-10-04 against master `bf9f71af` (#296, #298).

## State of the PRs

All 22 PRs are rebased on master `bf9f71af`. Each branch on `origin`
matches its PR head, and GitHub reports every one of them as mergeable.

Some PRs are stacked: each one contains the commits of the PRs before it.

| Stack | PRs |
|---|---|
| analog sections (filters.lib) | #272 → #273 → #277 → #292 → #293 |
| oscillators.lib phase | #283 → #294 → #297 → #299 |
| filters.lib / analyzers.lib fixes | #282 → #290 |
| delays, reverbs, demos | #284 → #291 |
| `re.fdnrev0` `nonl` | #289, on #284; it also holds copies of the two #282 commits (same patches, other SHAs) |
| crybaby / autowah | #270 → #288 |
| standalone | #269, #271, #285, #286, #287, #295 |

#295 contains neither #292 nor #294, but its description asks to merge it
after both.

## Method

The conflicts were measured on two levels:

1. Pairwise: `git merge-tree --write-tree --merge-base origin/master A B`
   for every pair of PRs where neither PR contains the other.
2. Sequentially: every PR head merged in turn onto the cumulated result
   (`git merge-tree`, then `-X theirs` to carry on past a conflict). This
   was done for Julius's order and for about 150 other orders that respect
   the stacks.

Each conflict hunk is classified as:

- `version`: only `declare version` lines;
- `bookkeeping`: `tests/precision-baseline.json` or
  `tests/extended-tests-survey.md`;
- `gen-doc`: a generated `doc/docs/libs/*.md` file (regenerate it, do not
  merge it by hand);
- `real`: library code or documentation.

## Result: conflicts cannot be avoided, only placed

A conflict between two PRs shows up whichever of them is merged first. The
order only decides at which step it appears. No order goes below
**6 steps with conflicts, 3 of them real hunks**. Julius's order reaches
this minimum, so it is the one kept.

The reason is that each PR was rebased on master on its own, and many of
them touch the same files: the survey, the precision baseline, and the
`declare version` lines.

## Recommended order

| Step | PRs | Conflicts |
|---|---|---|
| 1 | #272 → #273 → #277 → #292 → #293 | none; master can be fast-forwarded to #293 directly, which merges all five |
| 2 | #282 | **real**, in filters.lib (see below), plus its version and the generated `filters.md` |
| 3 | #290 | none |
| 4 | #283 → #294 → #297 → #299 | none |
| 5 | #284 | none |
| 6 | #289 | analyzers.lib version (1.4.5 against 1.5.0); the #282 copies drop out on rebase |
| 7 | #291 | none |
| 8 | #269 | bookkeeping (survey, precision baseline) |
| 9 | #270 → #288 | bookkeeping, for #270 |
| 10 | #271 | bookkeeping, plus the vaeffects.lib version |
| 11 | #285, #286 | none |
| 12 | #287 | **real**, in filters.lib (see below), plus the reverbs.lib version |
| 13 | #295 | none; it comes after #294 and #292, as it asks |

## The three real conflicts

1. **`fi.tf1s`: #282 against #292/#293.** The two PRs fix the same function
   in two ways. #282 multiplies the bilinear transform through by
   `t = tan(w1/2/SR)`, so that `w1 = 0` gives finite coefficients.
   #292/#293 rewrite it as a trapezoidal (TPT) integrator. Keep only one;
   the TPT one is probably the right choice, since it is the newer one and is
   tested up to Nyquist. Ask Julius to confirm.
2. **`fi.peak_eq` documentation: #282 against #292.** #292 documents that
   `fx` is clamped to [0.001, 0.499*SR], and that the peak becomes a shelf
   as `fx` goes to 0. #282 defines `B` (B = fx/Q, the -3 dB bandwidth of the
   peak). The two texts are to be combined.
3. **`fi.tf2snp`: #287 against #273.** #287 adds the
   `declare tf2snp author/copyright/license` lines and rewrites the comment
   line just above them ("tf2s keeps its accuracy" in #273, "fi.svf keeps
   its accuracy" in #287). Keep the declares, and the comment as #273 wrote
   it.

## Two traps that git does not report

- **Duplicate version numbers.** Several PRs raise a library to the same
  number. Git merges identical lines without a conflict, so the second PR
  merged keeps the number of the first.

  | Library | Number | Taken by | Also claimed by |
  |---|---|---|---|
  | vaeffects.lib | 1.6.4 | #273 (stack 1) | #270, #271, #286; #288 claims 1.6.5 |
  | filters.lib | 1.11.11 | #272 | #282, #287, #289, #290 |
  | reverbs.lib | 1.5.5 | #289 | #291 |
  | reverbs.lib | 1.5.4 | #284 | #287 |
  | analyzers.lib | 1.4.5 | #282 | #289 (and #290 has 1.5.0) |

  At each step, the PR being merged takes the next free number of each
  library it touches.
- **#289 holds copies of #282's commits.** The patches are the same, the
  SHAs differ. `git rebase` drops them as already applied, as long as #282
  is merged first, which the order above ensures.

## Procedure

History stays linear (AGENTS.md, *Git history*): no merge commits.

1. Step 1 is a fast-forward: master is still `bf9f71af`, the base of the
   whole stack.

   ```bash
   git merge --ff-only origin/svf-tf2s-speedup
   ```

2. From step 2 on, master has moved. Each PR, or the tip of each stack, is
   rebased on the current head, its conflicts resolved and its versions
   renumbered. Then `make checkdoc` is run, along with `make check` on
   the touched tests (after `rm -rf tests/output`) and `make check-precision`
   on the touched test files. The branch is fast-forwarded last:

   ```bash
   git rebase master-merge-julius <pr-branch>
   git checkout master-merge-julius
   git merge --ff-only <pr-branch>
   ```

3. GitHub marks a PR as merged only when its head commit is reachable from
   master. A rebased PR therefore has its branch pushed
   (`git push --force-with-lease origin <pr-branch>`) before master is
   advanced to it.

The references are regenerated for the tests whose output each PR changes
on purpose. A test failure outside the scope of the PR means a resolution
error.

## Execution record (2026-10-04)

The merge was done on `master-merge-julius` in the order above, PR by PR,
with `git rebase --onto <current head> <original head of the parent PR>
<branch>`. Each rebased branch is kept locally as `mj/<branch>`. Julius
confirmed the three resolutions and the version numbers in #263
beforehand, and did not push to the 22 branches meanwhile.

### Rebased heads

| PR | Branch | Original head | Rebased head (`mj/<branch>`) |
|---|---|---|---|
| #272 | `tf3slf-tpt` | `9d6a3282` | `15f13da1` |
| #273 | `tf2s-tpt` | `ed44a5ef` | `85079fe9` |
| #277 | `svf-hpfirst` | `9c1798d3` | `4b137a66` |
| #292 | `w1-zero-safe` | `df80c2b8` | `631c240c` |
| #293 | `svf-tf2s-speedup` | `71b9f913` | `06985a1d` |
| #282 | `jos-fixes-filters` | `2520cf6a` | `ea760b08` |
| #290 | `rtocv-order` | `2a0c097b` | `81cfe8b6` |
| #283 | `jos-fixes-oscillators` | `d5a37e32` | `b137daed` |
| #294 | `lf-sawpos-float` | `b3a7e89e` | `ba96bc50` |
| #297 | `saw2ptr-float` | `95763a0f` | `31369386` |
| #299 | `saw4-float` | `90108b25` | `5f75048f` |
| #284 | `jos-fixes-delays-reverbs` | `12311ebc` | `18b2bdce` |
| #289 | `fdnrev0-nonl` | `500ab88a` | `59c15088` |
| #291 | `zita-match-rev1` | `81ecac3e` | `b54a282f` |
| #269 | `modefilter-float` | `46ddf145` | `15be6acc` |
| #270 | `crybaby-float` | `5fc2a56d` | `ab3a45ab` |
| #288 | `autowah-clamp` | `172b5f02` | `f541c0c0` |
| #271 | `bandpass2matched-float` | `438fd5d3` | `efbcd9fb` |
| #285 | `jos-fixes-phaflangers` | `a1ee2cb7` | `c575fdd1` |
| #286 | `jos-fixes-moog-doc` | `1191c6a3` | `f75aa595` |
| #287 | `jos-doc-batch` | `02e4a5ef` | `7968a3f7` |
| #295 | `motion-lf-oscillators` | `29959eff` | `164521d8` (one commit added, below) |

`master-merge-julius` ends with one more commit, `version.lib` 2.76.0 →
2.77.0: the batch adds functions (the `_chrono` analyzers of #290), so
MINOR.

### Conflicts as they came, and their resolution

The replay stopped on 8 commits, all of them predicted above.

- **#282**, commit `filters.lib: filter-bank delay equalizers, ...`:
  - version: 1.11.16;
  - `tf1s`: #292's TPT body kept, #282's multiply-through-by-`t` body
    dropped. The commit message says so. #282's other `tf1s`-related
    content merged without conflict: both PRs had added the same
    `tf1s_zero_freq_test` line to the doc block and to
    `tests/filters_analog_sections_tests.dsp`. Git kept both copies, so one
    of each was removed;
  - `peak_eq` `Where:`: #292's `fx` bullet (the clamp, and the shelf as
    `fx` goes to 0) followed by #282's `B` bullet (B = fx/Q);
  - `doc/docs/libs/filters.md`: regenerated (`make -C doc md index`).
- **#269**: survey and baseline. The resolution keeps every removal made
  by either side: the `modeFilter_jump_test` row and its deferred test go
  (#269 reactivates it), and the `moog_vcf_2b` ones stay gone (#273). The
  18 bell, marimba and djembe level entries go; so do `saw4_test`,
  `scope_test` and `simplex1_test`, which the oscillators stack had
  removed.
- **#270**: survey and baseline, same rule. The deferred-test row becomes
  #270's `bandpass2Matched_slider_test` row. `autowah_test`,
  `crybaby_test` and `crybaby_demo_test` leave the baseline.
- **#271**, by hand:
  - the six `*2Matched_modulated_test` rows and deferred tests go (#271),
    and so do both slider-test rows: #270 fixed the `autowah`/`crybaby`
    ones and #271 the `bandpass2Matched` one;
  - the paragraph that said which `_test`s still take sliders now reads:
    "`autowah_test` and `crybaby_test` were split into a constant `_test`
    and a `_slider_test` with #270, and `bandpass2Matched_test` with
    #271.";
  - `tests/precision-baseline.json`: `"nonfinite": {}` (#272 removed
    `tf3slf_test`, #271 `bandpass2Matched_test`);
  - vaeffects.lib: 1.6.7.
- **#286**: vaeffects.lib 1.6.8.
- **#287**: filters.lib 1.11.17; `tf2snp`: #273's comment ("tf2s keeps its
  accuracy") followed by #287's three `declare tf2snp` lines;
  reverbs.lib 1.5.7.

The version numbers that git merged silently were set by amending the
commit that raises them in the original PR: reverbs.lib 1.5.6 (#291),
vaeffects.lib 1.6.5 (#270) and 1.6.6 (#288). Final versions:
filters.lib 1.11.17, vaeffects.lib 1.6.8, reverbs.lib 1.5.7,
analyzers.lib 1.5.0, oscillators.lib 1.9.4, demos.lib 1.6.3,
physmodels.lib 1.2.3, motion.lib 0.10.2.

### Checks at each step

`make check` was run in full after `rm -rf tests/output`, against
references that each step brings up to date. The references were rebuilt
at `bf9f71af` (1945 tests, no difference) before step 1. At each step, the
tests that differed were compared with the list in the PR description.
Only those references, and those of the new tests, were regenerated, and
all of them were checked to be finite and nonzero. `make check-precision`
was run on the touched test files and on the files whose baseline
entries the step removes.

| Steps | Differ | Matches the PRs | New tests | check-precision |
|---|---|---|---|---|
| 1 (#272-#293) | 59 | #292 reports 60 (#273's 11 and 49 of its own); the 59 here all belong to the families it lists (`tf2s`, `tf1s` and band-section callers under modulation or jumps, the three slow-start demos) | 47 | 336 tests, 0 failed |
| 2-3 (#282, #290) | 29 | the 25 of #282, plus the jump/zero-freq tests of `peak_eq`, `peak_eq_cq` and `resonhp` that step 1 added | 15 | 189, 0 failed |
| 4 (#283-#299) | 38 | exactly #283's 38 | 21 | 182 + 127 (files of the removed baseline entries), 0 failed |
| 5-7 (#284, #289, #291) | 20 | exactly the 20 of #291 (#284's 15 and the `zita_rev_fdn` loop length) | 11 | 169 + 33 (instruments), 0 failed |
| 8-10 (#269, #270, #288, #271) | 1 | `modeFilter_modulated_test`, as #269 says | 24 | 324, 0 failed |
| 11-13 (#285, #286, #287, #295) | 30 | #285's 17 and #295's 13; none for #286 and #287 | 2 | 186, 0 failed |

On the final head: `make check`, 2065 tests, 0 differences, 0 missing
references; `make checkdoc` OK; `scripts/check_usage.py` on every
library: 1197 symbols, 0 debt; `scripts/normalize_licenses.py --check`
OK; `import("all.lib"); process = _;` compiles; the regenerated docs
(`make -C doc md index`) are identical to the committed ones.

### #295: `orientation6_test` was silent

The check of the new references found one all-zero output:
`orientation6_test`, on all six channels, already on #295's own head. In
#295, the test's inputs became `os.lf_triangle(0.05)`, `os.sawtooth(0.08)`
and `os.lf_triangle(0.03)`. `os.lf_triangle` starts at -1, and at these
frequencies the three inputs stay near (-1, -1, -1) for the whole second
the test renders (still -0.80, -0.84, -0.88 at its end). That point is at
least 1.41 from every axis, while a lobe only reaches 1/`shape` = 1, so
every weight is 0. The previous `os.triangle(0.05)` stayed near 0 and
put the vector in the Rear lobe.

The fix, a commit added to the PR (`164521d8`), drives the test at 1.5,
2.5 and 3.5 Hz, in the doc block and in `tests/motion_tests.dsp`. Among
the frequencies tried, it is the one whose vector crosses all six lobes
within the second: every output is nonzero, with peaks from 0.49 to 0.71.
`check-precision` on `tests/motion_tests.dsp`: 21 tests, 0 failed.

### Publishing

Still to do, in this order:

1. Push each rebased branch over its PR branch, guarded by its original
   head:

   ```bash
   git push --force-with-lease=<branch>:<original head> origin mj/<branch>:<branch>
   ```

2. Push `master-merge-julius`, then fast-forward `master` to it. GitHub
   then marks the 22 PRs as merged.
3. Tell Julius in #263 that the merge is done, and that his branches are
   free again.
