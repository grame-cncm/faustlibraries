# Minimal test harness for Faust DSP tests and to build and test the documentation.
#
# `make reference`  - compile each *_test entry and store terminal output under tests/reference/.
# `make check`      - recompile, run each test whose output is stale, and diff against the
#                     stored reference output. An output is stale when a file the test
#                     loads, its reference, the harness or the build settings changed.
# `make check-vec`  - run the regression tests with Faust's vectorized code generator.
# `make check-precision` - render every test in -single and -double at 44.1 to 192 kHz
#                     and fail on non-finite output or a float/double level gap
#                     beyond tests/precision-baseline.json (no reference needed).
# `make check-precision-matrix` - the same with several compilations in turn: C++ -O2
#                     and -O3 -ffast-math, Faust -vec and -lang ocpp.
# `make check-sanitize` - run every test under the address and undefined-behavior
#                     sanitizers, without Faust's table guards (-ct 0).
# `make check-cpu`  - measure the CPU cost of the tests (ns/frame, % of a core), and with
#                     CPU_ARGS="--base REV" the ratio new / base against the libraries of REV.
# `make check-cpu-matrix` - the same with C++ -O3 -ffast-math, -O3, and Faust -vec in turn.
# `make verify-matched` - prove the rewrites of vaeffects.lib's matched filters and check
#                     their coefficients against Vicanek's formulas at 60 digits.
# `make check-doc`   - verify documentation coverage, standardFunctions.md and licenses,
#                     and compile the Usage sections of the libraries changed since HEAD.
# `make check-weak` - flag the tests whose reference validates little (silent, constant,
#                     settled early, inputs unused) against tests/weak-baseline.json.
# `make check-reinit` - render every test after a second init() (the same rate, and a
#                     rate change both ways): it must equal a fresh instance, against
#                     tests/reinit-baseline.json.
# `make check-jumps` - render every test with its sliders jumping between their bounds
#                     during the run: non-finite, blow-up, against tests/jumps-baseline.json.
# `make check-sr`   - render every test at 44.1, 96 and 192 kHz, the noises made the same
#                     signal at every rate: spectrum shape, level, onset and decay times,
#                     against tests/sr-baseline.json.
# `make check-backend-outputs` - compare the outputs of WebAssembly and Cmajor (Julia with
#                     BACKEND_OUTPUTS_ARGS="--lang wasm,cmajor,julia --run-julia") with the
#                     C++ build in -single,
#                     against tests/backend-output-baseline.json.
# `make check-mutation` - inject small faults in a copy of the libraries (a sample, fixed seed)
#                     and report which ones the tests detect: a measure, no baseline.
# `make check-usage` - compile the #### Usage section of every documented symbol
#                     (arity, parameters) against tests/usage-baseline.json.
# `make check-filter-claims` - measure the filters of filters.lib and vaeffects.lib with
#                     faustprobe (faust-rs): SR independence, -3 dB points, peaks...,
#                     against tests/filter-claims-baseline.json.
# `make check-tuning` - measure the pitch of the physmodels.lib instruments with
#                     faustprobe (faust-rs) at 44.1 to 192 kHz, against
#                     tests/tuning-baseline.json.
# `make check-osc-claims` - measure the oscillators of oscillators.lib and the
#                     antialiased functions of aanl.lib with faustprobe: pitch and
#                     waveform at 44.1 to 192 kHz, aliasing against the naive waveform
#                     and between orders, float noise, against tests/osc-claims-baseline.json.
# `make clean`      - remove build artefacts and generated outputs (references are kept).
# `make distclean`  - additionally remove the stored reference outputs.
# `make bench`      - use faustbench-llvm to benchmark all test specs.
# `make certify`    - regenerate the Lean certification theorems into tests/build/,
#                     kernel-check them, and fail if any verdict drifted from the
#                     committed tests/lean/certified.lean.
# `make check-certify` - the same regeneration, failing on a verdict only, not on a
#                     term; check-doc runs it when what it reads changed.
# `make certify-reference` - regenerate and re-check tests/lean/certified.lean in place.
# `make build`      - build the documentation.
# `make serve`      - serve the documentation.
# `make doc-index`  - build the Faust library documentation JSON index, its io counts
#                     computed by faust (DOC_INDEX_IO= to guess them without faust).
# `make doc-index-split` - build a compact index plus one detailed JSON per module.
# `make doc-index-commercial` - build a JSON index filtered to commercially compatible symbols.

