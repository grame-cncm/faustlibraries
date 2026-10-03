# Contributing

In general, libraries are organised in a *stacked manner*: the base ones define functions or constants without any dependancies, and additional ones are gradually built on top of simpler ones, layer by layer. **Dependency loops must be avoided as much as possible**. The *resources* folder contains tools to build and visualise the libraries dependencies graphs.

If you wish to add a function to any of these libraries or if you plan to add a new library, make sure that you observe the following conventions:

## New Functions

* All functions must be preceded by a markdown documentation header respecting the following format (open the source code of any of the libraries for an example):

```
//-----------------`(pr).functionName`--------------------
// Description
//
// #### Usage
//
// ```
// Usage example
// ```
//
// Where:
//
// * `param1`: parameter 1 description
// * `param2`: parameter 2 description
//
// #### Example
//
// ```
// Additional example
// ```
//
// #### Test
// ```
// functionName_test = some_dsp_code;
// ```
//
// #### References
//
// * <https://some_url1>
// * <https://some_url2>
//-------------------------------------------------
```

* The `functionName` must be prefixed by the `libraryName` name prefix, like `(pr)` in the example.
* The environment system (e.g. `os.osc`) should be used when calling a function declared in another library (see the section on [Library Import](#library-import)).
* Try to reuse existing functions as much as possible.
* The `Usage` line must show the *input/output shape* (the number of inputs and outputs) of the function, like `gen: _` for a mono generator, `_ : filter : _` for a mono effect, etc. The `Where:` section then allows each parameter to be described individually, using the appropriate surrounding quotes.
* The `Example` line can be used to provide additional examples.
* The `Test` line should used to add a DSP program to test the function. The test name must be `functionName_test`. The actual code can be extracted and independantly tested using the `-pn` compiler option (to specify the name of the dsp entry-point instead of process). The test code must import all the needed libraries, like `an = library("analyzers.lib");` if a function from analyzers.lib is used in the test code. The `functionName_test` test should be added in the relevant file in the *tests* folder.
* The `References` line can be used to add links to references.
* Some functions use parameters that are [constant numerical expressions](https://faustdoc.grame.fr/manual/syntax/#constant-numerical-expressions). The convention is to label them in *capital letters* and document them preferably to be *constant numerical expressions* (or *known at compile time* in existing libraries).
* Functions with several parameters should better be written by putting the *more constant parameters* (like control, setup...) at the beginning of the parameter list, and *audio signals to be processed* at the end. This allows to do partial-application. So prefer the following  `clip(low, high, x) = min(max(x, low), high);` form where `clip(-1, 1)` partially applied version can be used later on in different contexts, better than `clip(x, low, high) = min(max(x, low), high);` version.
* Every time a new function is added, the documentation should be updated simply by running `make doclib`. <!-- TODO -->

### Layering UI-ready variants

Many functions benefit from two public faces so the same DSP can serve both low-level reuse and ready-to-tweak usage:

- *Core function*: exposes all parameters, no UI or side effects; best for reuse, composition, and testing.
- *UI wrapper*: fixes sensible defaults and exposes only runtime-tuned parameters as UI controls; leaves signals that must be provided externally as arguments.

Use the UI-free core for correctness and performance work; build the UI variant when you need something directly tweakable in examples or end-user contexts.

A generic core/UI pair could be:

```
// Core: parameters explicit, no UI
coreEffect(paramA, paramB, mix) =
  fooProcessing(mix, wet)
with {
  wet = *(paramA) : barProcessing(paramB); // barProcessing is your DSP
};

// UI wrapper: binds smoothed controls to the core
coreEffect_ui =
  coreEffect(paramA_ui, paramB_ui, mix_ui)
with {
  paramA_ui = hslider("Param A", 1.0, 0.0, 2.0, 0.01) : si.smoo;
  paramB_ui = hslider("Param B", 0.5, 0.0, 1.0, 0.01) : si.smoo;
  mix_ui    = hslider("Mix", 1.0, 0.0, 1.0, 0.01) : si.smoo;
};

process = coreEffect_ui; 
```

This keeps the core reusable (no UI dependencies) and the wrapper ready for immediate tweaking; `process` points to the UI layer for quick testing.

#### Instrument-specific three-layer pattern

Instrument models often add a third, ready-to-play layer. The clarinet model is a reference:

- `pm.clarinetModel(tubeLength, pressure, reedStiffness, bellOpening)`: core DSP with every parameter explicit and no UI.
- `pm.clarinetModel_ui(pressure)`: wraps the core and adds UI sliders for tube length, reed stiffness, bell opening, and output gain; keeps `pressure` as an argument.
- `pm.clarinet_ui_MIDI`: builds a playable instrument by pairing the core with a blower/envelope plus MIDI-mapped UI (pitch bend, sustain, vibrato, gain, etc.).

When adding similar models, start with the UI-free core, add a minimal UI wrapper, then optionally provide a controller-specific wrapper (MIDI or otherwise). Keep the core independent so it remains reusable.


### Variables and identifiers scoping

To avoid name clashes between libraries, keep identifiers as local as possible. Prefer defining intermediate constants and helpers inside `with { ... }` blocks or `environment { ... }` sections, and only expose the intended public entry points. This minimizes collisions when several libraries are imported together and keeps global namespace usage limited to documented, public-facing functions.

When a helper cannot live inside a `with`/`environment` block (for instance
because several public functions share it), prefix its name with an
underscore: `_helperName`. The underscore marks it as **internal**: it is not
part of the library's public API, needs no documentation block, is excluded
from the documentation coverage accounting (`scripts/audit2.py`,
`make checkdoc`), and may change or disappear without notice. Do not use
underscore-prefixed symbols from another library.

## New Libraries

* Any new "standard" library should be declared in `stdfaust.lib` with its own environment (2 letters - see `stdfaust.lib`) and in `all.lib`.
* Some of the new library functions should be demonstrated in [demos.lib](#demo-functions).
* Any new "standard" library must be added to `generateDoc`.
* Functions must be organized by sections.
* Any new library should at least `declare` a `name` and a `version`.
* Any new library has to use a prefix declared in the header section with the following kind of syntax: `Its official prefix is 'qu'` (look at an existing library to follow the exact syntax).
* Be sure to add the appropriate kind of `ma = library("maths.lib");` import library line, for each external library function used in the new library (for instance `ma.foo` that would be used somewhre in the code).
* The comment based markdown documentation of each library must respect the following format (open the source code of any of the libraries for an example):

```
//############### libraryName ##################
// Description
//
// * Section Name 1
// * Section Name 2
// * ...
//
// It should be used using the `[...]` environment:
//
// ```
// [...] = library("libraryName");
// process = [...].functionCall;
// ```
//
// Another option is to import `stdfaust.lib` which already contains the `[...]`
// environment:
//
// ```
// import("stdfaust.lib");
// process = [...].functionCall;
// ```
//##############################################

