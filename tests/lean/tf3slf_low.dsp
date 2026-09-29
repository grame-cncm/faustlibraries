// fi.tf3slf with its poles at 1 rad/s (0.16 Hz), as in tf3slf_test, which
// check-precision reports non-finite in single at every rate. A third-order
// recursion: refused by the rate analysis (more than 2 states), pinned so
// that extending it shows up here.
fi = library("filters.lib");
process = fi.tf3slf(0, 0, 0, 1, 1, 2, 2, 1);