FAUST ?= faust
FAUST_OPT ?= -double -t 0
# faust finds the libraries of the root in the current directory, not those of dx7/,
# which tests/dx7_tests.dsp loads by their installed names (library("operator.lib")):
# without -I dx7 it would compile the copies installed with faust, not this checkout's.
FAUST_INCLUDES := -I dx7
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
# io counts computed by faust (empty: guessed from the Usage text, no faust needed)
DOC_INDEX_IO ?= --measure-io
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
PRECISION_BUILD_DIR := tests/build-precision
# Extra arguments for check-precision, e.g. PRECISION_ARGS="tests/vaeffects_tests.dsp"
# or PRECISION_ARGS="-k klonCentaur_test" (a regex on test names, see scripts/check_precision.py -h).
PRECISION_ARGS ?=
CPU_BUILD_DIR := tests/build-cpu
# Extra arguments for check-cpu, e.g. CPU_ARGS="--base origin/master tests/filters_resonator_tests.dsp"
# or CPU_ARGS="--base origin/master -k resonlp" (see scripts/check_cpu.py -h).
CPU_ARGS ?=
# Arguments for verify-matched, e.g. VERIFY_ARGS="--old" or VERIFY_ARGS="--quick"
# (see scripts/verify_matched2.py -h).
VERIFY_ARGS ?=
DSP_TEST_DIR := tests
DSP_FILES := $(shell find $(DSP_TEST_DIR) -maxdepth 1 -name '*.dsp' | sort)
BENCH_LOG := tests/bench.log

.PHONY: FORCE reference check check-mutation check-sanitize check-extremes check-long check-weak check-reinit check-jumps check-sr check-backend-outputs check-vec check-precision check-precision-matrix check-backends check-cpu check-cpu-matrix verify-matched check-doc checkdoc check-usage check-filter-claims check-tuning check-osc-claims check-plots plots clean distclean help bench certify check-certify certify-reference certify-deep doc-index doc-index-split doc-index-commercial

# Remove a target whose recipe failed, so a failed test is re-run next time
# instead of being considered up to date.
.DELETE_ON_ERROR:

# The prerequisites of the test outputs name their stem ($$*).
.SECONDEXPANSION:

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
# check-sanitize: every test built with the address and undefined-behavior
# sanitizers, in each precision, rendered one second at each rate. Faust's
# table guards are off (-ct 0): a library read that only stays in range
# because the compiler clamps the index is reported too.
SANITIZE_PRECISIONS ?= single double
SANITIZE_RATES ?= 44100 192000
SANITIZE_FAUST_OPT ?= -t 0 -ct 0
SANITIZE_CXXFLAGS ?= -O1 -g -std=c++17 -fsanitize=address,undefined -fno-sanitize-recover=undefined -fno-omit-frame-pointer
SANITIZE_BUILD_DIR := tests/build-sanitize
SANITIZE_OUTPUT_DIR := tests/output-sanitize
SANITIZE_OUTS := $(addprefix $(SANITIZE_OUTPUT_DIR)/,$(addsuffix .ok,$(TESTS)))

