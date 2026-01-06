//----------------------------------------------------------------------------
// debug_tests.dsp
// Tests for debug probe functions.
//----------------------------------------------------------------------------

db = library("debug.lib");
os = library("oscillators.lib");

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

probe_disabled_rms_db_test = db[DEBUG=0;].probe_rms_db(16, 1, mono);
probe_disabled_rms_lin_test = db[DEBUG=0;].probe_rms_lin(17, 1, mono);
probe_disabled_peak_db_test = db[DEBUG=0;].probe_peak_db(18, 1, mono);
probe_disabled_peak_lin_test = db[DEBUG=0;].probe_peak_lin(19, 1, mono);
probe_disabled_crest_db_test = db[DEBUG=0;].probe_crest_db(20, 1, mono);
probe_disabled_env_test = db[DEBUG=0;].probe_env(21, 1, mono);
probe_disabled_min_test = db[DEBUG=0;].probe_min(22, 1, mono);
probe_disabled_max_test = db[DEBUG=0;].probe_max(23, 1, mono);
probe_disabled_dc_test = db[DEBUG=0;].probe_dc(24, 1, mono);
probe_disabled_slew_test = db[DEBUG=0;].probe_slew(25, 1, mono);
probe_disabled_zcr_test = db[DEBUG=0;].probe_zcr(26, 1, mono);
probe_disabled_value_test = db[DEBUG=0;].probe_value(27, 1, mono);
probe_disabled_bool_test = db[DEBUG=0;].probe_bool(28, 1, mono > 0);
probe_disabled_band_lo_test = db[DEBUG=0;].probe_band_lo(29, 1, mono);
probe_disabled_band_mid_test = db[DEBUG=0;].probe_band_mid(30, 1, mono);
probe_disabled_band_hi_test = db[DEBUG=0;].probe_band_hi(31, 1, mono);
