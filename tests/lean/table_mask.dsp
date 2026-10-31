// An index masked to the table, whatever the slider range: x & 15 lies in
// [0, 15] for every int x. IN RANGE.
process = rdtable(16, 1.0, int(hslider("i", 0, 0, 1000, 1)) & 15);
