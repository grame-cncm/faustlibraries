// fi.tf2snp, normalized-ladder coefficients computed without cancellation
// (tf2snp-exact-coeffs): a rotation in a 4-state recursion, which neither
// Jury (2 states at most) nor the small-gain test (a rotation has gain 1)
// reads. A Lyapunov certificate proves it stable. Pins the verdict at the
// six rates.
fi = library("filters.lib");
process = fi.tf2snp(0, 0, 1, sqrt(2), 1, 2*3.141592653589793*1000);
