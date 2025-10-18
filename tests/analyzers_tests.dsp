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
