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
- The test references (`tests/reference/`, ~1.2 GB) are local build
  artifacts: generate them with `make reference`, never commit them. Same
  for the built site (`site/`) and `tests/build|output`.
- A test failure means the change altered audible output. That is either a
  bug in the change or a deliberate fix; in the second case say so
  explicitly and regenerate only the affected references.

## Hard rules for library changes

1. **Every new public function** needs, in the same commit:
   - a full documentation block (description, `#### Usage` showing the
     input/output shape, `Where:` for each parameter, `#### Test`);
   - a `functionName_test` entry in the matching `tests/*.dsp` file, and its
     reference generated with `make reference`;
   - a `declare functionName license "ID";` with a canonical SPDX
     identifier (check with `scripts/normalize_licenses.py --check`).
2. **Internal helpers** that cannot live in a `with { }` /
   `environment { }` block are prefixed `_name`. They need no doc block and
   are excluded from coverage; never use another library's `_` symbols.
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
6. Do not edit generated files by hand: `doc/docs/libs/*.md`,
   `doc/docs/standardFunctions.md` (regenerate with
   `scripts/build_standard_functions.py`) and the figures in
   `doc/docs/img/` (regenerate with `make plots` — the generator embeds
   property assertions and must end with "all property assertions hold").
7. **Keep the LLM-facing JSON exports working.** `make doc-index-split`
   (`scripts/build_faust_doc_index.py`) parses the same doc blocks into the
   machine-readable index that MCP tools and `scripts/faust_doc_api.py`
   consume. After any change to documentation *format* (header shapes,
   section names, block structure), regenerate the export and spot-check
   that the touched symbols still come out with their summary, usage,
   params and license (`scripts/faust_doc_api.py get_faust_symbol xx.name`).
   `make checkdoc` guards the floor — the exported symbol count may only
   grow — but it cannot see a field that silently comes out empty.
