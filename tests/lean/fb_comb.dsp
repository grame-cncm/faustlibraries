// fi.fb_comb: y[n] = x[n] - aN*y[n-441], a feedback comb with 441 samples of
// state. Jury does not read it (more than 2 states); the small-gain test
// does: stable when |aN| < 1, whatever the delay. Pins: stable, and
// fb_comb_unstable.dsp is not.
fi = library("filters.lib");
process = fi.fb_comb(1024, 441, 1, 0.7);