//================= Section Name ===============
// Description
//==============================================
```

## Coding Conventions

In order to have a uniformized library system, we established the following conventions (that hopefully will be followed by others when making modifications to them).

### Function Naming

The libraries historically mix `snake_case` and `camelCase` in roughly equal
proportion, sometimes inside a single file. Renaming existing public symbols
is not an option (it breaks user code), so the rule applies to *new* code:

* a new function added to an existing library follows the **dominant style of
  that library** (and of the section it lands in, when the library is mixed);
* a new library picks **one** style in its header section and uses it
  consistently;
* internal helpers follow the underscore convention described in
  [Variables and identifiers scoping](#variables-and-identifiers-scoping).

For terminology, use the terms of the digital signal processing field
(JOS proposal):

* `impulse`: ...,0,1,0,...
* `pulse`: ...,0,1,1,0,... or longer
* `impulse_train`
* `pulse_train`
* `gate` = pulse controlled externally (e.g., by NoteOn,NoteOff)
* `trigger` = impulse controlled externally (gate - gate' > 0) == gate rising edge

### Variable Argument List 

 Strictly speaking, there are no lists in Faust. But list operations [can be simulated](https://faustdoc.grame.fr/manual/faq/#pattern-matching-and-lists) (in part) using the parallel binary composition operation `,` and pattern matching.

Thus functions expecting a variable number of arguments can use this mechanism, like a `foo` function that would be used this way: `foo((a,b,c,d))`. See [fi.iir](https://faustlibraries.grame.fr/libs/filters/#fiiir) and [fi.fir](https://faustlibraries.grame.fr/libs/filters/#fifir) examples.

### Documentation

* All the functions that we want to be "public" are documented.
* We used the `faust2md` "standards" for each library: `//###` for main title (library name - equivalent to `#` in markdown), `//===` for section declarations (equivalent to `##` in markdown) and `//---` for function declarations (equivalent to `####` in markdown - see `basics.lib` for an example).
* Sections in function documentation should be declared as `####` markdown title.
* Each function documentation provides a "Usage" section (see `basics.lib`). 
* The full documentation can be generated using the doc/Makefile script. Use `make help` to see all possible commands. If you plan to create a pull-request, *do not commit the full generated code* but only the modified .lib files.
* Each function can have `declare author "name";` and `declare copyright "XXX";` declarations.
* Every **new** function must carry a `declare functionName license "ID";` line
  whose `ID` is a canonical [SPDX identifier](https://spdx.org/licenses/) --
  e.g. `MIT`, `GPL-3.0-only`, `LGPL-2.1-or-later`, `BSD-3-Clause`, `ISC`, or
  the repository's `LicenseRef-STK-4.3` and
  `LicenseRef-LGPL-2.1-or-later-with-Faust-exception` for the two licenses
  without an SPDX-listed id. The accepted spellings are the `CANONICAL` /
  `ALLOWED` tables of `scripts/normalize_licenses.py`; run
  `scripts/normalize_licenses.py --check` (included in `make checkdoc`) to
  verify, and plain `scripts/normalize_licenses.py` to fix legacy spellings.
* Each library has a `declare version "xx.yy.zz";` [semantic version](https://semver.org) number to be raised each time a modification is done, and the global `version` triplet in `version.lib` follows — see [Versioning](#versioning) for the exact rules.

### Versioning

Version numbers live at two levels, and both follow
[semantic versioning](https://semver.org):

* each library carries its own `declare version "MAJOR.MINOR.PATCH";`,
  raised **in the same commit** as the change it describes;
* `version.lib` holds the global `vl.version` triplet for the library set as
  a whole, raised once per batch of changes according to the
  highest-ranking change since it was last raised.

Which component to raise:

* **MAJOR** — any backwards-*incompatible* change to the public API:
  removing or renaming a documented function, changing its arity, its
  parameter order or units, or its audible semantics; and in particular
  **removing deprecated aliases** at the end of their grace period.
* **MINOR** — backwards-compatible functionality: a new function or
  library, new optional behavior, documenting a previously undocumented
  symbol, or **marking a function deprecated** (the alias still works, so
  deprecation itself is not a breaking change).
* **PATCH** — backwards-compatible bug fixes and internal improvements:
  wrong coefficients or constants, performance work, documentation fixes,
  and any change confined to underscore-prefixed internal symbols (they
  are not API — see
  [Variables and identifiers scoping](#variables-and-identifiers-scoping)).

The deprecation lifecycle ties into this: deprecating a name is MINOR,
and its removal must wait until at least one *published release* has
shipped with the `declare ... deprecated` warning, at which point the
removal is the MAJOR change of the next version. When in doubt about
whether a change is breaking, treat the documented behavior — the
function's doc block and its regression test — as the contract: if an
existing test reference has to be regenerated because the output changed,
the change is at least a bug fix worth calling out, and if callers must
edit their code, it is MAJOR.

### Library Import

To prevent cross-references between libraries, we generalized the use of the `library("")` system for function calls in all the libraries. This means that everytime a function declared in another library is called, the environment corresponding to this library needs to be called too. To make things easier, a `stdfaust.lib` library was created and is imported by all the libraries:

```
aa = library("aanl.lib");
sf = library("all.lib");
an = library("analyzers.lib");
ba = library("basics.lib");
co = library("compressors.lib");
db = library("debug.lib");
de = library("delays.lib");
dm = library("demos.lib");
dx = library("dx7.lib");
en = library("envelopes.lib");
fd = library("fds.lib");
fi = library("filters.lib");
ho = library("hoa.lib");
hy = library("hysteresis.lib");
it = library("interpolators.lib");
la = library("linearalgebra.lib");
ma = library("maths.lib");
mi = library("mi.lib");
ef = library("misceffects.lib");
mo = library("motion.lib");
no = library("noises.lib");
os = library("oscillators.lib");
pf = library("phaflangers.lib");
pl = library("platform.lib");
pm = library("physmodels.lib");
qu = library("quantizers.lib");
rm = library("reducemaps.lib");
re = library("reverbs.lib");
ro = library("routes.lib");
sp = library("spats.lib");
si = library("signals.lib");
so = library("soundfiles.lib");
sy = library("synths.lib");
ve = library("vaeffects.lib");
vl = library("version.lib");
wa = library("webaudio.lib");
wd = library("wdmodels.lib");
```

For example, if we wanted to use the `smooth` function which is now declared in `signals.lib`, we would do the following:

```
import("stdfaust.lib");

process = si.smooth(0.999);
```

This standard is only used within the libraries: nothing prevents coders to still import `signals.lib` directly and call `smooth` without `ro.`, etc. It means symbols and function names defined within a library **have to be unique to not collide with symbols of any other libraries**.  

### "Demo" Functions

"Demo" functions are placed in `demos.lib` and have a built-in user interface (UI). Their name ends with the `_demo` suffix. Each of these function have a `.dsp` file associated to them in the [Faust project](https://github.com/grame-cncm/faust) `examples` folder.

Any function containing UI elements should be placed in this library and respect these standards.

### "Standard" Functions

"Standard" functions are here to simplify the life of new (or not so new) Faust coders. They are declared in `/libraries/doc/standardFunctions.md` and allow to point programmers to preferred functions to carry out a specific task. For example, there are many different types of lowpass filters declared in `filters.lib` and only one of them is considered to be standard, etc.

## Testing the library

Before preparing a pull-request, the new library must be carefully tested:

- all functions defined in the library must be tested by preparing a DSP test program, to be added using the `#### Test` syntax 
- the compatibility library `all.lib` imports all libraries in a same namespace, so check functions names collisions using the following test program: `import("all.lib"); process = _;`
- reference files for all tests can be generated using the `make reference` command and then verified with the `make check` command, which compares the generated samples against the reference files within a specified tolerance. A good practice for developers is therefore to generate the reference files and re-run the checks whenever the code is modified. `make check` fails on the first divergence; use `make -k check` to run the whole suite and collect every failure.
- every new function therefore ships with **both** its `#### Test` section and the corresponding `functionName_test` entry in the *tests* folder, and its reference is generated with `make reference` in the same change.
- finally, `make checkdoc` must pass: it rejects any new undocumented symbol, any documentation block without a `#### Usage` section, any block reduced to a `#### Test` section, a stale `doc/standardFunctions.md`, and any non-canonical license string, while the historical debt recorded in `tests/doc-baseline.json` stays accepted.
- new code must also be checked in single and double precision, from 44.1 to 192 kHz, as described below: `make check` covers neither, `make check-precision` does.
- a function whose parameters are meant to vary at run time is tested with constant, slider and modulated parameters, as described below: the three run different code.
- buttons and checkboxes are driven by the harnesses (`arch/print_arch.cpp` for `make check`, `arch/precision_arch.cpp` for `make check-precision`): every button and checkbox is ON (1) for the first half of the rendered frames and OFF (0) for the second half. A gate is pressed then released, so a release, a note-off or a retrigger is exercised; a checkbox, a bypass for example, is rendered in both states, with the transition between them. Sliders and number entries keep their default value for the whole run. (Until October 2026 the buttons and checkboxes stayed ON for the whole run, so bypassed effects and releases were never tested, #281.)

### Constant, slider, modulated and jump tests

The Faust compiler generates different code for a parameter depending on what it is:

| parameter | example | the coefficients that depend on it are computed |
|---|---|---|
| a constant | `fi.resonlp(1000, 2, 1)` | once: folded at compile time, or at init when they depend on `ma.SR` |
| a control (slider) | `fi.resonlp(hslider("fc", ...), ...)` | once per block, at the start of `compute` |
| a signal | `fi.resonlp(1000*(1 + 0.5*lfo), ...)` | at every sample, inside the loop |

Precision, stability and CPU cost can differ between the three. A function that is correct with constants can lose precision when its coefficients are computed at run time in float. It can also blow up when they change at every sample, since a recursive structure that is stable for each frozen setting is not necessarily stable when that setting moves. And its cost per sample can double. The harnesses (`make check`, `make check-precision`, `make check-cpu`) render the tests as written, with the controls at their default values: they cannot turn a constant into a control or a signal. The test has to do it.

A function whose parameters are meant to vary at run time therefore has three tests, a recursive filter four, written first in its `#### Test` section like any other (rule 8 of `AGENTS.md`). Typical parameters are a cutoff or center frequency, a resonance, a gain, an oscillator frequency, a delay length or a time constant.

1. **`functionName_test`, constant parameters.** This is the usual test.
2. **`functionName_slider_test`, parameters from sliders** (`hslider`, `vslider`, `nentry`), without smoothing, with realistic default values. It checks that the function accepts run-time controls: a parameter that must be a constant makes it fail to compile. It checks the coefficients computed at run time in the program's precision: for `fi.resonlp`, the float/double level gap is 6.4e-5 with sliders against 1.8e-5 with constants. And it checks that they stay at control rate: its cost should match the constant test's. When it is clearly slower, the normalizer has moved part of the coefficient computation into the per-sample loop, which is what the `min(x, ma.MAX)` workarounds in the libraries prevent.
3. **`functionName_modulated_test`, a parameter modulated at every sample**, over the part of its range where the function is under stress (low cutoffs, high resonance...). It checks the stability and the precision of the time-varying structure, and the cost of computing the coefficients at every sample: 6.32 ns/frame for `fi.resonlp` against 3.48 with constants. A slider followed by `si.smoo` is a signal too, so a `_ui` wrapper that smooths its controls belongs to this case, not the previous one.

Drive the modulation with an integer counter, not with `os.osc` or `os.lf_*`. Those accumulate their phase in the program's precision and drift in float: the precision check then measures the modulator, not the function. With a sine modulator, the level gap of the test below is 9 times larger (4.8e-4) and its sample gap 43 times larger (2.2e-2). `ba.period` counts in integers and gives a triangle that is the same in both precisions. Give it a period tied to the sample rate, `P = int(ma.SR/10)`, so that the triangle runs at 10 Hz at every rate the precision check uses (with a fixed `ba.period(4800)` it would run at 40 Hz at 192 kHz). `P` and `1/P` are computed once at init: the period adds no per-sample division.

```
resonlp_test = no.noise : fi.resonlp(1000, 2, 1);
resonlp_slider_test = no.noise : fi.resonlp(hslider("fc", 1000, 50, 5000, 1), hslider("Q", 2, 0.5, 20, 0.01), 1);
resonlp_modulated_test = no.noise : fi.resonlp(fc, 2, 1)
with {
  P = int(ma.SR/10);                     // a tenth of a second, in samples, at every rate
  tri = 1 - abs(2*ba.period(P)/P - 1);    // 0 to 1 and back at 10 Hz, exact
  fc = 50*pow(100, tri);                  // exponential sweep from 50 Hz to 5 kHz
};
```

4. **`functionName_jump_test`, a parameter jumping between the two ends of its range**, for recursive filters. It is what a user produces by moving a slider: the harnesses never move one, so the `_slider_test` never jumps. A jump is where realizations differ most. A state-variable section leaks on an attenuated input after an abrupt cutoff change (#264); a direct form can leave its states far from the level the new coefficients expect, and its float and double outputs then diverge. The jump test is the `_modulated_test` with its triangle replaced by a square wave at 5 Hz, `sq = ba.period(2*P) < P`, so that the parameter holds each end of the sweep for 0.1 s:

   ```
   resonlp_jump_test = no.noise : fi.resonlp(50*pow(100, sq), 2, 1)
   with {
     P = int(ma.SR/10);
     sq = ba.period(2*P) < P; // 0 or 1, switching every 0.1 s, exact
   };
   ```

   Delay lines with an integer length need none: a jump of length is the same discontinuity whatever the realization.

   When it was introduced, every filter of `filters.lib` that has a `_modulated_test` got one, except ten that fail `make check-precision`, with level gaps of 1.1e-3 to 0.53. All are built on the direct-form `fi.tf2s` (`resonlp`, `resonhp`, `resonbp`, the `peak_eq` family, `highpass3e`, `highpass6e`, `highpass_plus_lowpass`), except `wgr`, which is already at the threshold with a constant 100 Hz. Every state-variable or TPT filter passes. They will get their jump tests with a realization that passes them.

Two more precautions:

- **An integer parameter driven by the triangle**, such as a delay length, must come out the same in both precisions. `int(16 + 112*tri)` does not: float and double `tri` can differ in the last bit, and near an integer boundary `int()` then picks a different delay, so the two outputs diverge by whole samples and the sample gap checks nothing. Compute the integer exactly, with an integer remainder, since Faust's `/` is always a float division:

  ```
  fb_comb_modulated_test = no.noise : fi.fb_comb(2048, d, 0.7, 0.6)
  with {
    P = int(ma.SR/10);
    m = 112*(P - abs(2*ba.period(P) - P)); // 112*tri*P, an integer
    d = 16 + int((m - m % P)/P + 0.5);     // 16 + floor(112*tri), the same integer in float and double
  };
  ```

- **The interval analysis of the compiler** does not see that `ba.period(P)/P` stays below 1 when `P` is not a constant: a parameter that needs bounds, such as a delay that is read directly with `@` or a window length, gets them explicitly (`: max(16) : min(128)`, `tri : max(0) : min(1)`).

Parameters that must be known at compile time (in capital letters by convention: an order, a number of voices or bands, a maximum delay) need neither variant. `scripts/lib_tests.py inventory xx.lib` lists which of the four tests each documented function has, in the doc blocks and in `tests/*.dsp`. `scripts/lib_tests.py add xx.lib new_tests.dsp` inserts tests written in an ordinary Faust file into both places; `scripts/README.md` describes it. The three costs can be compared in one run:

```bash
make check-cpu CPU_ARGS="-k '^resonlp(_slider|_modulated)?_test'"
```

### Precision and sample rate

The regression tests run in double precision at 48 kHz only (`-double`, `SAMPLE_RATE=48000`). Most hosts compile Faust code in single precision (`float`) and run it at 44.1, 48, 88.2, 96, 176.4 or 192 kHz. Before a pull request, new code must therefore be rendered in both precisions and at all these rates.

`make check-precision` does this for every `*_test`, with no stored reference: it compiles each test in `-single` and `-double` with `arch/precision_arch.cpp` (the excitation and control schedule of `arch/print_arch.cpp`, with a binary output), renders one second at each of the six rates, and compares the two builds. A test fails when:

- an output is not finite, in either precision, at any rate;
- its **level gap** exceeds 1e-3: for some output and rate, the RMS of the single-precision render differs from that of the double-precision render by more than 1e-3 in relative terms.

The level gap is the criterion, not the sample-by-sample gap, because `os.osc` drifts in phase in single precision (see below): the sample gap of a test it drives exceeds 1e-3 whether the code under test is accurate or not. The sample gap is still measured and written to the `--json` report. For a new test, prefer `no.noise` as input, or `os.tosc` when a sine is needed: both measurements are then meaningful. `os.tosc` is the sine of an integer phase (`os.tphase`): its phase is exact at every sample, the same in both precisions and at every rate, and it plays its frequency to 0.1 Hz; the tests use it in place of `os.osc`, except those of the oscillators themselves.

The debt accepted when the check was introduced is pinned in `tests/precision-baseline.json`, the way `tests/doc-baseline.json` pins the documentation debt: `nonfinite` lists the rates at which a test may be non-finite in single precision, `level` the worst level gap it may reach (within a factor `margin` of 2, since the last bits of a single-precision result depend on the compiler and its math library), and `expected` the few tests whose outputs differ between precisions by definition (`ma.EPSILON`, `ma.MIN`). A new test is never in the baseline, so it must pass outright. When a fix removes the need for an entry, the check says so: remove the entry in the same commit. For a `level` entry, it says so only once the gap is below the threshold divided by the margin (5e-4): a gap just under 1e-3 on your machine may still be above it on another platform, so do not remove an entry the check does not report. Never add or loosen an entry to silence a failure you caused; the baseline is regenerated as a whole (`scripts/check_precision.py --write-baseline`) only when the rates, the threshold or the harness change.

The whole run compiles every test twice and takes about ten minutes on ten cores. To check one library, pass its test file, or select tests by name:

```bash
make check-precision PRECISION_ARGS="tests/vaeffects_tests.dsp"
make check-precision PRECISION_ARGS="-k klonCentaur_test"
```

The builds use `faust -single|-double` and `c++ -O2`. A precision fix can depend on how the code is compiled: the Faust normalizer and a C++ `-ffast-math` both reassociate floating-point expressions, and can undo a rewrite that avoided a cancellation. When a change relies on a precise evaluation order, check it with other compilations too. `make check-precision-matrix` runs the check with C++ `-O2` and `-O3 -ffast-math`, then with Faust `-vec` and `-lang ocpp`, against the same baseline; single options are also available:

```bash
make check-precision-matrix PRECISION_ARGS="tests/vaeffects_tests.dsp"
make check-precision PRECISION_ARGS='-k Matched --cxx-options="-O3 -ffast-math"'
make check-precision PRECISION_ARGS="-k Matched --faust-options=-vec"
```

`make check-precision` renders each test as written, at its default control values. The points below go further; check them by hand for new code, with the controls at their extremes and with the input levels the function is meant for:

- **Stability.** At every rate and in both precisions the output must stay finite and bounded, with the controls at their extremes and with the input levels the function is meant for.
- **Float against double.** At each rate, compare the single and double precision renders of the same program. A well-conditioned structure stays within about 1e-5 to 1e-4 of the peak. A larger gap, or one that grows with the sample rate, points to a structure that loses precision in float. Recursive filters whose poles come close to z = 1 are the usual cause, that is, frequencies low relative to the sample rate. For example, `no.noise : fi.lowpass(4, 50)` differs by 0.3 % of its peak at 44.1 kHz and by 8 % at 192 kHz. Prefer a structure that stays accurate there, or document the limitation. A state-variable filter is one such structure: in the same conditions, `fi.svf.lp(50, 0.707)` stays within 4e-5.
- **Compare on an input that is the same in both precisions**, such as `no.noise`, which is an integer generator, or `os.tosc`, a sine of an integer phase. `os.osc` accumulates its phase in the program's precision, so a sine input already differs between float and double by 0.1 % at 44.1 kHz and 1 % at 192 kHz, and hides the behavior of the code under test.
- **Behavior across rates.** What should not depend on the sample rate must not: cutoff and resonance frequencies, formants, time constants, levels. Compute coefficients from `ma.SR`, and watch for anything set in samples (delay lengths, waveguide sections, block sizes) and for pre-warping or oversampling filters close to Nyquist at the lowest rates. When a model is only valid at some rates, say so in its documentation and, if possible, give a way to adapt it (see `pt.ticksPerSample`). `ma.SR` is clamped to 192 kHz (see `pl.SR`), so behavior above that rate is not guaranteed.
- **Long runs.** A recursive state decaying towards zero must not linger in the subnormal range, which float reaches much earlier than double: flush it or check that the structure does not produce it. Integer counters such as `ba.time` wrap after 2^31 samples, that is 12.4 hours at 48 kHz: do not use them to detect the first sample, use `1'` or `1 - 1'`.

For such hand checks, the `arch/print_arch.cpp` architecture used by `make check` takes the number of frames and the sample rate as arguments. For a program `probe.dsp` built around the new function, for instance `process = no.noise : fi.lowpass(4, 50);`, the following commands render one second at each rate in both precisions and print, for each rate, whether the output is finite, its peak, and the largest float/double difference relative to that peak:

```bash
b=tests/build
for p in single double; do
  faust -$p -a arch/print_arch.cpp $b/probe.dsp -o $b/probe-$p.cpp
  c++ -O2 -std=c++17 $b/probe-$p.cpp -o $b/probe-$p
done
for sr in 44100 48000 88200 96000 176400 192000; do
  $b/probe-single $sr $sr > $b/probe-single.txt
  $b/probe-double $sr $sr > $b/probe-double.txt
  python3 -c "import numpy as n; s=n.loadtxt('$b/probe-single.txt')[:,1:]; d=n.loadtxt('$b/probe-double.txt')[:,1:]; print('$sr', 'finite' if n.isfinite(s).all() and n.isfinite(d).all() else 'NOT FINITE', 'peak %.3g' % abs(d).max(), 'single/double gap %.1e' % (abs(s-d).max()/abs(d).max()))"
done
```

Report in the pull request what was checked and what was found, including any limitation left in the documentation.

### CPU cost

A change that alters the structure of a computation, such as a rewrite against cancellation, a filter realized in another form, or a workaround of the normalizer, also changes what it costs. That cost is a trade-off to state in the pull request, with numbers a reviewer can reproduce. `make check-cpu` measures it on the tests. The `--base REV` argument compares the libraries of the working tree, or of `--new REV`, with those of REV:

```bash
make check-cpu CPU_ARGS="--base origin/master tests/filters_analog_sections_tests.dsp"
make check-cpu-matrix CPU_ARGS="--base origin/master -k 'resonlp|vocoder_demo'"
scripts/check_cpu.py --base origin/master --new origin/some-branch -k tf2s
```

**Measure on an idle machine**, on AC power, with nothing else running: no build, no `make check` or `check-precision`, no other heavy job. A few seconds of another load can triple the rounds of the test being timed, and no tool can correct a timing made on a loaded machine. `check-cpu` warns when the load average exceeds the performance cores at the start, but it cannot see a short burst. What it does see is the spread of the rounds: a ratio whose spread is still above 20% after the re-race is marked `?`, left out of the summary, and listed at the end, to be measured again. Quote no ratio marked `?`. For the figures of a pull request, two runs that agree are better than one. On an idle machine, two full runs of the suite differed by 0.2% to 0.5% per ratio (median).

For each test, the table gives the best time per frame in the two versions, their ratio new / base, the share of one core at 48 kHz, and the spread of the rounds, which is the noise the ratio should be read against. Comparisons of identical code put that noise at about 3%: a ratio within 3%, or within its spread, is no difference. The measurement and the protocol come from Yann Orlarey's [faustcompilerbenchtool](https://github.com/orlarey/faustcompilerbenchtool), and are described in `scripts/README.md`. A time is flagged `NaN` when the output was not finite: that time measures NaN arithmetic, not the code.

- **Measure the tests you touched, and the callers that matter.** A function used inside a bank of filters, such as the 32 bands of `dm.vocoder_demo`, costs its ratio times the number of instances. Select these tests by file or with `-k`, or run the whole suite with `--changed-only`, which times only the tests whose generated code the change alters, wherever they are.
- **Measure with more than one compilation.** The default one is what faust2xx scripts use (`c++ -O3 -ffast-math`). A ratio depends on the compilation, and not only the times do. `-ffast-math` turns divisions into multiplications and reassociates sums: a direct-form filter profits from that more than a state-variable one. Faust `-vec` can change a ratio even more. `make check-cpu-matrix` runs `fast-math`, `strict` (`-O3`) and `vec` in turn. Report at least `fast-math` and `strict`.
- **Measure the three regimes.** A test with constant parameters computes its coefficients once. The `_slider_test` and `_modulated_test` variants (see *Constant, slider, modulated and jump tests* above) measure the cost per block and per sample. A rewrite can be cheap in the first regime and twice as slow in the last one: a state-variable realization of `fi.tf3slf` measured 1.22 times the direct form's cost with constants, and 1.97 times with its cutoff modulated at every sample.
- **Look at the `ops` column, not only at the ratio.** It counts the divisions, square roots and transcendental calls (`pow`, `tan`...) that each sample executes, and marks with `!` a change that adds any. A desktop core hides much of their cost; an embedded core such as a Cortex-M7 does not, since a division costs it 14 cycles and a `pow` tens to hundreds. A new per-sample `pow` or `tan` deserves a mention in the pull request even when the measured ratio looks harmless.
- **Quote ratios from one run.** Times vary between machines, compilers and runs. The identity lines printed first name the machine, the compilers (with their paths) and the revisions, so include them with the table.

Report the ratios, the compilations, and the absolute cost (% of a core) in the pull request. A slower function is acceptable when what it buys (precision, stability, a correct behavior) is worth it: say so explicitly.

## Formal certification (experimental, work in progress)

> **Status: experimental.** This tool is under active development: the set of
> properties it can certify is deliberately small, its verdicts and file
> formats may change, and it is **not** required for a pull-request to be
> accepted. Regular testing (`make reference` / `make check` / `make checkdoc`)
> remains the contract.

Alongside the numerical test harness, the repository carries a formal
certification pipeline based on [Lean 4](https://lean-lang.org): the compiled
signal graph of a DSP example is imported into Lean, analysed, and each verdict
is pinned as a machine-checked theorem. The hand-written specifications live in
`formalisation/`, the certified examples in `tests/lean/`, and the generator in
`scripts/sig2lean.py`.

Two properties are currently certified, on concrete instantiations:

- **feedback stability**: linear recursions of order ≤ 2 with constant
  coefficients are checked against the Jury criterion in exact rational
  arithmetic (e.g. `fi.tf2` instances);
- **index bounds**: every table read and delay tap is checked to stay in range
  *as written* — as opposed to being made safe by a compiler-inserted clamp.

Everything the analysers do not recognise exactly is **refused, not guessed**:
a refusal (`not certified`, `not proven`) is a statement about the analyser's
current coverage, not a defect report about the function.

### Contributor workflow

No Lean knowledge is needed. Prerequisites: `lean` (4.31, bundled Std only) and
`faust-rs` on the PATH — or override with `make certify FAUST_RS=... LEAN=...`.

1. Add a small DSP program to `tests/lean/` instantiating the new function
   with concrete parameters, e.g. `tests/lean/machin.dsp`:

   ```
   xx = library("malib.lib");
   process = xx.machin(3, 1000);
   ```

   The file's base name becomes the name of the generated definitions and
   theorems. A nominal case plus a boundary case is a good default; a
   deliberate counter-example whose refusal is itself pinned (like
   `tf2_unstable.dsp` or `table_bad_clamp.dsp`) is also valuable.

2. Run `make certify`. It regenerates the theorems into `tests/build/`,
   kernel-checks them, and diffs against the committed
   `tests/lean/certified.lean` — so a new `.dsp` makes it fail, displaying
   exactly the block that would be added. Read the verdicts in that diff:

   - `STABLE` / `IN RANGE`: the property is certified by a kernel-checked
     theorem;
   - `NOT STABLE` / `CLAMP REQUIRED`: the graph really is unstable, or the
     index only stays in the table thanks to the backend's clamp — for a
     library function, a hint to clamp or document on the Faust side;
   - `not a recognised linear recursion` / `not proven`: outside the certified
     fragment (coefficients depending on `ma.SR`, nonlinear recursion,
     order > 2…). The refusal is pinned as a `= false` theorem, so if a later
     extension of the analysers unlocks the case, `make certify` will show the
     verdict flip.

   The run also cross-checks every table verdict against the compiler's own
   clamp insertion (the `-ct` pass, read from
   `faust-rs --dump-sig-dag-prepared`): a `CLAMP REQUIRED` table the
   compiler left unclamped fails certification outright, and a clamp on a
   table Lean proves in range is recorded as a missed optimisation in the
   "Compiler clamp oracle" section of `certified.lean`.

3. Once the verdicts look right, run `make certify-reference` to regenerate
   `tests/lean/certified.lean` in place, and commit **both** the `.dsp` and the
   regenerated `certified.lean`.

From then on, every `make certify` re-proves the theorems and turns any
verdict drift — from a compiler or specification change — into a loud failure,
exactly as `make check` does for numerical outputs.

Two standing limits are worth knowing: certification applies to the exported
signal graph (not to the generated C++/Rust code), and to the exact rationals
denoted by the coefficients (not to floating-point execution). Both are
recorded as named obligations in `formalisation/signal-import-formal-spec.lean`.

A third, optional layer exists for maintainers: `make certify-deep` builds a
small [mathlib](https://github.com/leanprover-community/mathlib4)-based project
(`formalisation/mathlib/`) that discharges the central recorded obligation —
the executable Jury test is proved equivalent, at order 2, to "every pole lies
strictly inside the unit disc" — plus the positivity hypothesis of the `tf2s`
theorem. It pins its own toolchain and downloads the mathlib build cache
(several GB) on first run; it is never needed for `make certify`, for
contributions, or for pull-requests.

## LLMs

The site exposes an `llms.txt` file generated from `doc/docs/llms.txt` and published at [https://faustlibraries.grame.fr/llms.txt](https://faustlibraries.grame.fr/llms.txt).

### Faust Library JSON Exports

This repository can also generate machine-readable JSON exports of the Faust
library documentation directly from the `.lib` sources.

The generator is:

```bash
scripts/build_faust_doc_index.py
```

It parses documentation blocks from the library sources, starting from
`stdfaust.lib`, follows `library("...")` and `import("...")` directives, and
extracts for each documented symbol:

- `summary`
- `usage`
- `params`
- `notes`
- `io` with `inSignals` / `outSignals` when derivable
- `testCode`
- `references`
- `license` when a per-symbol `declare ... license|licence "..."` is present
- `source`

Two JSON layouts are supported:

- monolithic: one full JSON file containing all libraries and symbols
- split: one compact global index plus one detailed JSON file per module

Default Make targets:

```bash
make doc-index
make doc-index-split
make doc-index-commercial
```

Default output locations:

- `make doc-index` writes `tests/faust-doc-index.json`
- `make doc-index-split` writes:
  - `tests/faust-doc-index.json`
  - `tests/faust-doc/index.json`
  - `tests/faust-doc/modules/*.json`
- `make doc-index-commercial` writes the same paths as `make doc-index-split`,
  but filters the exported symbols using the `commercial-compatible` license
  policy

You can override the output paths:

```bash
make doc-index DOC_INDEX_OUTPUT=/tmp/faust-doc-index.json
make doc-index-split DOC_INDEX_OUTPUT=/tmp/faust-doc-index.json DOC_INDEX_SPLIT_DIR=/tmp/faust-doc
```

You can also run the generator directly:

```bash
python3 scripts/build_faust_doc_index.py --repo-root . --output tests/faust-doc-index.json --pretty
python3 scripts/build_faust_doc_index.py --repo-root . --output tests/faust-doc-index.json --split-output-dir tests/faust-doc --pretty
python3 scripts/build_faust_doc_index.py --repo-root . --output tests/faust-doc-index.json --split-output-dir tests/faust-doc --license-policy commercial-compatible --pretty
```

License-policy filtering is optional. The supported values are:

- `all`: export every documented symbol
- `commercial-compatible`: keep only symbols that pass a conservative
  per-symbol license heuristic

The current `commercial-compatible` heuristic:

- accepts missing per-symbol licenses and treats them as falling back to the
  library default
- accepts common permissive or weak-copyleft markers such as `MIT`, `BSD`,
  `Apache`, `LGPL`, `LGPL with exception`, `MPL`, `ISC`, `zlib`, `Boost`,
  `Unlicense`, `public domain`, and `STK-4.3`
- rejects markers such as `GPL`, `AGPL`, and explicitly non-commercial terms

This is a practical export filter for tooling, not a legal opinion.

The policy can also be customized with external allowlist/denylist files:

```bash
python3 scripts/build_faust_doc_index.py \
  --repo-root . \
  --output tests/faust-doc-index.json \
  --split-output-dir tests/faust-doc \
  --license-policy commercial-compatible \
  --license-allowlist-file /path/to/license-allowlist.txt \
  --license-denylist-file /path/to/license-denylist.txt \
  --pretty
```

These files use a simple newline-based format:

- one token or pattern per line
- matching is case-insensitive and based on substring inclusion
- empty lines are ignored
- lines starting with `#` are treated as comments

Example:

```text
# Allow permissive licenses and a specific local marker
mit
bsd
apache
my-company-approved-license
```

The Make target also supports these overrides:

```bash
make doc-index-commercial \
  DOC_INDEX_LICENSE_ALLOWLIST_FILE=/path/to/license-allowlist.txt \
  DOC_INDEX_LICENSE_DENYLIST_FILE=/path/to/license-denylist.txt
```

The split layout is recommended for LLM or retrieval-based use because it avoids
loading the whole documentation into context for every request.

### Local Documentation Query API

The repository also ships with a local query tool that reproduces the Faust
library documentation operations used in `faustforge`:

```bash
scripts/faust_doc_api.py
```

Supported operations:

- `search_faust_lib`
- `get_faust_symbol`
- `list_faust_module`
- `get_faust_examples`
- `explain_faust_symbol_for_goal`

The tool can read either:

- the monolithic export `tests/faust-doc-index.json`
- the split export `tests/faust-doc/index.json`

If `--index` is omitted, it tries these defaults in that order:

1. `tests/faust-doc/index.json`
2. `tests/faust-doc-index.json`

Examples:

```bash
python3 scripts/faust_doc_api.py --pretty search_faust_lib reverb --limit 5
python3 scripts/faust_doc_api.py --pretty search_faust_lib filter --module filters --limit 10

python3 scripts/faust_doc_api.py --pretty get_faust_symbol de.delay
python3 scripts/faust_doc_api.py --pretty list_faust_module delays --limit 20
python3 scripts/faust_doc_api.py --pretty get_faust_examples delay
python3 scripts/faust_doc_api.py --pretty explain_faust_symbol_for_goal re.springreverb "build a metallic spring reverb"
```

To force a specific index location:

```bash
python3 scripts/faust_doc_api.py --index tests/faust-doc-index.json --pretty get_faust_symbol aa.Rsqrt
python3 scripts/faust_doc_api.py --index tests/faust-doc --pretty list_faust_module filters --limit 10
```

The `make clean` target removes the generated JSON artifacts by default:

- `tests/faust-doc-index.json`
- `tests/faust-doc/`

### Licensing issue

Some DSP functions carry per-symbol licenses that are more restrictive than the
default Faust libraries distribution terms. This matters in LLM-assisted code
generation and code reuse workflows.

In particular, functions released under licenses that are non-commercial,
copyleft-incompatible, or otherwise unsuitable for the intended downstream use
**must not be suggested blindly in generated code**.

When exposing Faust library data to LLM tools or retrieval systems:

- preserve per-function license metadata when it exists
- make that metadata queryable alongside the usual documentation fields
- check license compatibility before recommending or assembling generated DSP
  code from library functions

The local JSON export and query tooling can expose this information, so **license
checks can be integrated into higher-level assistants and generation pipelines**.


## Library test and deployment

For GRAME maintainers:

- global tests can be done using the `make reference` and `make check` at rool level
- regenerate the PDF documentation using `make pdf` target at rool level
- update the library submodule in [faust](https://github.com/grame-cncm/faust), recompile and deploy WebAssembly libfaust in [fausteditor](https://github.com/grame-cncm/fausteditor), [faustplayground](https://github.com/grame-cncm/faustplayground) and [faustide](https://github.com/grame-cncm/faustide)
- update the library submodule in [faustlive](https://github.com/grame-cncm/faustlive) 
- update the library list in this [fausteditor](https://github.com/grame-cncm/fausteditor/blob/master/src/faustlive.js) page as well as the [snippets](https://github.com/grame-cncm/fausteditor/blob/master/src/codemirror/mode/faust/faustsnippets.js) (using the `faust2atomsnippets -s *.lib` command at root level).
- update the library list in this [faustide](https://github.com/grame-cncm/faustide/blob/master/src/documentation.ts) page and [LIBRARIES](https://github.com/grame-cncm/faustide/tree/master/src/static/examples/LIBRARIES) folder.
- update the library list in the [faustgen~](https://github.com/grame-cncm/faust/blob/master-dev/embedded/faustgen/src/faustgen_factory.cpp) code
- update the [Faust Syntax Highlighting Files](https://github.com/grame-cncm/faust/tree/master-dev/syntax-highlighting)
- make an update PR for [vscode-faust](https://github.com/hellbent/vscode-faust) project
