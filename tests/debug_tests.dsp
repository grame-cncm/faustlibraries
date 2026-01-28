//----------------------------------------------------------------------------
// debug_tests.dsp
// Tests for debug probe functions.
//----------------------------------------------------------------------------

db = library("debug.lib");
os = library("oscillators.lib");
fi = library("filters.lib");

mono = os.osc(220);

probe_rms_db_test = db.probe_rms_db(0, 1, mono);
probe_rms_lin_test = db.probe_rms_lin(1, 1, mono);
probe_peak_db_test = db.probe_peak_db(2, 1, mono);
probe_peak_lin_test = db.probe_peak_lin(3, 1, mono);
probe_crest_db_test = db.probe_crest_db(4, 1, mono);
probe_env_test = db.probe_env(5, 1, mono);
probe_min_test = db.probe_min(6, 1, mono);
probe_max_test = db.probe_max(7, 1, mono);
probe_dc_test = db.probe_dc(8, 1, mono);
probe_slew_test = db.probe_slew(9, 1, mono);
probe_zcr_test = db.probe_zcr(10, 1, mono);
probe_value_test = db.probe_value(11, 1, mono);
probe_bool_test = db.probe_bool(12, 1, mono > 0);
probe_band_lo_test = db.probe_band_lo(13, 1, mono);
probe_band_mid_test = db.probe_band_mid(14, 1, mono);
probe_band_hi_test = db.probe_band_hi(15, 1, mono);
probe_tap_test = db.probe_tap(db.probe_rms_db(16, 1), mono);
probe_tap_n_test = probe_tap_n_example;

probe_disabled_rms_db_test = db[DEBUG=0;].probe_rms_db(17, 1, mono);
probe_disabled_rms_lin_test = db[DEBUG=0;].probe_rms_lin(18, 1, mono);
probe_disabled_peak_db_test = db[DEBUG=0;].probe_peak_db(19, 1, mono);
probe_disabled_peak_lin_test = db[DEBUG=0;].probe_peak_lin(20, 1, mono);
probe_disabled_crest_db_test = db[DEBUG=0;].probe_crest_db(21, 1, mono);
probe_disabled_env_test = db[DEBUG=0;].probe_env(22, 1, mono);
probe_disabled_min_test = db[DEBUG=0;].probe_min(23, 1, mono);
probe_disabled_max_test = db[DEBUG=0;].probe_max(24, 1, mono);
probe_disabled_dc_test = db[DEBUG=0;].probe_dc(25, 1, mono);
probe_disabled_slew_test = db[DEBUG=0;].probe_slew(26, 1, mono);
probe_disabled_zcr_test = db[DEBUG=0;].probe_zcr(27, 1, mono);
probe_disabled_value_test = db[DEBUG=0;].probe_value(28, 1, mono);
probe_disabled_bool_test = db[DEBUG=0;].probe_bool(29, 1, mono > 0);
probe_disabled_band_lo_test = db[DEBUG=0;].probe_band_lo(30, 1, mono);
probe_disabled_band_mid_test = db[DEBUG=0;].probe_band_mid(31, 1, mono);
probe_disabled_band_hi_test = db[DEBUG=0;].probe_band_hi(32, 1, mono);
probe_disabled_tap_test = db[DEBUG=0;].probe_tap(db.probe_rms_db(33, 1), mono);
probe_disabled_tap_n_test = probe_tap_n_disabled_example;

probe_freq_lin_test = db.probe_freq_lin(34, 1, 440, 10, mono);
probe_freq_db_test = db.probe_freq_db(35, 1, 440, 10, mono);
probe_freq_ratio_test = db.probe_freq_ratio(36, 1, 440, 660, 12, mono);
probe_env_lin_test = db.probe_env_lin(37, 1, 0.001, 0.1, mono);
probe_env_db_test = db.probe_env_db(38, 1, 0.001, 0.1, mono);
probe_peak_hold_test = db.probe_peak_hold(39, 1, 2.0, mono);
probe_below_threshold_test = db.probe_below_threshold(40, 1, -40, mono);
probe_attack_state_test = db.probe_attack_state(41, 1, -60, mono);
probe_onset_test = db.probe_onset(42, 1, -40, 50, mono);
probe_spectral_centroid_test = db.probe_spectral_centroid(43, 1, mono);
probe_multiband_test = db.probe_multiband(44, 1, mono);
probe_dc_precise_test = db.probe_dc_precise(56, 1, mono);
probe_silence_test = db.probe_silence(57, 1, -60, mono);
probe_sample_count_test = db.probe_sample_count(58, 1, mono);
probe_time_ms_test = db.probe_time_ms(59, 1, mono);

probe_disabled_freq_lin_test = db[DEBUG=0;].probe_freq_lin(120, 1, 440, 10, mono);
probe_disabled_freq_db_test = db[DEBUG=0;].probe_freq_db(121, 1, 440, 10, mono);
probe_disabled_freq_ratio_test = db[DEBUG=0;].probe_freq_ratio(122, 1, 440, 660, 12, mono);
probe_disabled_env_lin_test = db[DEBUG=0;].probe_env_lin(123, 1, 0.001, 0.1, mono);
probe_disabled_env_db_test = db[DEBUG=0;].probe_env_db(124, 1, 0.001, 0.1, mono);
probe_disabled_peak_hold_test = db[DEBUG=0;].probe_peak_hold(125, 1, 2.0, mono);
probe_disabled_below_threshold_test = db[DEBUG=0;].probe_below_threshold(126, 1, -40, mono);
probe_disabled_attack_state_test = db[DEBUG=0;].probe_attack_state(127, 1, -60, mono);
probe_disabled_onset_test = db[DEBUG=0;].probe_onset(128, 1, -40, 50, mono);
probe_disabled_spectral_centroid_test = db[DEBUG=0;].probe_spectral_centroid(129, 1, mono);
probe_disabled_multiband_test = db[DEBUG=0;].probe_multiband(130, 1, mono);
probe_disabled_dc_precise_test = db[DEBUG=0;].probe_dc_precise(142, 1, mono);
probe_disabled_silence_test = db[DEBUG=0;].probe_silence(143, 1, -60, mono);
probe_disabled_sample_count_test = db[DEBUG=0;].probe_sample_count(144, 1, mono);
probe_disabled_time_ms_test = db[DEBUG=0;].probe_time_ms(145, 1, mono);

// Example pulled from debug.lib documentation.
left = os.osc(220) : fi.lowpass(2, 1200);
right = os.osc(330) : fi.highpass(2, 400);
stereo = (left, right)
  : (fi.lowpass(2, 2000), fi.highpass(2, 700));
probe_tap_n_example = stereo
  : db.probe_tap_n(2, + : db.probe_rms_db(100, 1))
  : (fi.lowpass(2, 8000), fi.lowpass(2, 8000));
probe_tap_n_disabled_example = stereo
  : db[DEBUG=0;].probe_tap_n(2, + : db.probe_rms_db(101, 1))
  : (fi.lowpass(2, 8000), fi.lowpass(2, 8000));
