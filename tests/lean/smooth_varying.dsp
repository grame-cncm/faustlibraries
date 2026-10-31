// si.smooth with a pole from a slider: a product by a non-constant is not
// distributed over the sum, and the recursion is refused.
si = library("signals.lib");
process = hslider("g", 0, 0, 1, 0.01) : si.smooth(hslider("s", 0.9, 0, 0.99, 0.01));
