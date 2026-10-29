//----------------------------------------------------------------------------
// fastmath_tests.dsp
// Tests for the fast mathematical functions.
//----------------------------------------------------------------------------

fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");

fexp2_test = fa.fexp2(3.3);
fexp2_slider_test = par(i, 6, fa.fexp2(xi(i))/pow(2.0, xi(i))) with { X = (-20.0, -0.5, 0.0, 0.3, 10.5, 20.0); xi(i) = hslider("fexp2:x%i", ba.take(i+1, X), -20, 20, 0.001); }; // relative to the exact value, so that make check (tolerance 1e-5) compares every point, whatever its magnitude
fexp2_modulated_test = fa.fexp2(40*tri - 20) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fexp2_nan_test = select2(y < 1e6, 0.0, y) with { i = ba.time % 4; y = fa.fexp2(select2(i == 3, 4*i - 6, (i - 3) * (ma.MAX * 2))); };
fexp2_faster_test = fa.fexp2_faster(3.3);
fexp2_faster_slider_test = par(i, 6, fa.fexp2_faster(xi(i))/pow(2.0, xi(i))) with { X = (-20.0, -0.5, 0.0, 0.3, 10.5, 20.0); xi(i) = hslider("fexp2_faster:x%i", ba.take(i+1, X), -20, 20, 0.001); }; // relative to the exact value, so that make check (tolerance 1e-5) compares every point, whatever its magnitude
fexp2_faster_modulated_test = fa.fexp2_faster(40*tri - 20) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fexp_test = fa.fexp(2.3);
fexp_slider_test = par(i, 6, fa.fexp(xi(i))/exp(xi(i))) with { X = (-14.0, -1.0, 0.0, 0.5, 7.3, 14.0); xi(i) = hslider("fexp:x%i", ba.take(i+1, X), -14, 14, 0.001); }; // relative to the exact value, so that make check (tolerance 1e-5) compares every point, whatever its magnitude
fexp_modulated_test = fa.fexp(28*tri - 14) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fexp_faster_test = fa.fexp_faster(2.3);
fexp_faster_slider_test = par(i, 6, fa.fexp_faster(xi(i))/exp(xi(i))) with { X = (-14.0, -1.0, 0.0, 0.5, 7.3, 14.0); xi(i) = hslider("fexp_faster:x%i", ba.take(i+1, X), -14, 14, 0.001); }; // relative to the exact value, so that make check (tolerance 1e-5) compares every point, whatever its magnitude
fexp_faster_modulated_test = fa.fexp_faster(28*tri - 14) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fexp10_test = fa.fexp10(1.3);
fexp10_slider_test = par(i, 6, fa.fexp10(xi(i))/pow(10.0, xi(i))) with { X = (-6.0, -0.5, 0.0, 0.3, 3.1, 6.0); xi(i) = hslider("fexp10:x%i", ba.take(i+1, X), -6, 6, 0.001); }; // relative to the exact value, so that make check (tolerance 1e-5) compares every point, whatever its magnitude
fexp10_modulated_test = fa.fexp10(12*tri - 6) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fdb2linear_test = fa.fdb2linear(-6.0);
fdb2linear_slider_test = par(i, 6, fa.fdb2linear(xi(i))/pow(10.0, xi(i)/20)) with { X = (-120.0, -60.0, -6.0, 0.0, 6.0, 24.0); xi(i) = hslider("fdb2linear:l%i", ba.take(i+1, X), -120, 24, 0.01); }; // relative to the exact value, so that make check (tolerance 1e-5) compares every point, whatever its magnitude
fdb2linear_modulated_test = fa.fdb2linear(144*tri - 120) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fdb2linear_faster_test = fa.fdb2linear_faster(-6.0);
fdb2linear_faster_slider_test = par(i, 6, fa.fdb2linear_faster(xi(i))/pow(10.0, xi(i)/20)) with { X = (-120.0, -60.0, -6.0, 0.0, 6.0, 24.0); xi(i) = hslider("fdb2linear_faster:l%i", ba.take(i+1, X), -120, 24, 0.01); }; // relative to the exact value, so that make check (tolerance 1e-5) compares every point, whatever its magnitude
fdb2linear_faster_modulated_test = fa.fdb2linear_faster(144*tri - 120) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
flog2_test = fa.flog2(7.3);
flog2_slider_test = par(i, 6, fa.flog2(hslider("flog2:x%i", ba.take(i+1, X), 1e-6, 1000, 1e-6))) with { X = (1e-6, 0.01, 0.5, 1.0, 7.3, 1000.0); };
flog2_modulated_test = fa.flog2(10.0^(9*tri - 6)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
flog2_faster_test = fa.flog2_faster(7.3);
flog2_faster_slider_test = par(i, 6, fa.flog2_faster(hslider("flog2_faster:x%i", ba.take(i+1, X), 1e-6, 1000, 1e-6))) with { X = (1e-6, 0.01, 0.5, 1.0, 7.3, 1000.0); };
flog2_faster_modulated_test = fa.flog2_faster(10.0^(9*tri - 6)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
flog2_sqrt_test = fa.flog2_sqrt(7.3);
flog2_sqrt_slider_test = par(i, 6, fa.flog2_sqrt(hslider("flog2_sqrt:x%i", ba.take(i+1, X), 1e-9, 1e9, 1e-9))) with { X = (1e-9, 0.001, 0.5, 1.0, 100.0, 1e9); };
flog2_sqrt_modulated_test = fa.flog2_sqrt(10.0^(18*tri - 9)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
flog_test = fa.flog(7.3);
flog_slider_test = par(i, 6, fa.flog(hslider("flog:x%i", ba.take(i+1, X), 1e-6, 1000, 1e-6))) with { X = (1e-6, 0.01, 0.5, 1.0, 7.3, 1000.0); };
flog_modulated_test = fa.flog(10.0^(9*tri - 6)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
flog10_test = fa.flog10(7.3);
flog10_slider_test = par(i, 6, fa.flog10(hslider("flog10:x%i", ba.take(i+1, X), 1e-6, 1000, 1e-6))) with { X = (1e-6, 0.01, 0.5, 1.0, 7.3, 1000.0); };
flog10_modulated_test = fa.flog10(10.0^(9*tri - 6)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
flinear2db_test = fa.flinear2db(0.5);
flinear2db_slider_test = par(i, 6, fa.flinear2db(hslider("flinear2db:x%i", ba.take(i+1, X), 1e-6, 1000, 1e-6))) with { X = (1e-6, 0.01, 0.5, 1.0, 7.3, 1000.0); };
flinear2db_modulated_test = fa.flinear2db(10.0^(9*tri - 6)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
flinear2db_faster_test = fa.flinear2db_faster(0.5);
flinear2db_faster_slider_test = par(i, 6, fa.flinear2db_faster(hslider("flinear2db_faster:x%i", ba.take(i+1, X), 1e-6, 1000, 1e-6))) with { X = (1e-6, 0.01, 0.5, 1.0, 7.3, 1000.0); };
flinear2db_faster_modulated_test = fa.flinear2db_faster(10.0^(9*tri - 6)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
flinear2db_sqrt_test = fa.flinear2db_sqrt(0.5);
flinear2db_sqrt_slider_test = par(i, 6, fa.flinear2db_sqrt(hslider("flinear2db_sqrt:x%i", ba.take(i+1, X), 1e-9, 1e9, 1e-9))) with { X = (1e-9, 0.001, 0.5, 1.0, 100.0, 1e9); };
flinear2db_sqrt_modulated_test = fa.flinear2db_sqrt(10.0^(18*tri - 9)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fpow_test = fa.fpow(2.7, 1.3);
fpow_slider_test = par(i, 4, fa.fpow(hslider("fpow:x%i", ba.take(i+1, X), 0.001, 100, 0.001), hslider("fpow:y%i", ba.take(i+1, Y), -3, 3, 0.001))) with { X = (0.001, 0.5, 2.7, 100.0); Y = (-3.0, 0.5, 1.3, 3.0); };
fpow_modulated_test = fa.fpow(10.0^(4*tri - 2), 6*tri - 3) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fsin2pi_test = fa.fsin2pi(0.1);
fsin2pi_slider_test = par(i, 6, fa.fsin2pi(hslider("fsin2pi:x%i", ba.take(i+1, X), -1000.5, 1000.5, 0.0001))) with { X = (-1000.5, -0.75, -0.1, 0.2, 0.7, 1000.3); };
fsin2pi_modulated_test = fa.fsin2pi(200*tri - 100) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fsin2pi_faster_test = fa.fsin2pi_faster(0.1);
fsin2pi_faster_slider_test = par(i, 6, fa.fsin2pi_faster(hslider("fsin2pi_faster:x%i", ba.take(i+1, X), -1000.5, 1000.5, 0.0001))) with { X = (-1000.5, -0.75, -0.1, 0.2, 0.7, 1000.3); };
fsin2pi_faster_modulated_test = fa.fsin2pi_faster(200*tri - 100) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fcos2pi_test = fa.fcos2pi(0.1);
fcos2pi_slider_test = par(i, 6, fa.fcos2pi(hslider("fcos2pi:x%i", ba.take(i+1, X), -1000.5, 1000.5, 0.0001))) with { X = (-1000.5, -0.75, -0.1, 0.2, 0.7, 1000.3); };
fcos2pi_modulated_test = fa.fcos2pi(200*tri - 100) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fsin_test = fa.fsin(0.7);
fsin_slider_test = par(i, 6, fa.fsin(hslider("fsin:x%i", ba.take(i+1, X), -1000, 1000, 0.001))) with { X = (-1000.0, -3.0, -0.1, 0.5, 3.0, 1000.0); };
fsin_modulated_test = fa.fsin(20*tri - 10) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fsin_faster_test = fa.fsin_faster(0.7);
fsin_faster_slider_test = par(i, 6, fa.fsin_faster(hslider("fsin_faster:x%i", ba.take(i+1, X), -1000, 1000, 0.001))) with { X = (-1000.0, -3.0, -0.1, 0.5, 3.0, 1000.0); };
fsin_faster_modulated_test = fa.fsin_faster(20*tri - 10) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fcos_test = fa.fcos(0.7);
fcos_slider_test = par(i, 6, fa.fcos(hslider("fcos:x%i", ba.take(i+1, X), -1000, 1000, 0.001))) with { X = (-1000.0, -3.0, -0.1, 0.5, 3.0, 1000.0); };
fcos_modulated_test = fa.fcos(20*tri - 10) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
ftanpi_test = fa.ftanpi(0.1);
ftanpi_slider_test = par(i, 6, fa.ftanpi(hslider("ftanpi:x%i", ba.take(i+1, X), -0.49, 0.49, 0.0001))) with { X = (-0.49, -0.25, 0.0, 0.1, 0.3, 0.49); };
ftanpi_modulated_test = fa.ftanpi(0.98*tri - 0.49) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
ftan_test = fa.ftan(0.7);
ftan_slider_test = par(i, 6, fa.ftan(hslider("ftan:x%i", ba.take(i+1, X), -1.5, 1.5, 0.001))) with { X = (-1.5, -0.7, 0.0, 0.3, 1.0, 1.5); };
ftan_modulated_test = fa.ftan(3*tri - 1.5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
ftanh_test = fa.ftanh(0.7);
ftanh_slider_test = par(i, 7, fa.ftanh(hslider("ftanh:x%i", ba.take(i+1, X), -20, 20, 0.001))) with { X = (-20.0, -2.0, -0.1, 0.0, 0.5, 3.0, 20.0); };
ftanh_modulated_test = fa.ftanh(10*tri - 5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
ftanh_faster_test = fa.ftanh_faster(0.7);
ftanh_faster_slider_test = par(i, 7, fa.ftanh_faster(hslider("ftanh_faster:x%i", ba.take(i+1, X), -20, 20, 0.001))) with { X = (-20.0, -2.0, -0.1, 0.0, 0.5, 3.0, 20.0); };
ftanh_faster_modulated_test = fa.ftanh_faster(10*tri - 5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
