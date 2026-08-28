// ba.tabulate with C = 0 and an input range wider than [r0, r1]: the
// library applies no protection and the index can leave the table. The
// affine index arithmetic ((x-r0)/(r1-r0)*(S-1)) is outside rangeOf's
// current rules, so the as-written verdict is a pinned "not proven" — and
// the clamp oracle records that only the compiler's -ct clamp stands
// between this real-code site and an out-of-bounds read.
ba = library("basics.lib");
process = ba.tabulate(0, sin, 128, 0.0, 10.0, hslider("x", 0, 0, 20, 0.01)).val;
