//----------------------------------------------------------------------------
// filters_direct_ladder_tests.dsp
// Tests for direct-form and ladder filters.
//----------------------------------------------------------------------------

ba = library("basics.lib");
fi = library("filters.lib");
os = library("oscillators.lib");
si = library("signals.lib");

src = os.osc(440);

iir_test = src : fi.iir((0.5, 0.5), (0.3));
fir_test = src : fi.fir((0.2, 0.2, 0.2, 0.2, 0.2));
convN_test = (src <: si.bus(3)) : fi.convN(3, (0.3, 0.2, 0.1, 0.05));
conv_test = src : fi.conv((0.25, 0.25, 0.25, 0.25));

tf1_test = src : fi.tf1(0.5, 0.25, -0.4);
tf2_test = src : fi.tf2(0.1, 0.2, 0.1, -0.5, 0.06);
tf3_test = src : fi.tf3(0.1, 0.3, 0.3, 0.1, -0.9, 0.26, -0.024);
notchw_test = src : fi.notchw(200, 1000);

tf21_test = src : fi.tf21(0.1, 0.2, 0.1, -0.5, 0.06);
tf22_test = src : fi.tf22(0.1, 0.2, 0.1, -0.5, 0.06);
tf22t_test = src : fi.tf22t(0.1, 0.2, 0.1, -0.5, 0.06);
tf21t_test = src : fi.tf21t(0.1, 0.2, 0.1, -0.5, 0.06);

av2sv_test = fi.av2sv((-0.4, 0.1)) : si.bus(2);
bvav2nuv_test = fi.bvav2nuv((0.1, 0.2, 0.3), (-0.4, 0.1)) : si.bus(3);

iir_lat2_test = src : fi.iir_lat2((0.1, 0.2, 0.3), (-0.4, 0.1));
allpassnt_test = src : fi.allpassnt(2, (0.3, -0.2)) : si.bus(3);
iir_kl_test = src : fi.iir_kl((0.1, 0.2, 0.3), (-0.4, 0.1));
allpassnklt_test = src : fi.allpassnklt(2, (0.3, -0.2)) : si.bus(3);
iir_lat1_test = src : fi.iir_lat1((0.1, 0.2, 0.3), (-0.4, 0.1));
allpassn1mt_test = src : fi.allpassn1mt(2, (0.3, -0.2)) : si.bus(3);
iir_nl_test = src : fi.iir_nl((0.1, 0.2, 0.3), (-0.4, 0.1));
allpassnnlt_test = src : fi.allpassnnlt(2, (0.3, -0.2)) : si.bus(3);
