# Agent instructions for faustlibraries

This repository is the Faust DSP standard library set: the `*.lib` files at
the root are the product. The online documentation is generated from their
comment blocks (`doc/`), and the regression tests are extracted from those
same blocks. Detailed conventions live in `doc/docs/contributing.md` — this
file is the operational summary.

## Commands

```bash
make checkdoc    # documentation & license gate - run before every commit
make reference   # build the test references (needs faust + a C++ compiler)
make check       # run the regression tests against the references (-k to run all)
make plots       # regenerate the documentation SVG figures (needs matplotlib)
make build       # build the mkdocs site (doc pages + figure injection)
```

- `make checkdoc` must pass before committing: it rejects any new
  undocumented symbol, any doc block without `#### Usage` (or reduced to a
  `#### Test`), a stale `doc/docs/standardFunctions.md`, and any
  non-canonical license string. Accepted historical debt is pinned in
  `tests/doc-baseline.json`; never regenerate that baseline to silence a
  failure you caused.
- The test references (`tests/reference/`, ~1.4 GB) are local build
  artifacts: generate them with `make reference`, never commit them. Same
  for the built site (`site/`) and `tests/build|output`.
- A test failure means the change altered audible output. That is either a
  bug in the change or a deliberate fix; in the second case say so
  explicitly and regenerate only the affected references.
- **`make check` caches**: the `.out`/`.ref` targets do not depend on the
  `.lib` sources, so after editing a library a plain `make check` re-runs
  only tests whose outputs are missing and silently skips the rest. For a
  real full validation, `rm -rf tests/output` first; to regenerate
  references after a deliberate behavior change, delete the affected
  `.ref` files before `make reference`.

## Hard rules for library changes

1. **Every new public function** needs, in the same commit:
   - a full documentation block (description, `#### Usage` showing the
     input/output shape, `Where:` for each parameter, `#### Test`);
   - a `functionName_test` entry in the matching `tests/*.dsp` file, and its
     reference generated with `make reference`;
   - a `declare functionName license "ID";` with a canonical SPDX
     identifier (check with `scripts/normalize_licenses.py --check`).

   The doc-block **title must name every symbol the block documents,
   exactly**, each in its own backquotes: `` `(pp.)name` `` or
   `` `(pp.)name1`, `(pp.)name2` `` for multi-function blocks. The tooling
   does not recognize a title with a trailing space inside the backquotes,
   an argument list appended to the name, or a sibling only mentioned in
   the prose — all three make the symbol count as undocumented. The
   generic pattern `` `name[N]` `` matches digit suffixes only
   (`name1`..`name9`), not letter variants.

   Test names must be **unique across all of `tests/*.dsp`** (each becomes
   one `tests/reference/<name>.ref`), and must not differ from an existing
   name only by letter case — the `.ref` files collide on case-insensitive
   filesystems (macOS). Prefix with the library's short name (`mm_`,
   `tu_`, `inst_`) when the natural name is taken. Every test must produce
   a **nonzero output signal**: a gate defaulting to 0 or a slider
   defaulting to silence turns the reference into all zeros, which
   validates nothing. Check the generated `.ref` before committing it.
2. **Internal helpers** that cannot live in a `with { }` /
   `environment { }` block are prefixed `_name`. They need no doc block and
   are excluded from coverage; never use another library's `_` symbols.
   When hiding or renaming an existing public-by-accident symbol, the old
   name survives one published release as a deprecated alias grouped at
   the end of the file (`declare oldname deprecated "...renamed _name";`
   `oldname = _name;` — or a frozen copy of the body when the definition
   moved into a `with`). Before hiding anything, check it is not used by
   another library, a documented example, or an explicit-substitution
   switch (`os[SAFE=1;]`) — any of those makes it de facto public: document
   it instead.
3. **Naming**: existing symbols keep their names; new code follows the
   dominant style of the file (or section) it lands in.
4. **Versioning**: raise the library's `declare version` in the same commit
   (MAJOR = breaking, MINOR = additions or newly documented symbols,
   PATCH = fixes and `_`-internal work), and `version.lib` per batch. Full
   policy: `doc/docs/contributing.md`, section *Versioning*. Removing a
   `declare ... deprecated` alias is a MAJOR change and must wait one
   published release.
5. **Cross-library calls** go through the environment prefixes
   (`ma = library("maths.lib"); ... ma.PI`), never bare names. Check name
   collisions with `import("all.lib"); process = _;`.
6. Do not edit generated files by hand: `doc/docs/libs/*.md` (regenerate
   with `make -C doc md`), `doc/docs/libs/index.md` — the symbol index
   linking every documented name to its page, rebuilt from those pages by
   `make -C doc index`, so it is stale until the `md` step has run and a
   new public function is missing from it until both have —
   `doc/docs/standardFunctions.md` (regenerate with
   `scripts/build_standard_functions.py`) and the figures in
   `doc/docs/img/` (regenerate with `make plots` — the generator embeds
   property assertions and must end with "all property assertions hold").
   `make -C doc build` chains `md` and `index` before building the site;
   prefer it over `md` alone, which silently leaves the index behind.
7. **Keep the LLM-facing JSON exports working.** `make doc-index-split`
   (`scripts/build_faust_doc_index.py`) parses the same doc blocks into the
   machine-readable index that MCP tools and `scripts/faust_doc_api.py`
   consume. After any change to documentation *format* (header shapes,
   section names, block structure), regenerate the export and spot-check
   that the touched symbols still come out with their summary, usage,
   params and license (`scripts/faust_doc_api.py get_faust_symbol xx.name`).
   `make checkdoc` guards the floor — the exported symbol count may only
   grow — but it cannot see a field that silently comes out empty.

## Git history

The history is linear and must stay that way: no merge commits. The last one
dates from December 2020, and every commit since sits on a single strand.
Bisecting a 1400-commit library where a regression means "an audible output
changed" depends on it.

- **Never** `git merge` a branch that has diverged. Rebase the branch onto its
  target, then fast-forward:

  ```bash
  git rebase master my-branch      # replay, resolve conflicts here
  git checkout master
  git merge --ff-only my-branch    # refuses rather than creating a merge commit
  ```

- Update from the remote with `git pull --rebase`, never a plain `git pull`.
  Configure it once so a stray pull cannot create a merge:

  ```bash
  git config pull.rebase true
  git config merge.ff only
  ```

- Squash the work-in-progress commits of a branch before integrating it. One
  commit per coherent change: a library edit, its tests, its regenerated
  documentation and its version bumps belong together, not spread over five
  commits that each leave `make checkdoc` or `make check` failing.
- Rewriting history (`rebase`, `--amend`, squash) is fine as long as the
  commits have not been pushed. Once they are on `origin`, they are frozen:
  fix forward with a new commit.
- Do not commit build artifacts even when they sit in the working tree.
  `.gitignore` covers `site/` but not `tests/reference/`, `tests/output/`,
  `tests/build/` or the doc index exports (`tests/faust-doc-index.json`,
  `tests/faust-doc/`), so never stage with `git add -A` or `git commit -a` —
  name the files you mean.
