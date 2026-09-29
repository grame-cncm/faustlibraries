// ve.bandpass2Matched at the defaults of bandpass2Matched_test, which
// check-precision reports non-finite in single at 176.4 kHz: a per-block
// sqrt of a cancelling expression gets a negative argument in single
// precision. Pins: the finite verdict names that sqrt where it may fail.
ve = library("vaeffects.lib");
process = ve.bandpass2Matched(1200, 2.0);