# What makes a test output stale, so that `make check` never passes on the output
# of older code. Each recipe keeps, in a .d file beside the output, the files
# `faust -flist` says the test loaded: its .dsp and the libraries it uses, not the
# ones it only declares, so that a change of phaflangers.lib re-runs the tests of
# phaflangers.lib and not all of them. An output without its .d file (older than
# this rule, or from an interrupted run) is stale too. The rule of the .d files has
# no recipe on purpose, and a .d file gives each file an empty rule of its own, so
# that a library that disappears does not stop make.
CHECK_DEPS := $(OUTS:.out=.d)
SANITIZE_DEPS := $(SANITIZE_OUTS:.ok=.d)
$(CHECK_DEPS) $(SANITIZE_DEPS):
include $(wildcard $(CHECK_DEPS) $(SANITIZE_DEPS))

# $(call write_deps,FLIST,TARGET,DEPFILE): the .d file of TARGET from the output of
# faust -flist, in paths relative to the checkout.
define write_deps
awk -v target='$(2)' -v root='$(CURDIR)/' '/^\// { \
	if (index($$0, root) == 1) $$0 = substr($$0, length(root) + 1); \
	gsub(/ /, "\\ "); print target ": " $$0; print $$0 ":" }' $(1) > $(3)
endef

# The build settings of the outputs: a change of options, of tolerance or of compiler
# re-runs them all. A .params file is only rewritten when it changes, so that its date
# says when the settings last changed; check-vec, for one, must not leave its outputs
# to the next plain `make check`.
define update_params
if cmp -s $@.tmp $@; then rm -f $@.tmp; else mv $@.tmp $@; fi
endef
CHECK_PARAMS := $(OUTPUT_DIR)/.params
SANITIZE_PARAMS := $(SANITIZE_OUTPUT_DIR)/.params

# An output whose reference is missing can be up to date. It must still fail, with the
# message of its recipe: `make check` would otherwise pass without comparing anything.
# The .ref files are not prerequisites to build: a missing one would be generated by
# the code under test, and the test would compare that code with itself.
$(patsubst $(REFERENCE_DIR)/%.ref,$(OUTPUT_DIR)/%.out,$(filter-out $(wildcard $(REFS)),$(REFS))): FORCE

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
	$(FAUST) $(FAUST_OPT) $(FAUST_INCLUDES) -a $(ARCH) -pn $* $$file -o $(BUILD_DIR)/$*.cpp; \
	if ! $(CXX) $(CXXFLAGS) $(BUILD_DIR)/$*.cpp -o $(BUILD_DIR)/$*; \
	then \
		echo "[fail] build failed for $*"; \
		exit 1; \
	fi; \
	$(BUILD_DIR)/$* $(NUM_SAMPLES) $(SAMPLE_RATE) > $@

check: $(OUTS) ## Run tests and diff against references (fails on first divergence; use -k to run all)

check-sanitize: $(SANITIZE_OUTS) ## Run every test under ASan and UBSan, -single and -double, at 44.1 and 192 kHz, without Faust's table guards (-k to run all)

check-vec: ## Run all regression tests with Faust's vectorized code generator
	@rm -rf $(BUILD_DIR) $(OUTPUT_DIR)
	$(MAKE) check FAUST_OPT="$(FAUST_OPT) -vec"

check-precision: ## Check every test in float and double at 44.1-192 kHz against tests/precision-baseline.json
	@FAUST="$(FAUST)" CXX="$(CXX)" $(PYTHON) scripts/check_precision.py --build-dir $(PRECISION_BUILD_DIR) $(PRECISION_ARGS)

check-extremes: ## Render every test with its sliders at their extremes, all and one by one (baseline: tests/extremes-baseline.json); EXTREMES_ARGS="tests/xx_tests.dsp"
	@FAUST="$(FAUST)" CXX="$(CXX)" $(PYTHON) scripts/check_extremes.py --build-dir $(PRECISION_BUILD_DIR) $(EXTREMES_ARGS)

