//----------------------------------------------------------------------------
// interpolators_tests.dsp
// Tests for interpolator helper functions.
//----------------------------------------------------------------------------

it = library("interpolators.lib");
os = library("oscillators.lib");
ma = library("maths.lib");
ba = library("basics.lib");

interpolate_linear_test = it.interpolate_linear(0.5, 0.0, 1.0);

interpolate_cosine_test = it.interpolate_cosine(0.5, 0.0, 1.0);

interpolate_cubic_test = it.interpolate_cubic(0.5, -1.0, 2.0, 1.0, 4.0);

interpolator_two_points_test = it.interpolator_two_points(gen, idv, it.interpolate_linear)
with {
    gen(idx) = waveform {0.0, 1.0, 4.0, 9.0, 16.0}, int(ma.modulo(idx, 5)) : rdtable;
    step = 0.25;
    idxFloat = ma.modulo((+(step)~_) - step, 4.0);
    idv = it.make_idv(idxFloat);
};

interpolator_linear_test = it.interpolator_linear(gen, idv)
with {
    gen(idx) = waveform {0.0, 1.0, 4.0, 9.0, 16.0}, int(ma.modulo(idx, 5)) : rdtable;
    step = 0.25;
    idxFloat = ma.modulo((+(step)~_) - step, 4.0);
    idv = it.make_idv(idxFloat);
};

interpolator_cosine_test = it.interpolator_cosine(gen, idv)
with {
    gen(idx) = waveform {0.0, 1.0, 4.0, 9.0, 16.0}, int(ma.modulo(idx, 5)) : rdtable;
    step = 0.25;
    idxFloat = ma.modulo((+(step)~_) - step, 4.0);
    idv = it.make_idv(idxFloat);
};

interpolator_four_points_test = it.interpolator_four_points(gen, idv, it.interpolate_cubic)
with {
    gen(idx) = waveform {-1.0, 2.0, 1.0, 4.0, 7.0, 3.0}, int(ma.modulo(idx, 6)) : rdtable;
    step = 0.25;
    idxFloat = ma.modulo((+(step)~_) - step, 5.0);
    idv = it.make_idv(idxFloat);
};

interpolator_cubic_test = it.interpolator_cubic(gen, idv)
with {
    gen(idx) = waveform {-1.0, 2.0, 1.0, 4.0, 7.0, 3.0}, int(ma.modulo(idx, 6)) : rdtable;
    step = 0.25;
    idxFloat = ma.modulo((+(step)~_) - step, 5.0);
    idv = it.make_idv(idxFloat);
};

interpolator_select_test = it.interpolator_select(gen, idv, 2)
with {
    gen(idx) = waveform {-1.0, 2.0, 1.0, 4.0, 7.0, 3.0}, int(ma.modulo(idx, 6)) : rdtable;
    step = 0.25;
    idxFloat = ma.modulo((+(step)~_) - step, 5.0);
    idv = it.make_idv(idxFloat);
};

lerp_test = it.lerp(0.0, 10.0, -5.0, 5.0, 2.5);

piecewise_test = it.piecewise((-5, -2, 0, 3), (1, 0, 4, -1), os.osc(0.1));

lagrangeCoeffs_test = it.lagrangeCoeffs(2, (0.0, 0.5, 1.0), 0.25);

lagrangeInterpolation_test =
    (lagrange_x, lagrange_y0, lagrange_y1, lagrange_y2, lagrange_y3)
    : it.lagrangeInterpolation(3, (0, 1, 2, 3))
with {
    lagrange_x = 1.5;
    lagrange_y0 = 2.0;
    lagrange_y1 = 5.0;
    lagrange_y2 = -1.0;
    lagrange_y3 = 3.0;
};

frdtable_test = it.frdtable(3, 16, os.sinwaveform(16), os.phasor(16, 200));

frwtable_test = it.frwtable(3, 16, os.sinwaveform(16), ba.period(16), os.osc(220), os.phasor(16, 150));

remap_test = it.remap(-1.0, 1.0, 100.0, 1000.0, os.osc(0.5));
