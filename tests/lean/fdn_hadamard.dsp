// A 4-line feedback delay network: delays of 149, 211, 263 and 293
// samples, a loss of 0.9 per pass, and the orthogonal mixing matrix
// hadamard(4)/2. Every gain of the small-gain test is 0.45 per line, 1.8 per
// row: it fails, although the network is stable. A Lyapunov-Krasovskii
// certificate (the energy of the four delay lines) proves it, whatever the
// delays. Pins: stable, and fdn_hadamard_unstable.dsp (a gain of 1.05) is not.
ro = library("routes.lib");
de = library("delays.lib");
ba = library("basics.lib");
N = 4;
g = 0.9;
lines = par(i, N, de.delay(512, ba.take(i + 1, (149, 211, 263, 293))) : *(g));
mix = ro.hadamard(N) : par(i, N, /(2));
process = (ro.interleave(N, 2) : par(i, N, +) : lines) ~ mix :> _;
