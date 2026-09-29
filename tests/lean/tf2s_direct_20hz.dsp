// The direct form fi.lowpass used before #262: fi.tf2s at 20 Hz. Its Jury
// margin 1 + a1 + a2 is O(w^2), about 1.7e-6 at 96 kHz, below what the
// rounding of its coefficients in single precision can move. Pins: stable
// in exact and double at every rate, not proven in single from 88.2 kHz.
fi = library("filters.lib");
ma = library("maths.lib");
process = fi.tf2s(0, 0, 1, sqrt(2), 1, 2*ma.PI*20);
