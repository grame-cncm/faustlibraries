// fi.dcblocker = zero(1) : pole(0.995) — a classic constant-coefficient
// one-pole from filters.lib. Pins: STABLE through the zero/pole composition.
fi = library("filters.lib");
process = fi.dcblocker;
