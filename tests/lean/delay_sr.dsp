// A delay set in seconds, de.delay(ma.SR, 0.25*ma.SR): the tap is computed
// from the sample rate in each precision. Pins: non-negative at every rate.
de = library("delays.lib");
ma = library("maths.lib");
process = de.delay(ma.SR, 0.25*ma.SR);
