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
