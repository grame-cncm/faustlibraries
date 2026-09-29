// fi.fb_fcomb, a feedback comb with a fractional delay: two taps weighted by
// the interpolation, whose absolute values sum to |aN|. Pins: stable.
fi = library("filters.lib");
process = fi.fb_fcomb(1024, 441.5, 1, 0.7);
