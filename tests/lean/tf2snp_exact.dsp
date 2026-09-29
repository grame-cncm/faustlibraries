// fi.tf2snp, normalized-ladder coefficients computed without cancellation
// (tf2snp-exact-coeffs). Pins the verdict at the six rates.
fi = library("filters.lib");
process = fi.tf2snp(0, 0, 1, sqrt(2), 1, 2*3.141592653589793*1000);
