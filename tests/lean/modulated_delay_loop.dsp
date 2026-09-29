// A delay modulated at every sample inside a feedback loop, as in a
// flanger: y = x + 0.5*y[n - d(n)] with d(n) between 100 and 300 samples.
// Jury cannot read a variable delay; the small-gain test only needs
// d >= 1. Pins: stable. (With de.fdelay, the two interpolation weights
// (1-f) and f are bounded separately, their sum by 2: not proven.)
de = library("delays.lib");
os = library("oscillators.lib");
process = (+ : de.delay(1024, int(200 + 100*os.osc(0.5)))) ~ *(0.5);
