# Minimal test harness for Faust DSP tests and to build and test the documentation.
#
# `make reference`  - compile each *_test entry and store terminal output under tests/reference/.
# `make check`      - recompile, run each test, and diff against the stored reference output.
# `make checkdoc`   - verify documentation coverage, standardFunctions.md and licenses.
# `make clean`      - remove build artefacts and generated outputs (references are kept).
# `make distclean`  - additionally remove the stored reference outputs.
# `make bench`      - use faustbench-llvm to benchmark all test specs.
# `make certify`    - regenerate the Lean certification theorems into tests/build/,
#                     kernel-check them, and fail if any verdict drifted from the
#                     committed tests/lean/certified.lean.
# `make certify-reference` - regenerate and re-check tests/lean/certified.lean in place.
# `make build`      - build the documentation.
# `make serve`      - serve the documentation.
# `make doc-index`  - build the Faust library documentation JSON index.
# `make doc-index-split` - build a compact index plus one detailed JSON per module.
# `make doc-index-commercial` - build a JSON index filtered to commercially compatible symbols.

FAUST ?= faust
FAUST_OPT ?= -double -t 0
FAUSTBENCH ?= faustbench-llvm
CXX ?= g++
CXXFLAGS ?= -O2 -std=c++17
NUM_SAMPLES ?= 48000
SAMPLE_RATE ?= 48000

FLOAT_TOL ?= 1e-5
FLOATDIFF ?= ./scripts/floatdiff.py
PYTHON ?= python3
DOC_INDEX_SCRIPT ?= ./scripts/build_faust_doc_index.py
DOC_INDEX_OUTPUT ?= tests/faust-doc-index.json
DOC_INDEX_SPLIT_DIR ?= tests/faust-doc
DOC_INDEX_LICENSE_ALLOWLIST_FILE ?=
DOC_INDEX_LICENSE_DENYLIST_FILE ?=

