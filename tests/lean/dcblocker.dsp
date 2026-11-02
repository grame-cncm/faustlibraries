// fi.dcblocker = zero(1) : pole(pow(0.995, 44100/ma.SR)) — a one-pole from
// filters.lib whose pole follows the rate (35 Hz at every rate since 2026-11-02;
// it was the constant 0.995). Pins: NOT CERTIFIED, the pole is not a constant
// (the analyser reads constant coefficients only, as for si.smoo).
fi = library("filters.lib");
process = fi.dcblocker;
