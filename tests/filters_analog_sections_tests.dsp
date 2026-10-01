//----------------------------------------------------------------------------
// filters_analog_sections_tests.dsp
// Tests for analog-transfer filter sections.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
ma = library("maths.lib");
no = library("noises.lib");
ba = library("basics.lib");

src = os.tosc(440);

tf2s_test = src : fi.tf2s(0, 0, 1, sqrt(2), 1, ma.PI*ma.SR/2);
tf2snp_test = src : fi.tf2snp(0, 0, 1, sqrt(2), 1, ma.PI*ma.SR/2);
tf2snp_lowfc_test = no.noise : fi.tf2snp(0, 0, 1, sqrt(2), 1, 2*ma.PI*20);
tf2snp_hp_lowfc_test = no.noise : fi.tf2snp(1, 0, 0, sqrt(2), 1, 2*ma.PI*10.1);
tf1snp_test = src : fi.tf1snp(0, 1, 1, ma.PI*ma.SR/2);
tf1snp_lowfc_test = no.noise : fi.tf1snp(0, 1, 1, 2*ma.PI*10.1);
tf1snp_slider_test = no.noise : fi.tf1snp(0, 1, 1, 2*ma.PI*hslider("fc", 1000, 20, 20000, 1));
tf1snp_modulated_test = no.noise : fi.tf1snp(0, 1, 1, 2*ma.PI*20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
tf1snp_jump_test = no.noise : fi.tf1snp(0, 1, 1, 2*ma.PI*20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
tf3slf_test = src : fi.tf3slf(0, 0, 0, 1, 1, 2, 2, 1);
tf1s_test = src : fi.tf1s(0, 1, 1, ma.PI*ma.SR/2);
tf1s_slider_test = no.noise : fi.tf1s(0, 1, 1, 2*ma.PI*hslider("fc", 1000, 20, 20000, 1));
tf1s_modulated_test = no.noise : fi.tf1s(0, 1, 1, 2*ma.PI*20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
tf1s_jump_test = no.noise : fi.tf1s(0, 1, 1, 2*ma.PI*20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
tf1s_zero_freq_test = no.noise : fi.tf1s(1, 0, 1, 2*ma.PI*1000*(ba.time >= 100));
tf2sb_test = src : fi.tf2sb(0, 0, 1, sqrt(2), 1, 2*ma.PI*200, 2*ma.PI*1000);
tf2sb_slider_test = no.noise : fi.tf2sb(0, 0, 1, sqrt(2), 1, 2*ma.PI*hslider("bw", 800, 10, 10000, 1), 2*ma.PI*hslider("fc", 1000, 20, 20000, 1));
tf2sb_modulated_test = no.noise : fi.tf2sb(0, 0, 1, sqrt(2), 1, 2*ma.PI*fc/5, 2*ma.PI*fc) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); fc = 20*pow(250, tri); };
tf2sb_jump_test = no.noise : fi.tf2sb(0, 0, 1, sqrt(2), 1, 2*ma.PI*fc/5, 2*ma.PI*fc) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; fc = 20*pow(250, sq); };
tf1sb_test = src : fi.tf1sb(0, 1, 1, 2*ma.PI*200, 2*ma.PI*1000);
tf1sb_slider_test = no.noise : fi.tf1sb(0, 1, 1, 2*ma.PI*hslider("bw", 800, 10, 10000, 1), 2*ma.PI*hslider("fc", 1000, 20, 20000, 1));
tf1sb_modulated_test = no.noise : fi.tf1sb(0, 1, 1, 2*ma.PI*fc/5, 2*ma.PI*fc) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); fc = 20*pow(250, tri); };
tf1sb_jump_test = no.noise : fi.tf1sb(0, 1, 1, 2*ma.PI*fc/5, 2*ma.PI*fc) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; fc = 20*pow(250, sq); };
