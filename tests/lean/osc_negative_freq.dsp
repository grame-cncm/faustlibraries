// os.osc at a negative frequency: the phase x - floor(x) of a slightly
// negative x rounds to 1.0 in floating point (frac(-1e-9) = 1.0 in single),
// which puts the 65536-entry table index one past the end. Pins: the table
// read is proven in range for os.osc(440) (osc.dsp) in double and single,
// not here.
os = library("oscillators.lib");
process = os.osc(-440);
