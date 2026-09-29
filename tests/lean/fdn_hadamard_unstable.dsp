// fdn_hadamard.dsp with a gain of 1.05 per pass: the mixing matrix is
// orthogonal, so the network gains 5% per pass and is unstable. No
// certificate can exist; pins that the analysis does not prove it.
ro = library("routes.lib");
de = library("delays.lib");
ba = library("basics.lib");
N = 4;
g = 1.05;
lines = par(i, N, de.delay(512, ba.take(i + 1, (149, 211, 263, 293))) : *(g));
mix = ro.hadamard(N) : par(i, N, /(2));
process = (ro.interleave(N, 2) : par(i, N, +) : lines) ~ mix :> _;
