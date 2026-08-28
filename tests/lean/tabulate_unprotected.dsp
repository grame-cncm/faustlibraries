// ba.tabulate with C = 0 and an input range wider than [r0, r1]: the
// library applies no protection and the index can leave the table. The
// affine rangeOf rules (translate / scale / inverse-scale) read the index
// arithmetic ((x-r0)/(r1-r0)*(S-1) + 1/2) exactly, so the as-written
// verdict is a proven CLAMP REQUIRED — and the clamp oracle confirms the
// compiler's -ct clamp is what stands between this real-code site and an
// out-of-bounds read.
ba = library("basics.lib");
process = ba.tabulate(0, sin, 128, 0.0, 10.0, hslider("x", 0, 0, 20, 0.01)).val;
