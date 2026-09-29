// fi.tf3slf with its poles at 1 rad/s (0.16 Hz), as in tf3slf_test, which
// check-precision reports non-finite in single at every rate. A triple pole
// this close to 1 leaves no margin: the Lyapunov certificate the oracle finds
// does not survive the box of the coefficients, even in exact arithmetic,
// and the recursion stays not proven. Pinned so that extending the analysis
// shows up here.
fi = library("filters.lib");
process = fi.tf3slf(0, 0, 0, 1, 1, 2, 2, 1);