check-long: ## Render every test for 2 min at 192 kHz in -single and -double: non-finite, growth, subnormals, single/double drift (baseline: tests/long-baseline.json); LONG_ARGS="tests/xx_tests.dsp"
	@FAUST="$(FAUST)" CXX="$(CXX)" $(PYTHON) scripts/check_long.py $(LONG_ARGS)

check-weak: ## Flag the tests whose reference validates little: silent, below the tolerance, constant, settled, inputs unused (baseline: tests/weak-baseline.json); WEAK_ARGS="tests/xx_tests.dsp"
	@FAUST="$(FAUST)" $(PYTHON) scripts/check_weak.py --tol $(FLOAT_TOL) $(WEAK_ARGS)

check-mutation: ## Inject small faults in the libraries (a sample, fixed seed) and report which ones the tests detect; MUTATION_ARGS="--lib filters.lib -n 50 --list-survivors"
	@FAUST="$(FAUST)" CXX="$(CXX)" FLOAT_TOL="$(FLOAT_TOL)" $(PYTHON) scripts/check_mutation.py $(MUTATION_ARGS)

check-reinit: ## Render every test after a second init() at the same rate and after a rate change: it must equal a fresh instance (baseline: tests/reinit-baseline.json); REINIT_ARGS="tests/xx_tests.dsp"
	@FAUST="$(FAUST)" CXX="$(CXX)" $(PYTHON) scripts/check_reinit.py --build-dir $(PRECISION_BUILD_DIR) $(REINIT_ARGS)

check-jumps: ## Render every test with its sliders jumping between their bounds, all and one by one (baseline: tests/jumps-baseline.json); JUMPS_ARGS="tests/xx_tests.dsp"
	@FAUST="$(FAUST)" CXX="$(CXX)" $(PYTHON) scripts/check_jumps.py --build-dir $(PRECISION_BUILD_DIR) $(JUMPS_ARGS)

check-sr: doc-index-split ## Render every test at 44.1, 96 and 192 kHz with rate-independent noises: spectrum shape, level, onset and decay must not move (baseline: tests/sr-baseline.json); SR_ARGS="tests/xx_tests.dsp"
	@FAUST="$(FAUST)" CXX="$(CXX)" $(PYTHON) scripts/check_sr.py --export $(DOC_INDEX_SPLIT_DIR) $(SR_ARGS)

check-precision-matrix: ## check-precision with C++ -O2 and -O3 -ffast-math, Faust -vec and -lang ocpp in turn
	@FAUST="$(FAUST)" CXX="$(CXX)" $(PYTHON) scripts/check_precision.py --build-dir $(PRECISION_BUILD_DIR) --matrix all $(PRECISION_ARGS)

check-backends: ## Compile every test for WebAssembly (modules validated and run with node), Cmajor (rendered by cmaj), Julia, Codebox, C#, Java (baseline: tests/backend-baseline.json); BACKENDS_ARGS="--lang wasm"
	@FAUST="$(FAUST)" $(PYTHON) scripts/check_backends.py $(BACKENDS_ARGS)

check-backend-outputs: ## Compare the outputs of WebAssembly and Cmajor (Julia with BACKEND_OUTPUTS_ARGS="--lang wasm,cmajor,julia --run-julia") with the C++ build in -single (baseline: tests/backend-output-baseline.json)
	@FAUST="$(FAUST)" CXX="$(CXX)" $(PYTHON) scripts/check_backends.py --compare --lang wasm,cmajor $(BACKEND_OUTPUTS_ARGS)

check-cpu: ## Measure the CPU cost of the tests; CPU_ARGS="--base REV" adds the ratio new / base
	@FAUST="$(FAUST)" CXX="$(CXX)" $(PYTHON) scripts/check_cpu.py --build-dir $(CPU_BUILD_DIR) $(CPU_ARGS)

check-cpu-matrix: ## check-cpu with C++ -O3 -ffast-math, -O3, and Faust -vec in turn
	@FAUST="$(FAUST)" CXX="$(CXX)" $(PYTHON) scripts/check_cpu.py --build-dir $(CPU_BUILD_DIR) --matrix all $(CPU_ARGS)

