// fi.fb_comb with |aN| = 1.1: its poles lie outside the unit circle. Pins:
// not proven stable (the small-gain test cannot conclude, as it must not).
fi = library("filters.lib");
process = fi.fb_comb(1024, 441, 1, 1.1);
