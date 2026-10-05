//----------------------------------------------------------------------------
// filters_filterbank_tests.dsp
// Tests for arbitrary crossover filter bank helpers.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");
ma = library("maths.lib");

src = os.tosc(440);

filterbank_test = src : fi.filterbank(3, (500, 2000));
filterbanki_test = src : fi.filterbanki(3, (500, 2000));
filterbanki_o5_sum_test = no.noise : fi.filterbanki(5, (500, 1000, 2000)) :> _;
filterbank_tpt_df_test = no.noise : fi.filterbank_tpt_df(fi.tpt_df_fmin, 3, (50, 500, 4000));
filterbank_tpt_df_o5_sum_test = no.noise : fi.filterbank_tpt_df(fi.tpt_df_fmin, 5, (50, 500, 4000)) :> _;
filterbank_tpt_df_slider_test = no.noise : fi.filterbank_tpt_df(fi.tpt_df_fmin, 3, (hslider("f1", 500, 20, 10000, 1), hslider("f2", 4000, 20, 20000, 1)));
filterbank_tpt_df_modulated_test = no.noise : fi.filterbank_tpt_df(0, 3, (f1, 4*f1)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); f1 = 2500*pow(2, tri); };
filterbank_tpt_df_jump_test = no.noise : fi.filterbank_tpt_df(ma.MAX, 3, (f1, 4*f1)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; f1 = 100*pow(10, sq); };
filterbanki_tpt_df_test = no.noise : fi.filterbanki_tpt_df(fi.tpt_df_fmin, 3, (50, 500, 4000));
filterbanki_tpt_df_o5_sum_test = no.noise : fi.filterbanki_tpt_df(fi.tpt_df_fmin, 5, (50, 500, 4000)) :> _;
filterbanki_tpt_df_slider_test = no.noise : fi.filterbanki_tpt_df(fi.tpt_df_fmin, 3, (hslider("f1", 500, 20, 10000, 1), hslider("f2", 4000, 20, 20000, 1)));
filterbanki_tpt_df_modulated_test = no.noise : fi.filterbanki_tpt_df(0, 3, (f1, 4*f1)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); f1 = 2500*pow(2, tri); };
filterbanki_tpt_df_jump_test = no.noise : fi.filterbanki_tpt_df(ma.MAX, 3, (f1, 4*f1)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; f1 = 100*pow(10, sq); };
