# Pink Trombone port — reference, validation and notes

Support material for `pinktrombone.lib` (root, prefix `pt`), the Faust port of Neil
Thapen's **Pink Trombone** v1.1 (2017, MIT) <https://dood.al/pinktrombone/>.
Main entry points: `pt.pinkTrombone(...)` / `pt.pinkTrombone2(...)` (the `2` variants
take two independent constrictions, like the original's multi-touch), `pt.glottis`,
`pt.tract` / `pt.tract2` (+ `tractN`/`tractN2` with explicit turbulence noise),
`pt.lfWaveform`, `pt.tractDiameters(2)`, `pt.tractReflections`, `pt.tractTick`,
`dm.pink_trombone_demo` (demo GUI).

## Files

- `port-notes.md` — how each part of the JS maps to Faust, every deliberate
  deviation, validation results, Faust lessons. **Read this before changing the DSP.**
- `simplex-noise-fit.md` — the 1-D simplex drift noise (`no.simplex1_lf` in
  `noises.lib`, exact) and the history of the earlier statistical substitute.
- `ptref.py` — line-by-line Python port of the JS `Tract`/`Glottis` used as the
  reference (multi-touch capable). `fh.py` — DawDreamer render helper. `validate.py` —
  compares the Faust code with the reference and fails on nonfinite output or errors above the documented tolerances: `python3.11 tests/pinktrombone/validate.py`
  (needs dawdreamer, numpy, scipy).
- `speak.py` — phoneme-to-trajectory sequencer: compiles an ARPAbet-ish phoneme
  string into per-sample automation for `dm.pink_trombone_demo` and renders it
  (`python3.11 speak.py "HH AH . L OW | W ER L D" out.wav`, or `--demo` for the
  phrases in `listening/speak_*.wav`). Vowels are calibrated against the engine
  itself (LPC formant matching, method in the module docstring); rounded vowels
  and clusters use the second constriction bus. No laterals/trills — a 1-D tract
  cannot say [l]/[r] properly; L and R are approximations.
- `../pinktrombone_tests.dsp` — deterministic `_test` specs for `make reference/check`;
  `dm.pink_trombone_demo` in `demos.lib` (`../demos_tests.dsp`).
- Not committed (gitignored): the original page — fetch with
  `curl -sL https://dood.al/pinktrombone/ -o tests/pinktrombone/pinktrombone-1.1-original.html`
  (the whole synth is inline JS: `Glottis`, `Tract`, `TractUI.setRestDiameter`,
  `TractUI.handleTouches`, `AudioSystem.doScriptProcessor`) — and `listening/`
  demo renders (default "ah", vowel glide with wobble, tenseness sweep, fricative,
  plosive, nasal, voice gate, 20 s wobble).

## Status (2026-08-18)

- Tract (44-section Kelly–Lochbaum + 28-section nose, 2 ticks/sample, transients,
  turbulence, velum) matches the JS reference to ~1e-6 relative in steady state
  (float32); differences only in the first ~0.25 s (the JS interpolates its
  reflection coefficients from zero in block 0) and during diameter movement
  (block-rate vs sample-rate slew).
- Glottis (LF pulse via Rd, per-period parameter latching, aspiration, intensity
  ramp, frequency smoothing, vibrato/wobble, tenseness drift) matches the reference
  waveform to <1.5e-3 abs and RMS / high-band statistics to <1 %; the drift noise
  is real simplex noise, exact up to the seed (`pt.noiseSeed`).
- CPU: ~12 % of one core at 44.1 kHz (DawDreamer, float32). Compiles and renders
  its block diagram in the Faust Web IDE (box-graph kept small; see port-notes.md).
- Not yet listened to by a human.

## Controls (`dm.pink_trombone_demo`)

| group | control | original |
|---|---|---|
| voicebox | pitch (0..20 semitones above F2 87.31 Hz), tenseness, always voice, pitch wobble | keyboard x, keyboard y, the two buttons |
| tract | tongue index (12..29), tongue diameter (2.05..3.5), nasal | tongue control disc, touching above the nose |
| constriction | index (2..44), diameter (0..3, 3 = none, ≤0.3 = closure), active | any other touch on the tract |

## Compatibility

Use `pt = library("pinktrombone.lib");` or `import("stdfaust.lib");`.
`all.lib` registers the `pt` environment rather than flattening the library's short
generic names (`n`, `NSTATE`, `glottis`, `tract`, ...) into its namespace.
Internal helpers carry a `_` prefix and are not part of the API; the GUI lives in
`dm.pink_trombone_demo`.

## Focused checks

```sh
make checkdoc
make reference DSP_FILES=tests/pinktrombone_tests.dsp
make check DSP_FILES=tests/pinktrombone_tests.dsp OUTPUT_DIR=/tmp/pt-scalar-output
make check DSP_FILES=tests/pinktrombone_tests.dsp FAUST_OPT="-double -vec -t 0" OUTPUT_DIR=/tmp/pt-vector-output
python3.11 tests/pinktrombone/validate.py
python3 -m unittest discover -s tests -p test_doc_index.py
```

Use fresh output directories on each run because the Makefile does not track
library source dependencies. References and generated outputs are local artifacts;
never stage them. The C++ compiler must be able to find the Faust architecture
headers (`faust/dsp/dsp.h`).

## Performance comparison

Save the old library and compare it with the current implementation:

```sh
git show 5bab71a:pinktrombone.lib > /tmp/pinktrombone-before.lib
python3 tests/pinktrombone/benchmark.py --baseline /tmp/pinktrombone-before.lib
```

If the C++ compiler cannot find the Faust headers, add
`--include /path/to/faust/architecture`. `FAUST`, `CXX`, and `CXXFLAGS` may override
the tools and compiler flags. `--output report.json` saves all measurements.
The benchmark alternates baseline/candidate runs and reports the median of nine
rounds, using 48 kHz, 256-frame blocks, single-precision DSP and `-O2` by default.
It covers the glottis, a fixed two-constriction voice, and a voice with moving
pitch, tenseness and tongue controls. This measures render throughput on the
local machine; it does not measure real-time scheduling or audio-device latency.
