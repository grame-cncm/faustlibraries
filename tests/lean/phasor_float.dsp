// A floating-point phasor indexing a sine table: the form of os.osc in double
// precision. os.osc itself goes through the fixed-point phasor here, certify
// compiling in single (see osc.dsp). Pins the strict bound x - floor(x) in
// [0, 1), without which int(frac*N) would reach N: IN RANGE.
ma = library("maths.lib");
os = library("oscillators.lib");
process = rdtable(65536, os.sinwaveform(65536), int(phase * 65536))
with { phase = (+(0.01) : ma.decimal) ~ _; };
