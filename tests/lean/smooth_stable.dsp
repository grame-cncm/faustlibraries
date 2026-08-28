// si.smooth with a constant coefficient — the most used smoothing idiom in
// the libraries (si.smoo is the same recursion with an SR-dependent pole).
// Pins: order-1 recursion, a1 = -0.999, Jury => STABLE.
si = library("signals.lib");
process = hslider("g", 0, 0, 1, 0.01) : si.smooth(0.999);
