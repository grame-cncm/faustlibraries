// ba.tabulate with C = 1: the library clamps the read index itself
// (rid(x,1) = max(0, min(x, S-1))), and the interval analysis reads that
// clamp: the table verdict is IN RANGE as written, and the clamp oracle
// checks the compiler inserts nothing on top. The stability verdict is a
// pinned refusal: the table *generator* contains ba.time's counter
// recursion, whose pole sits on the unit circle.
ba = library("basics.lib");
process = ba.tabulate(1, sin, 128, 0.0, 10.0, hslider("x", 0, 0, 10, 0.01)).val;
