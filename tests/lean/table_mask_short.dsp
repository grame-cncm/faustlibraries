// The same mask, one bit too wide for the table: CLAMP REQUIRED.
process = rdtable(16, 1.0, int(hslider("i", 0, 0, 1000, 1)) & 31);
