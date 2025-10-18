//----------------------------------------------------------------------------
// filters_analog_sections_tests.dsp
// Tests for analog-transfer filter sections.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
ma = library("maths.lib");

src = os.osc(440);

tf2s_test = src : fi.tf2s(0, 0, 1, sqrt(2), 1, ma.PI*ma.SR/2);
tf2snp_test = src : fi.tf2snp(0, 0, 1, sqrt(2), 1, ma.PI*ma.SR/2);
tf1snp_test = src : fi.tf1snp(0, 1, 1, ma.PI*ma.SR/2);
tf3slf_test = src : fi.tf3slf(0, 0, 0, 1, 1, 2, 2, 1);
tf1s_test = src : fi.tf1s(0, 1, 1, ma.PI*ma.SR/2);
tf2sb_test = src : fi.tf2sb(0, 0, 1, sqrt(2), 1, 2*ma.PI*200, 2*ma.PI*1000);
tf1sb_test = src : fi.tf1sb(0, 1, 1, 2*ma.PI*200, 2*ma.PI*1000);