verify-matched: ## Prove the rewrites of vaeffects.lib's matched filters, check their coefficients at 60 digits
	@FAUST="$(FAUST)" CXX="$(CXX)" $(PYTHON) scripts/verify_matched2.py $(VERIFY_ARGS)

$(CHECK_PARAMS): FORCE | $(OUTPUT_DIR)
	@{ $(FAUST) --version | head -2; $(CXX) --version | head -1; \
		echo 'FAUST_OPT=$(FAUST_OPT) $(FAUST_INCLUDES)'; echo 'CXXFLAGS=$(CXXFLAGS)'; \
		echo 'NUM_SAMPLES=$(NUM_SAMPLES)'; echo 'SAMPLE_RATE=$(SAMPLE_RATE)'; \
		echo 'FLOAT_TOL=$(FLOAT_TOL)'; } > $@.tmp; \
	$(update_params)

# Build a single output and immediately compare with its reference
$(OUTPUT_DIR)/%.out: $$(wildcard $(REFERENCE_DIR)/$$*.ref) $(OUTPUT_DIR)/%.d $(ARCH) $(CHECK_PARAMS) | $(OUTPUT_DIR) $(BUILD_DIR)
	@set -e; \
	file='$(call file_for,$*)'; \
	if [ -z "$$file" ]; then echo "No source file found for test '$*'"; exit 1; fi; \
	if [ ! -f $(REFERENCE_DIR)/$*.ref ]; then \
		echo "Missing reference: $(REFERENCE_DIR)/$*.ref"; \
		exit 1; \
	fi; \
	printf '[check] %s from %s\n' '$*' "$$file"; \
	$(FAUST) $(FAUST_OPT) $(FAUST_INCLUDES) -flist -a $(ARCH) -pn $* $$file -o $(BUILD_DIR)/$*.cpp > $(BUILD_DIR)/$*.flist; \
	$(call write_deps,$(BUILD_DIR)/$*.flist,$@,$(OUTPUT_DIR)/$*.d); \
	if ! $(CXX) $(CXXFLAGS) $(BUILD_DIR)/$*.cpp -o $(BUILD_DIR)/$*; \
		then \
			echo "[fail] build failed for $*"; \
			exit 1; \
		fi; \
	$(BUILD_DIR)/$* $(NUM_SAMPLES) $(SAMPLE_RATE) > $@; \
	if ! $(FLOATDIFF) $(REFERENCE_DIR)/$*.ref $@ $(FLOAT_TOL); then \
		echo "[fail] output for $* differs from reference"; \
		exit 1; \
	fi

# A test under the sanitizers: an out-of-bounds read of a table or a delay
# line produces plausible numbers and passes every other check. UBSan's
# array-bounds check sees an index past a member array of the DSP class,
# where ASan, which only guards the whole object, does not. No reference:
# the run fails on the first report.
$(SANITIZE_PARAMS): FORCE | $(SANITIZE_OUTPUT_DIR)
	@{ $(FAUST) --version | head -2; $(CXX) --version | head -1; \
		echo 'SANITIZE_FAUST_OPT=$(SANITIZE_FAUST_OPT) $(FAUST_INCLUDES)'; \
		echo 'SANITIZE_CXXFLAGS=$(SANITIZE_CXXFLAGS)'; \
		echo 'SANITIZE_PRECISIONS=$(SANITIZE_PRECISIONS)'; \
		echo 'SANITIZE_RATES=$(SANITIZE_RATES)'; } > $@.tmp; \
	$(update_params)

