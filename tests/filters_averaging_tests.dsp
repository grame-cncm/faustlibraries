//----------------------------------------------------------------------------
// filters_averaging_tests.dsp
// Tests of filters.lib.
//----------------------------------------------------------------------------

ba = library("basics.lib");
fi = library("filters.lib");
no = library("noises.lib");
ma = library("maths.lib");

avg_rect_test = no.noise : fi.avg_rect(0.01);
avg_rect_slider_test = no.noise : fi.avg_rect(hslider("period", 0.01, 0.001, 0.1, 0.001));
avg_rect_modulated_test = no.noise : fi.avg_rect(0.001 + 0.019*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1) : max(0) : min(1); };
avg_tau_test = no.noise : fi.avg_tau(0.01);
avg_tau_slider_test = no.noise : fi.avg_tau(hslider("period", 0.01, 0.001, 0.1, 0.001));
avg_tau_modulated_test = no.noise : fi.avg_tau(0.001 + 0.019*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
avg_t60_test = no.noise : fi.avg_t60(0.01);
avg_t60_slider_test = no.noise : fi.avg_t60(hslider("period", 0.01, 0.001, 0.1, 0.001));
avg_t60_modulated_test = no.noise : fi.avg_t60(0.001 + 0.019*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
avg_t19_test = no.noise : fi.avg_t19(0.01);
avg_t19_slider_test = no.noise : fi.avg_t19(hslider("period", 0.01, 0.001, 0.1, 0.001));
avg_t19_modulated_test = no.noise : fi.avg_t19(0.001 + 0.019*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
