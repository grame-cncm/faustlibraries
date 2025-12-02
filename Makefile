# Minimal test harness for Faust DSP tests and to build and test the documentation.
#
# `make reference`  - compile each *_test entry and store terminal output under tests/reference/.
# `make check`      - recompile, run each test, and diff against the stored reference output.
# `make clean`      - remove build artefacts and generated outputs.
# `make bench`      - use faustbench-llvm to benchmark all test specs.
# `make build`      - build the documentation.
# `make serve`      - serve the documentation.

FAUST ?= faust
FAUSTBENCH ?= faustbench-llvm
CXX ?= g++
CXXFLAGS ?= -O2 -std=c++17
NUM_SAMPLES ?= 1000
SAMPLE_RATE ?= 48000

FLOAT_TOL ?= 1e-5
FLOATDIFF ?= ./scripts/floatdiff.py

ARCH := arch/print_arch.cpp
BUILD_DIR := tests/build
REFERENCE_DIR := tests/reference
OUTPUT_DIR := tests/output
DSP_TEST_DIR := tests
DSP_FILES := $(shell find $(DSP_TEST_DIR) -maxdepth 1 -name '*.dsp' | sort)
BENCH_LOG := tests/bench.log

.PHONY: reference check clean help bench

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
reference: $(REFS) ## Build reference outputs for all *_test specifications

# Build a single reference from its test name (stem: %)
$(REFERENCE_DIR)/%.ref: | $(REFERENCE_DIR) $(BUILD_DIR)
	@set -e; \
	file='$(call file_for,$*)'; \
	if [ -z "$$file" ]; then echo "No source file found for test '$*'"; exit 1; fi; \
	printf '[reference] %s from %s\n' '$*' "$$file"; \
	$(FAUST) -a $(ARCH) -pn $* $$file -o $(BUILD_DIR)/$*.cpp; \
	if ! 	$(CXX) $(CXXFLAGS) $(BUILD_DIR)/$*.cpp -o $(BUILD_DIR)/$*; \
	then \
		echo "[skip] build failed for $*"; \
		exit 0; \
	fi; \
	$(BUILD_DIR)/$* $(NUM_SAMPLES) $(SAMPLE_RATE) > $@

check: $(OUTS) ## Run tests and diff against reference outputs

# Build a single output and immediately compare with its reference
$(OUTPUT_DIR)/%.out: | $(OUTPUT_DIR) $(BUILD_DIR)
	@set -e; \
	file='$(call file_for,$*)'; \
	if [ -z "$$file" ]; then echo "No source file found for test '$*'"; exit 1; fi; \
	printf '[check] %s from %s\n' '$*' "$$file"; \
	$(FAUST) -a $(ARCH) -pn $* $$file -o $(BUILD_DIR)/$*.cpp; \
	if ! $(CXX) $(CXXFLAGS) $(BUILD_DIR)/$*.cpp -o $(BUILD_DIR)/$*; \
		then \
			echo "[skip] build failed for $*"; \
			exit 0; \
		fi; \
	$(BUILD_DIR)/$* $(NUM_SAMPLES) $(SAMPLE_RATE) > $@; \
	if [ ! -f $(REFERENCE_DIR)/$*.ref ]; then \
		echo "Missing reference: $(REFERENCE_DIR)/$*.ref"; \
		exit 1; \
	fi; \
	if ! $(FLOATDIFF) $(REFERENCE_DIR)/$*.ref $@ $(FLOAT_TOL); then \
		echo "[fail] output for $* differs from reference"; \
	fi

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

build: ## Build the documentation
	$(MAKE) -C doc build
 
serve: ## Serve the documentation
	$(MAKE) -C doc serve
	
pdf: ## Create the PDF documentation
	$(MAKE) -C doc pdf

clean: ## Remove build artefacts and generated outputs
	rm -rf $(BUILD_DIR) $(REFERENCE_DIR) $(OUTPUT_DIR)

$(BUILD_DIR) $(REFERENCE_DIR) $(OUTPUT_DIR):
	@mkdir -p $@
