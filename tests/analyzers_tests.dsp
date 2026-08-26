//----------------------------------------------------------------------------
// analyzers_tests.dsp
// Tests for analyzer helper functions.
//----------------------------------------------------------------------------

an = library("analyzers.lib");
ba = library("basics.lib");
ma = library("maths.lib");
os = library("oscillators.lib");
si = library("signals.lib");

mono = os.osc(220);
rich = os.osc(440) + os.osc(880);

abs_envelope_rect_test = an.abs_envelope_rect(0.05, mono);
abs_envelope_tau_test = an.abs_envelope_tau(0.05, mono);
abs_envelope_t60_test = an.abs_envelope_t60(0.05, mono);
abs_envelope_t19_test = an.abs_envelope_t19(0.05, mono);

amp_follower_test = mono : an.amp_follower(0.05);
amp_follower_ud_test = mono : an.amp_follower_ud(0.002, 0.05);
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
spectralCentroid_test = rich : an.spectralCentroid(1, 0.01);

mth_octave_analyzer_test = mono : an.mth_octave_analyzer(3, 3, 8000, 5);
mth_octave_spectral_level6e_test = mono : an.mth_octave_spectral_level6e(3, 8000, 5, 0.05, 0);
analyzer_test = mono : an.analyzer(3, (500, 2000));

goertzelOpt_test = an.goertzelOpt(440, 128, os.osc(440));
goertzelComp_test = an.goertzelComp(440, 128, os.osc(440));
goertzel_test = an.goertzel(440, 128, os.osc(440));

resonator_test = mono : an.resonator(2, 440);

fft_test = an.rtocv(8, mono) : an.fft(8);
ifft_test = (an.rtocv(8, mono) : an.fft(8)) : an.ifft(8);

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
window_kaiser_test = an.window_kaiser(8.6, os.lf_sawpos(100));

// Loudness metering (EBU R128 / ITU-R BS.1770)
loudness_momentary_test = os.osc(997), os.osc(997) : an.loudness_momentary(2);
loudness_shortterm_test = os.osc(997), os.osc(997) : an.loudness_shortterm(2);
loudness_integrated_test = os.osc(997), os.osc(997) : an.loudness_integrated(2);
true_peak_test = os.osc(12000)*0.97 : an.true_peak;

// Spectral descriptors (filter-bank based)
spectral_centroid_test = os.osc(1000) : an.spectral_centroid(3, 1, 8000, 6, 0.1);
spectral_spread_test = os.osc(800) + os.osc(5000) : an.spectral_spread(3, 1, 8000, 6, 0.1);
spectral_flux_test = os.osc(1000) * ((ba.time % 24000) > 12000) : an.spectral_flux(3, 1, 8000, 6, 0.02);
