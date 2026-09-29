// si.smoo: a one-pole smoother whose pole exp(-1/(tau*SR)) depends on the
// sample rate. Pins: stable at the six rates in the three arithmetics.
si = library("signals.lib");
process = si.smoo;
