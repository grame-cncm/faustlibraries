// select2 between two indices, one past the table: the range is their union,
// whichever the selector. CLAMP REQUIRED.
process = rdtable(16, 1.0, select2(button("b"), int(hslider("i", 0, 0, 15, 1)), int(hslider("j", 0, 0, 100, 1))));
