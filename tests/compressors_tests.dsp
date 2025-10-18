//----------------------------------------------------------------------------
// compressors_tests.dsp
// Tests for compressor helper functions.
//----------------------------------------------------------------------------

co = library("compressors.lib");
os = library("oscillators.lib");

meter(x) = x;
meterLim(x) = x;
SCfunction(x) = x;

ratio2strength_test = co.ratio2strength(4);
strength2ratio_test = co.strength2ratio(0.75);
peak_compression_gain_mono_db_test = os.osc(440) : co.peak_compression_gain_mono_db(0.5, -12, 0.01, 0.1, 6, 0);
peak_compression_gain_N_chan_db_test = (os.osc(440), os.osc(660)) : co.peak_compression_gain_N_chan_db(0.5, -12, 0.01, 0.1, 6, 0, 0.5, 2);
FFcompressor_N_chan_test = (os.osc(440), os.osc(660)) : co.FFcompressor_N_chan(0.5, -12, 0.01, 0.1, 6, 0, 0.5, meter, 2);
FBcompressor_N_chan_test = (os.osc(440), os.osc(660)) : co.FBcompressor_N_chan(0.5, -12, 0.01, 0.1, 6, 0, 0.5, meter, 2);
FBFFcompressor_N_chan_test = (os.osc(440), os.osc(660)) : co.FBFFcompressor_N_chan(0.4, -12, 0.01, 0.1, 6, 0, 0.5, 0.3, meter, 2);
RMS_compression_gain_mono_db_test = os.osc(330) : co.RMS_compression_gain_mono_db(0.5, -18, 0.02, 0.12, 6, 0);
RMS_compression_gain_N_chan_db_test = (os.osc(330), os.osc(550)) : co.RMS_compression_gain_N_chan_db(0.5, -18, 0.02, 0.12, 6, 0, 0.5, 2);
RMS_FBFFcompressor_N_chan_test = (os.osc(330), os.osc(550)) : co.RMS_FBFFcompressor_N_chan(0.4, -18, 0.02, 0.12, 6, 0, 0.5, 0.3, meter, 2);
RMS_FBcompressor_peak_limiter_N_chan_test = (os.osc(330), os.osc(550)) : co.RMS_FBcompressor_peak_limiter_N_chan(0.4, -18, -2, 0.02, 0.12, 6, 0.5, meter, meterLim, 2);
peak_compression_gain_mono_test = os.osc(440) : co.peak_compression_gain_mono(0.5, -12, 0.01, 0.1, 6, 0);
peak_compression_gain_N_chan_test = (os.osc(440), os.osc(660)) : co.peak_compression_gain_N_chan(0.5, -12, 0.01, 0.1, 6, 0, 0.5, 2);
RMS_compression_gain_mono_test = os.osc(330) : co.RMS_compression_gain_mono(0.5, -18, 0.02, 0.12, 6, 0);
RMS_compression_gain_N_chan_test = (os.osc(330), os.osc(550)) : co.RMS_compression_gain_N_chan(0.5, -18, 0.02, 0.12, 6, 0, 0.5, 2);
compressor_lad_mono_test = os.osc(440) : co.compressor_lad_mono(0.005, 4, -9, 0.01, 0.1);
compressor_mono_test = os.osc(440) : co.compressor_mono(4, -9, 0.01, 0.2);
compressor_stereo_test = (os.osc(440), os.osc(660)) : co.compressor_stereo(4, -9, 0.01, 0.2);
compression_gain_mono_test = os.osc(440) : co.compression_gain_mono(4, -9, 0.01, 0.2);
limiter_1176_R4_mono_test = os.osc(440) : co.limiter_1176_R4_mono;
limiter_1176_R4_stereo_test = (os.osc(440), os.osc(660)) : co.limiter_1176_R4_stereo;
peak_expansion_gain_N_chan_db_test = (os.osc(220), os.osc(330)) : co.peak_expansion_gain_N_chan_db(0.5, -40, 20, 0.05, 0.01, 0.2, 6, 0, 0.5, 2048, 2);
expander_N_chan_test = (os.osc(220), os.osc(330)) : co.expander_N_chan(0.5, -40, 20, 0.05, 0.02, 0.2, 6, 0, 0.5, meter, 4096, 2);
expanderSC_N_chan_test = (os.osc(220), os.osc(330)) : co.expanderSC_N_chan(0.5, -40, 20, 0.05, 0.02, 0.2, 6, 0, 0.5, meter, 4096, 2, SCfunction, 1, os.osc(880));
limiter_lad_N_test = (os.osc(440), os.osc(660)) : co.limiter_lad_N(2, 0.01, 1, 0.01, 0.05, 0.2);
limiter_lad_mono_test = os.osc(440) : co.limiter_lad_mono(0.01, 1, 0.01, 0.05, 0.2);
limiter_lad_stereo_test = (os.osc(440), os.osc(660)) : co.limiter_lad_stereo(0.01, 1, 0.01, 0.05, 0.2);
limiter_lad_quad_test = (os.osc(220), os.osc(330), os.osc(440), os.osc(550)) : co.limiter_lad_quad(0.01, 1, 0.01, 0.05, 0.2);
limiter_lad_bw_test = os.osc(440) : co.limiter_lad_bw;
