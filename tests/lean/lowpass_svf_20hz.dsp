// fi.lowpass at 20 Hz: second-order sections in state-variable form since
// #262, accurate in float at low cutoffs. Pins: stable at the six rates of
// check-precision in exact, double and single arithmetic.
fi = library("filters.lib");
process = fi.lowpass(2, 20);