$(SANITIZE_OUTPUT_DIR)/%.ok: $(SANITIZE_OUTPUT_DIR)/%.d $(ARCH) $(SANITIZE_PARAMS) | $(SANITIZE_OUTPUT_DIR) $(SANITIZE_BUILD_DIR)
	@set -e; \
	file='$(call file_for,$*)'; \
	if [ -z "$$file" ]; then echo "No source file found for test '$*'"; exit 1; fi; \
	printf '[sanitize] %s from %s\n' '$*' "$$file"; \
	for p in $(SANITIZE_PRECISIONS); do \
		exe=$(SANITIZE_BUILD_DIR)/$*.$$p; \
		if ! $(FAUST) -$$p $(SANITIZE_FAUST_OPT) $(FAUST_INCLUDES) -flist -a $(ARCH) -pn $* $$file -o $$exe.cpp > $$exe.flist; then \
			echo "[fail] faust failed for $* (-$$p)"; \
			exit 1; \
		fi; \
		$(call write_deps,$$exe.flist,$@,$(SANITIZE_OUTPUT_DIR)/$*.d); \
		if ! $(CXX) $(SANITIZE_CXXFLAGS) $$exe.cpp -o $$exe; then \
			echo "[fail] sanitized build failed for $* (-$$p)"; \
			exit 1; \
		fi; \
		for sr in $(SANITIZE_RATES); do \
			log=$(SANITIZE_OUTPUT_DIR)/$*.$$p.$$sr.log; \
			if ! ASAN_OPTIONS=detect_leaks=0 UBSAN_OPTIONS=print_stacktrace=1 $$exe $$sr $$sr > /dev/null 2> $$log \
				|| grep -q 'runtime error\|Sanitizer' $$log; then \
				echo "[fail] $* (-$$p, $$sr Hz): $$(grep -m1 'runtime error\|ERROR' $$log || echo 'exit status')"; \
				exit 1; \
			fi; \
			rm -f $$log; \
		done; \
	done; \
	touch $@

check-doc: ## Fail on any doc/license regression (baseline: tests/doc-baseline.json)
	@$(PYTHON) scripts/check_doc.py

# former name, kept so that existing habits and scripts keep working
checkdoc: check-doc

check-usage: ## Compile every #### Usage section (baseline: tests/usage-baseline.json); USAGE_ARGS="--lib xx.lib"
	@$(PYTHON) scripts/check_usage.py $(USAGE_ARGS)

check-filter-claims: doc-index-split ## Measure the filters of filters.lib and vaeffects.lib against their doc with faustprobe (baseline: tests/filter-claims-baseline.json); FILTER_CLAIMS_ARGS="--only fi.lowpass"
	@$(PYTHON) scripts/check_filter_claims.py --export $(DOC_INDEX_SPLIT_DIR) $(FILTER_CLAIMS_ARGS)

check-tuning: ## Measure the pitch of the physmodels.lib models and MIDI instruments at 44.1-192 kHz with faustprobe (baseline: tests/tuning-baseline.json); TUNING_ARGS="--only pm.ks"
	@$(PYTHON) scripts/check_tuning.py $(TUNING_ARGS)

check-osc-claims: doc-index-split ## Measure the oscillators of oscillators.lib and the antialiased functions of aanl.lib with faustprobe: pitch, SR independence, aliasing, float noise (baseline: tests/osc-claims-baseline.json); OSC_CLAIMS_ARGS="--only os.sawN"
	@$(PYTHON) scripts/check_osc_claims.py --export $(DOC_INDEX_SPLIT_DIR) $(OSC_CLAIMS_ARGS)

check-plots: ## Regenerate every figure aside and fail on a stale one or a failed assertion (make plots refreshes them)
	@$(PYTHON) scripts/check_plots.py $(PLOTS_ARGS)

plots: ## Rewrite the figures whose rendering changed, then rebuild the doc pages that embed them; PLOTS_ARGS="--only fi_lowpass"
	@$(PYTHON) scripts/check_plots.py --update $(PLOTS_ARGS)
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

