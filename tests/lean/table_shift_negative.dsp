// >> rounds down, also below zero: -1 >> 2 is -1, not 0, so the index can be -1.
// A truncating shift would read [0, 3]. CLAMP REQUIRED.
process = rdtable(16, 1.0, int(hslider("i", 0, -1, 15, 1)) >> 2);
