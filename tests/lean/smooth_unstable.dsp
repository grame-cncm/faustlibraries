// si.smooth with a pole outside the unit circle: the coefficient above the sum
// is read, not assumed. Pins: a1 = -3/2, Jury => NOT STABLE.
si = library("signals.lib");
process = hslider("g", 0, 0, 1, 0.01) : si.smooth(1.5);