check-certify: ## Regenerate the Lean theorems and fail on a moved verdict, not on a term (make check-doc runs it with --changed)
	@FAUST_RS=$(FAUST_RS) LEAN=$(LEAN) $(PYTHON) scripts/check_certify.py

certify-reference: ## Regenerate tests/lean/certified.lean in place and kernel-check it
	@set -e; \
	FAUST_RS=$(FAUST_RS) FAUST_LIBS=$(CURDIR) $(PYTHON) $(SIG2LEAN) $(LEAN_TEMPLATE) $(LEAN_CERTIFIED) $(LEAN_CERT_DSP); \
	$(LEAN) $(LEAN_CERTIFIED); \
	printf '[certify-reference] wrote and checked %s\n' '$(LEAN_CERTIFIED)'

# Optional and heavy: builds the mathlib project that discharges the standing
# obligations of the Std-only specifications (Jury <=> poles in the unit disc,
# tan positivity). First run downloads the mathlib build cache (several GB).
# Never required by `make certify`.
certify-deep: ## Build the optional mathlib proofs discharging the certify obligations
	@set -e; \
	cd $(LEAN_SPEC_DIR)/mathlib; \
	lake exe cache get; \
	lake build; \
	printf '[certify-deep] mathlib obligations check\n'

doc-index: ## Build the Faust library documentation JSON index
	@set -e; \
	printf '[doc-index] writing %s\n' '$(DOC_INDEX_OUTPUT)'; \
	$(PYTHON) $(DOC_INDEX_SCRIPT) --repo-root . --output $(DOC_INDEX_OUTPUT) $(DOC_INDEX_IO) --pretty

doc-index-split: ## Build a compact JSON index and one detailed JSON per library module
	@set -e; \
	printf '[doc-index-split] writing %s and %s\n' '$(DOC_INDEX_OUTPUT)' '$(DOC_INDEX_SPLIT_DIR)'; \
	$(PYTHON) $(DOC_INDEX_SCRIPT) --repo-root . --output $(DOC_INDEX_OUTPUT) --split-output-dir $(DOC_INDEX_SPLIT_DIR) $(DOC_INDEX_IO) --pretty

doc-index-commercial: ## Build a JSON index filtered to commercially compatible symbols
	@set -e; \
	printf '[doc-index-commercial] writing %s and %s\n' '$(DOC_INDEX_OUTPUT)' '$(DOC_INDEX_SPLIT_DIR)'; \
	$(PYTHON) $(DOC_INDEX_SCRIPT) --repo-root . --output $(DOC_INDEX_OUTPUT) --split-output-dir $(DOC_INDEX_SPLIT_DIR) --license-policy commercial-compatible $(if $(DOC_INDEX_LICENSE_ALLOWLIST_FILE),--license-allowlist-file $(DOC_INDEX_LICENSE_ALLOWLIST_FILE),) $(if $(DOC_INDEX_LICENSE_DENYLIST_FILE),--license-denylist-file $(DOC_INDEX_LICENSE_DENYLIST_FILE),) $(DOC_INDEX_IO) --pretty

build: ## Build the documentation
	$(MAKE) -C doc build
 
serve: ## Serve the documentation
	$(MAKE) -C doc serve
	
pdf: ## Create the PDF documentation
	$(MAKE) -C doc pdf

clean: ## Remove build artefacts and generated outputs (keeps references)
	rm -rf $(BUILD_DIR) tests/build-mutation $(PRECISION_BUILD_DIR) $(CPU_BUILD_DIR) $(OUTPUT_DIR) $(DOC_INDEX_OUTPUT) $(DOC_INDEX_SPLIT_DIR)

distclean: clean ## Additionally remove the stored reference outputs
	rm -rf $(REFERENCE_DIR)

$(BUILD_DIR) $(REFERENCE_DIR) $(OUTPUT_DIR) $(SANITIZE_BUILD_DIR) $(SANITIZE_OUTPUT_DIR):
	@mkdir -p $@
