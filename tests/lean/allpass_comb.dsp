// fi.allpass_comb, the Schroeder allpass of the reverbs: its recursion is a
// feedback comb with gain -aN. Pins: stable for |aN| < 1, by the small-gain test.
fi = library("filters.lib");
process = fi.allpass_comb(1024, 441, 0.6);
