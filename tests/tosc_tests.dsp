// The test source itself (tosc.lib) : its float/double gap is the floor of the
// precision harness -- the error a test inherits from its input alone.
import("tosc.lib");

tosc_440_test = tosc(440);
tosc_12000_test = tosc(12000);
tosc_lfo_test = tosc(0.1);
