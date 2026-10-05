//----------------------------------------------------------------------------
// analyzers_tests.dsp
// Tests for analyzer helper functions.
//----------------------------------------------------------------------------

an = library("analyzers.lib");
ba = library("basics.lib");
fi = library("filters.lib");
ma = library("maths.lib");
os = library("oscillators.lib");
si = library("signals.lib");
no = library("noises.lib");

mono = os.tosc(220);
rich = os.tosc(440) + os.tosc(880);

abs_envelope_rect_test = an.abs_envelope_rect(0.05, mono);
abs_envelope_tau_test = an.abs_envelope_tau(0.05, mono);
abs_envelope_t60_test = an.abs_envelope_t60(0.05, mono);
abs_envelope_t19_test = an.abs_envelope_t19(0.05, mono);

amp_follower_test = mono : an.amp_follower(0.05);
amp_follower_slider_test = no.noise*pow(0.001, float(ba.period(Q))/Q) : an.amp_follower(hslider("amp_follower:rel", 0.05, 0.001, 1, 0.001)) with { Q = int(ma.SR/4); };
amp_follower_modulated_test = no.noise*pow(0.001, float(ba.period(Q))/Q) : an.amp_follower(0.001*pow(1000, tri)) with { Q = int(ma.SR/4); P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
amp_follower_jump_test = no.noise*pow(0.001, float(ba.period(Q))/Q) : an.amp_follower(0.001*pow(1000, sq)) with { Q = int(ma.SR/4); P = int(ma.SR/10); sq = ba.period(2*P) < P; };
amp_follower_ud_test = mono : an.amp_follower_ud(0.002, 0.05);
amp_follower_ud_slider_test = no.noise*pow(0.001, float(ba.period(Q))/Q) : an.amp_follower_ud(hslider("amp_follower_ud:att", 0.002, 0.0001, 0.01, 0.0001), hslider("amp_follower_ud:rel", 0.05, 0.01, 1, 0.001)) with { Q = int(ma.SR/4); };
amp_follower_ud_modulated_test = no.noise*pow(0.001, float(ba.period(Q))/Q) : an.amp_follower_ud(0.0005*pow(20, tri), 0.05) with { Q = int(ma.SR/4); P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
amp_follower_ud_jump_test = no.noise*pow(0.001, float(ba.period(Q))/Q) : an.amp_follower_ud(0.0005*pow(20, sq), 0.05) with { Q = int(ma.SR/4); P = int(ma.SR/10); sq = ba.period(2*P) < P; };
amp_follower_ar_test = mono : an.amp_follower_ar(0.002, 0.05);

ms_envelope_rect_test = an.ms_envelope_rect(0.05, mono);
ms_envelope_tau_test = an.ms_envelope_tau(0.05, mono);
ms_envelope_t60_test = an.ms_envelope_t60(0.05, mono);
ms_envelope_t19_test = an.ms_envelope_t19(0.05, mono);

rms_envelope_rect_test = an.rms_envelope_rect(0.05, mono);
rms_envelope_tau_test = an.rms_envelope_tau(0.05, mono);
rms_envelope_t60_test = an.rms_envelope_t60(0.05, mono);
rms_envelope_t19_test = an.rms_envelope_t19(0.05, mono);

zcr_test = an.zcr(0.01, mono);
pitchTracker_test = an.pitchTracker(4, 0.02, mono);
pitchTracker_slider_test = an.pitchTracker(4, hslider("pitchTracker:tau", 0.02, 0.001, 1, 0.001), os.tosc(220));
spectralCentroid_test = rich : an.spectralCentroid(1, 0.01);
spectralCentroid_slider_test = os.tosc(440) + os.tosc(880) : an.spectralCentroid(1, hslider("spectralCentroid:tau", 0.01, 0.001, 1, 0.001));

mth_octave_analyzer_test = mono : an.mth_octave_analyzer(3, 3, 8000, 5);
mth_octave_spectral_level6e_test = mono : an.mth_octave_spectral_level6e(3, 8000, 5, 0.05, 0);
analyzer_test = mono : an.analyzer(3, (500, 2000));

goertzelOpt_test = an.goertzelOpt(440, 128, os.tosc(440));
goertzelComp_test = an.goertzelComp(440, 128, os.tosc(440));
goertzel_test = an.goertzel(440, 128, os.tosc(440));

resonator_test = mono : an.resonator(2, 440);
resonator_slider_test = os.tosc(220) : an.resonator(2, hslider("resonator:f", 440, 20, 5000, 1)) : _, !;
resonator_modulated_test = no.noise : an.resonator(2, 20*pow(250, tri)) : _, ! with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
resonator_jump_test = no.noise : an.resonator(2, 20*pow(250, sq)) : _, ! with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };

fft_test = an.rtocv(8, mono) : an.fft(8);
ifft_test = (an.rtocv(8, mono) : an.fft(8)) : an.ifft(8);
rfft_analyzer_db_test = 2 * ba.pulse(8) + 0.5 * ba.pulse(4) : an.rfft_analyzer_db(8); // bins of 3 and 2: 9.54 and 6.02 dB
rfft_analyzer_c_test = no.noise : an.rfft_analyzer_c(8);
rfft_analyzer_magsq_test = no.noise : an.rfft_analyzer_magsq(8);
rfft_analyzer_c_chrono_test = no.noise : an.rfft_analyzer_c_chrono(8);

logsweep_test = an.logsweep(20, 2000, 5);
linsweep_test = an.linsweep(20, 2000, 5);

// Window functions (continuous, evaluated on a 100 Hz phase ramp)
window_rect_test = an.window_rect(os.lf_sawpos(100));
window_hann_test = an.window_hann(os.lf_sawpos(100));
window_hamming_test = an.window_hamming(os.lf_sawpos(100));
window_blackman_test = an.window_blackman(os.lf_sawpos(100));
window_blackman_harris_test = an.window_blackman_harris(os.lf_sawpos(100));
window_nuttall_test = an.window_nuttall(os.lf_sawpos(100));
window_flattop_test = an.window_flattop(os.lf_sawpos(100));
window_bartlett_test = an.window_bartlett(os.lf_sawpos(100));
window_cosN_test = an.window_cosN((0.5, -0.5), os.lf_sawpos(100));
window_tukey_test = an.window_tukey(0.5, os.lf_sawpos(100));
window_tukey_rect_test = an.window_tukey(0, os.lf_sawpos(100));
window_kaiser_test = an.window_kaiser(8.6, os.lf_sawpos(100));
rtocv_test = an.rtocv(8, os.tosc(220));
rtorv_test = an.rtorv(4, no.noise);
rtorv_chrono_test = an.rtorv_chrono(4, no.noise);
rtocv_chrono_test = an.rtocv_chrono(8, no.noise);
rtocv_chrono_ifft_test = an.rtocv_chrono(8, no.noise) : an.fft(8) : an.ifft(8) : par(i, 8, (_, !));

// Loudness metering (EBU R128 / ITU-R BS.1770)
loudness_momentary_test = os.tosc(997), os.tosc(997) : an.loudness_momentary(2);
loudness_shortterm_test = os.tosc(997), os.tosc(997) : an.loudness_shortterm(2);
loudness_integrated_test = os.tosc(997), os.tosc(997) : an.loudness_integrated(2);
true_peak_test = os.tosc(12000)*0.97 : an.true_peak;

// Spectral descriptors (filter-bank based)
spectral_centroid_test = os.tosc(1000) : an.spectral_centroid(3, 1, 8000, 6, 0.1);
spectral_spread_test = os.tosc(800) + os.tosc(5000) : an.spectral_spread(3, 1, 8000, 6, 0.1);
spectral_flux_test = os.tosc(1000) * ((ba.time % 24000) > 12000) : an.spectral_flux(3, 1, 8000, 6, 0.02);
octave_filterbank_test = os.tosc(440) : an.octave_filterbank(5);
half_octave_filterbank_test = os.tosc(440) : an.half_octave_filterbank(6);
third_octave_filterbank_test = os.tosc(440) : an.third_octave_filterbank(8);
spectral_level_test = os.tosc(220) : an.spectral_level(0.05, 0);
mth_octave_analyzer_tpt_df_test = no.noise : an.mth_octave_analyzer_tpt_df(fi.tpt_df_fmin, 5, 2, 10000, 12);
mth_octave_analyzer6e_tpt_df_test = no.noise : an.mth_octave_analyzer6e_tpt_df(fi.tpt_df_fmin, 2, 10000, 12);
analyzer_tpt_df_test = no.noise : an.analyzer_tpt_df(fi.tpt_df_fmin, 3, (50, 500, 4000));
analyzer_tpt_df_slider_test = no.noise : an.analyzer_tpt_df(fi.tpt_df_fmin, 3, (hslider("f1", 500, 20, 10000, 1), hslider("f2", 4000, 20, 20000, 1)));
analyzer_tpt_df_modulated_test = no.noise : an.analyzer_tpt_df(0, 3, (f1, 4*f1)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); f1 = 2500*pow(2, tri); };
analyzer_tpt_df_jump_test = no.noise : an.analyzer_tpt_df(ma.MAX, 3, (f1, 4*f1)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; f1 = 100*pow(10, sq); };