# --- Lean certification (formalisation/ + tests/lean/) ---
LEAN ?= lean
FAUST_RS ?= faust-rs
SIG2LEAN := ./scripts/sig2lean.py
LEAN_SPEC_DIR := formalisation
LEAN_TEMPLATE := $(LEAN_SPEC_DIR)/signal-import-formal-spec.lean
LEAN_EXAMPLES_DIR := tests/lean
LEAN_CERT_DSP := $(sort $(wildcard $(LEAN_EXAMPLES_DIR)/*.dsp))
LEAN_CERTIFIED := $(LEAN_EXAMPLES_DIR)/certified.lean

ARCH := arch/print_arch.cpp
BUILD_DIR := tests/build
REFERENCE_DIR := tests/reference
OUTPUT_DIR := tests/output
DSP_TEST_DIR := tests
DSP_FILES := $(shell find $(DSP_TEST_DIR) -maxdepth 1 -name '*.dsp' | sort)
BENCH_LOG := tests/bench.log

.PHONY: reference check checkdoc plots clean distclean help bench certify certify-reference doc-index doc-index-split doc-index-commercial

# Remove a target whose recipe failed, so a failed test is re-run next time
# instead of being considered up to date.
.DELETE_ON_ERROR:

help: ## Show available targets and descriptions
	@printf "Usage:\n  make \033[36m<target>\033[0m\n\n"
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_\/\.-]+:.*## / {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)


# --- Parallel build setup for test specs ---
# Discover specs like "path/to/file.dsp:testname"
TEST_SPECS := $(shell scripts/extract_tests.sh $(DSP_FILES))
# Extract just the test names (the part after the colon)
TESTS := $(foreach s,$(TEST_SPECS),$(word 2,$(subst :, ,$(s))))
# Build lists of reference/output files
REFS := $(addprefix $(REFERENCE_DIR)/,$(addsuffix .ref,$(TESTS)))
OUTS := $(addprefix $(OUTPUT_DIR)/,$(addsuffix .out,$(TESTS)))

# Map a test name ($1) back to its source DSP file using the TEST_SPECS list
define file_for
$(firstword $(subst :, ,$(filter %:$1,$(TEST_SPECS))))
endef

# Default goals remain documented via help; reference/check now depend on per-test files
reference: $(REFS) $(REFERENCE_DIR)/PARAMS ## Build reference outputs for all *_test specifications (records PARAMS)

# Record the parameters the references were generated with, so a regeneration
# or a comparison under different settings is detectable.
$(REFERENCE_DIR)/PARAMS: | $(REFERENCE_DIR)
	@{ \
		echo "FAUST_VERSION=$$($(FAUST) --version 2>/dev/null | head -1)"; \
		echo "FAUST_OPT=$(FAUST_OPT)"; \
		echo "NUM_SAMPLES=$(NUM_SAMPLES)"; \
		echo "SAMPLE_RATE=$(SAMPLE_RATE)"; \
		echo "FLOAT_TOL=$(FLOAT_TOL)"; \
	} > $@

# Build a single reference from its test name (stem: %)
$(REFERENCE_DIR)/%.ref: | $(REFERENCE_DIR) $(BUILD_DIR)
	@set -e; \
	file='$(call file_for,$*)'; \
	if [ -z "$$file" ]; then echo "No source file found for test '$*'"; exit 1; fi; \
	printf '[reference] %s from %s\n' '$*' "$$file"; \
	$(FAUST) $(FAUST_OPT) -a $(ARCH) -pn $* $$file -o $(BUILD_DIR)/$*.cpp; \
	if ! $(CXX) $(CXXFLAGS) $(BUILD_DIR)/$*.cpp -o $(BUILD_DIR)/$*; \
	then \
		echo "[fail] build failed for $*"; \
		exit 1; \
	fi; \
	$(BUILD_DIR)/$* $(NUM_SAMPLES) $(SAMPLE_RATE) > $@

check: $(OUTS) ## Run tests and diff against references (fails on first divergence; use -k to run all)

# Build a single output and immediately compare with its reference
$(OUTPUT_DIR)/%.out: | $(OUTPUT_DIR) $(BUILD_DIR)
	@set -e; \
	file='$(call file_for,$*)'; \
	if [ -z "$$file" ]; then echo "No source file found for test '$*'"; exit 1; fi; \
	printf '[check] %s from %s\n' '$*' "$$file"; \
	$(FAUST) $(FAUST_OPT) -a $(ARCH) -pn $* $$file -o $(BUILD_DIR)/$*.cpp; \
	if ! $(CXX) $(CXXFLAGS) $(BUILD_DIR)/$*.cpp -o $(BUILD_DIR)/$*; \
		then \
			echo "[fail] build failed for $*"; \
			exit 1; \
		fi; \
	$(BUILD_DIR)/$* $(NUM_SAMPLES) $(SAMPLE_RATE) > $@; \
	if [ ! -f $(REFERENCE_DIR)/$*.ref ]; then \
		echo "Missing reference: $(REFERENCE_DIR)/$*.ref"; \
		exit 1; \
	fi; \
	if ! $(FLOATDIFF) $(REFERENCE_DIR)/$*.ref $@ $(FLOAT_TOL); then \
		echo "[fail] output for $* differs from reference"; \
		exit 1; \
	fi

checkdoc: ## Fail on any doc/license regression (baseline: tests/doc-baseline.json)
	@$(PYTHON) scripts/checkdoc.py

plots: ## Regenerate the SVG plots, then rebuild the doc pages that embed them
	@$(PYTHON) scripts/plot_lib.py
	@$(PYTHON) scripts/plot_families.py
	$(MAKE) -C doc clean
	$(MAKE) -C doc build

bench: ## Run faustbench-llvm on all test specs and capture memory/CPU stats
	@set -e; \
	rm -f $(BENCH_LOG); \
	mkdir -p $(dir $(BENCH_LOG)); \
	for spec in $(TEST_SPECS); do \
		file=$${spec%%:*}; \
		test=$${spec##*:}; \
		printf '[bench] %s from %s\n' "$$test" "$$file"; \
		tmp="$$(mktemp)"; \
		if $(FAUSTBENCH) -single -pn "$$test" "$$file" > "$$tmp" 2>&1; then \
			line="$$(grep -m1 'MBytes/sec' "$$tmp" || true)"; \
			if [ -n "$$line" ]; then \
				mb="$$(printf '%s\n' "$$line" | sed -nE 's/.*: ([0-9.]+) MBytes\/sec.*/\1/p')"; \
				sd="$$(printf '%s\n' "$$line" | sed -nE 's/.*SD[[:space:]]*:[[:space:]]*([0-9.]+%).*/\1/p')"; \
				if [ -n "$$mb" ] && [ -n "$$sd" ]; then \
					printf '%s: %s : %s %s\n' "$$test" "$$file" "$$mb" "$$sd" >> $(BENCH_LOG); \
				else \
					printf '[warn] could not parse bench output for %s\n' "$$test" >&2; \
				fi; \
			else \
				printf '[warn] missing MBytes/sec output for %s\n' "$$test" >&2; \
			fi; \
		else \
			printf '[skip] bench failed for %s\n' "$$test" >&2; \
		fi; \
		rm -f "$$tmp"; \
	done; \
	if [ -f $(BENCH_LOG) ]; then \
		printf '[bench] results saved to %s\n' $(BENCH_LOG); \
	else \
		printf '[bench] no results generated\n' >&2; \
	fi

# The generator predicts each verdict and pins it as a `by decide` theorem, so a
# regenerated file always type-checks; drift is caught by diffing against the
# committed reference, exactly as `check` diffs numerical outputs. A compiler or
# prelude change that flips a verdict therefore fails this target loudly.
certify: ## Regenerate the Lean certification theorems, kernel-check them, and fail on drift
	@set -e; \
	mkdir -p $(BUILD_DIR); \
	printf '[certify] checking prelude and specs in %s\n' '$(LEAN_SPEC_DIR)'; \
	$(LEAN) $(LEAN_TEMPLATE); \
	$(LEAN) $(LEAN_SPEC_DIR)/tf2s-stability-formal-spec.lean; \
	printf '[certify] generating %s from %d dsp files\n' '$(BUILD_DIR)/certified.lean' '$(words $(LEAN_CERT_DSP))'; \
	FAUST_RS=$(FAUST_RS) FAUST_LIBS=$(CURDIR) $(PYTHON) $(SIG2LEAN) $(LEAN_TEMPLATE) $(BUILD_DIR)/certified.lean $(LEAN_CERT_DSP); \
	$(LEAN) $(BUILD_DIR)/certified.lean; \
	if ! diff -u $(LEAN_CERTIFIED) $(BUILD_DIR)/certified.lean; then \
		echo "[fail] certification drifted from $(LEAN_CERTIFIED) — review the diff above, then run 'make certify-reference'"; \
		exit 1; \
	fi; \
	printf '[certify] all theorems check; verdicts match %s\n' '$(LEAN_CERTIFIED)'

certify-reference: ## Regenerate tests/lean/certified.lean in place and kernel-check it
	@set -e; \
	FAUST_RS=$(FAUST_RS) FAUST_LIBS=$(CURDIR) $(PYTHON) $(SIG2LEAN) $(LEAN_TEMPLATE) $(LEAN_CERTIFIED) $(LEAN_CERT_DSP); \
	$(LEAN) $(LEAN_CERTIFIED); \
	printf '[certify-reference] wrote and checked %s\n' '$(LEAN_CERTIFIED)'

doc-index: ## Build the Faust library documentation JSON index
	@set -e; \
	printf '[doc-index] writing %s\n' '$(DOC_INDEX_OUTPUT)'; \
	$(PYTHON) $(DOC_INDEX_SCRIPT) --repo-root . --output $(DOC_INDEX_OUTPUT) --pretty

doc-index-split: ## Build a compact JSON index and one detailed JSON per library module
	@set -e; \
	printf '[doc-index-split] writing %s and %s\n' '$(DOC_INDEX_OUTPUT)' '$(DOC_INDEX_SPLIT_DIR)'; \
	$(PYTHON) $(DOC_INDEX_SCRIPT) --repo-root . --output $(DOC_INDEX_OUTPUT) --split-output-dir $(DOC_INDEX_SPLIT_DIR) --pretty

doc-index-commercial: ## Build a JSON index filtered to commercially compatible symbols
	@set -e; \
	printf '[doc-index-commercial] writing %s and %s\n' '$(DOC_INDEX_OUTPUT)' '$(DOC_INDEX_SPLIT_DIR)'; \
	$(PYTHON) $(DOC_INDEX_SCRIPT) --repo-root . --output $(DOC_INDEX_OUTPUT) --split-output-dir $(DOC_INDEX_SPLIT_DIR) --license-policy commercial-compatible $(if $(DOC_INDEX_LICENSE_ALLOWLIST_FILE),--license-allowlist-file $(DOC_INDEX_LICENSE_ALLOWLIST_FILE),) $(if $(DOC_INDEX_LICENSE_DENYLIST_FILE),--license-denylist-file $(DOC_INDEX_LICENSE_DENYLIST_FILE),) --pretty

build: ## Build the documentation
	$(MAKE) -C doc build
 
serve: ## Serve the documentation
	$(MAKE) -C doc serve
	
pdf: ## Create the PDF documentation
	$(MAKE) -C doc pdf

clean: ## Remove build artefacts and generated outputs (keeps references)
	rm -rf $(BUILD_DIR) $(OUTPUT_DIR) $(DOC_INDEX_OUTPUT) $(DOC_INDEX_SPLIT_DIR)

distclean: clean ## Additionally remove the stored reference outputs
	rm -rf $(REFERENCE_DIR)

$(BUILD_DIR) $(REFERENCE_DIR) $(OUTPUT_DIR):
	@mkdir -p $@
