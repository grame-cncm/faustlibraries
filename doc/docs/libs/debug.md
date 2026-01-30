#  debug.lib 

Debug library. Its official prefix is `db`.

This library provides UI-based debug probes for metering and diagnostics.
It includes RMS/Peak meters, dynamics probes, signal quality probes, and
simple band-energy meters.

Debug probes can be compiled out by setting the `DEBUG` global to 0 via
explicit substitution (e.g. `db[DEBUG=0;].probe_rms_db(...)`).
CNE means constant numerical expression (known at compile time).
`[probe:ID]` metadata tags are used to identify probes in the UI

The Debug library is organized into 11 sections:

* [Level Probes](#level-probes)
* [Dynamics Probes](#dynamics-probes)
* [Signal Quality Probes](#signal-quality-probes)
* [Control Signal Probes](#control-signal-probes)
* [Spectral Probes](#spectral-probes)
* [Analysis Probes](#analysis-probes)
* [Decay Probes](#decay-probes)
* [Attack Probes](#attack-probes)
* [Analysis Signal Quality Probes](#analysis-signal-quality-probes)
* [Time Stamping](#time-stamping)
* [Tap Utilities](#tap-utilities)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/debug.lib](https://github.com/grame-cncm/faustlibraries/blob/master/debug.lib)

## Level Probes

Level meters for quick signal magnitude checks (RMS/peak).
Use for coarse gain staging and headroom validation.

----

### `(db.)probe_rms_lin`

RMS level probe (linear).

#### Usage

```
_ : probe_rms_lin(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_rms_lin_test = db.probe_rms_lin(1, 1, os.osc(220));
```

----

### `(db.)probe_rms_db`

RMS level probe (dB). Bargraph includes `[unit:dB]`.

#### Usage

```
_ : probe_rms_db(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_rms_db_test = db.probe_rms_db(0, 1, os.osc(220));
```

----

### `(db.)probe_peak_lin`

Peak level probe (linear).

#### Usage

```
_ : probe_peak_lin(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_peak_lin_test = db.probe_peak_lin(3, 1, os.osc(220));
```

----

### `(db.)probe_peak_db`

Peak level probe (dB). Bargraph includes `[unit:dB]`.

#### Usage

```
_ : probe_peak_db(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_peak_db_test = db.probe_peak_db(2, 1, os.osc(220));
```

## Dynamics Probes

Dynamics-related meters for crest factor and envelope tracking.
Useful for checking transient behavior and overall dynamics.

----

### `(db.)probe_crest_db`

Crest factor probe (peak/rms ratio in dB).

#### Usage

```
_ : probe_crest_db(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_crest_db_test = db.probe_crest_db(4, 1, os.osc(220));
```

----

### `(db.)probe_env`

Envelope follower probe (attack/release).

#### Usage

```
_ : probe_env(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_env_test = db.probe_env(5, 1, os.osc(220));
```

----

### `(db.)probe_min`

Minimum-hold probe (inverted peak envelope).

#### Usage

```
_ : probe_min(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_min_test = db.probe_min(6, 1, os.osc(220));
```

----

### `(db.)probe_max`

Maximum-hold probe (slow peak envelope).

#### Usage

```
_ : probe_max(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_max_test = db.probe_max(7, 1, os.osc(220));
```

## Signal Quality Probes

Signal integrity checks such as DC offset, slew rate, and ZCR.
Helps detect bias, harsh transitions, or excessive high-frequency content.

----

### `(db.)probe_dc`

DC offset probe (very lowpass).

#### Usage

```
_ : probe_dc(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_dc_test = db.probe_dc(8, 1, os.osc(220));
```

----

### `(db.)probe_slew`

Slew rate probe (RMS of signal derivative).

#### Usage

```
_ : probe_slew(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_slew_test = db.probe_slew(9, 1, os.osc(220));
```

----

### `(db.)probe_zcr`

Zero-crossing rate probe (lowpassed).

#### Usage

```
_ : probe_zcr(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_zcr_test = db.probe_zcr(10, 1, os.osc(220));
```

## Control Signal Probes

Probes for control-rate or boolean signals.
Use to visualize modulators, gates, and internal state values.

----

### `(db.)probe_value`

Raw value probe (no smoothing).

#### Usage

```
_ : probe_value(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_value_test = db.probe_value(11, 1, os.osc(220));
```

----

### `(db.)probe_bool`

Boolean probe (gate/trigger state).

#### Usage

```
_ : probe_bool(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_bool_test = db.probe_bool(12, 1, os.osc(220) > 0);
```

## Spectral Probes

Frequency-band and spectral analysis probes.
Includes simple band meters plus centroid and multiband analysis.

----

### `(db.)probe_band_lo`

Low-band energy probe (<300 Hz).

#### Usage

```
_ : probe_band_lo(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_band_lo_test = db.probe_band_lo(13, 1, os.osc(220));
```

----

### `(db.)probe_band_mid`

Mid-band energy probe (300 Hz - 3 kHz).

#### Usage

```
_ : probe_band_mid(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_band_mid_test = db.probe_band_mid(14, 1, os.osc(220));
```

----

### `(db.)probe_band_hi`

High-band energy probe (>3 kHz).

#### Usage

```
_ : probe_band_hi(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_band_hi_test = db.probe_band_hi(15, 1, os.osc(220));
```

----

### `(db.)probe_spectral_centroid`

Spectral centroid estimate using multi-band analysis.
Outputs frequency estimate of spectral "center of mass".

#### Usage

```
_ : probe_spectral_centroid(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_spectral_centroid_test = db.probe_spectral_centroid(43, 1, os.osc(220));
```

----

### `(db.)probe_multiband`

Multi-band analyzer - outputs energy in N frequency bands.
Designed for STFT-like time-frequency analysis via time-series capture.

#### Usage

```
_ : probe_multiband(ID, HIDE) : _
```

Where:

* `ID`: (CNE) base probe id used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

Creates 8 probes at IDs ID through ID+7.

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_multiband_test = db.probe_multiband(44, 1, os.osc(220));
```

## Analysis Probes

Targeted analysis probes for offline or diagnostic workflows.
Includes parametric band energy and frequency ratio checks.

----

### `(db.)probe_freq_lin`

Parametric bandpass energy probe at a specific frequency.
Use to verify presence of expected oscillator frequencies.

#### Usage

```
_ : probe_freq_lin(ID, HIDE, freq, q) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI
* `freq`: center frequency in Hz
* `q`: filter Q (higher = narrower band, typically 5-20)

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_freq_lin_test = db.probe_freq_lin(34, 1, 440, 10, os.osc(440));
```

----

### `(db.)probe_freq_db`

Parametric bandpass energy probe in dB at a specific frequency.

#### Usage

```
_ : probe_freq_db(ID, HIDE, freq, q) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI
* `freq`: center frequency in Hz
* `q`: filter Q (higher = narrower band, typically 5-20)

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_freq_db_test = db.probe_freq_db(35, 1, 440, 10, os.osc(440));
```

----

### `(db.)probe_freq_ratio`

Ratio between two frequency bands (useful for verifying oscillator balance).

#### Usage

```
_ : probe_freq_ratio(ID, HIDE, f1, f2, q) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI
* `f1`: center frequency in Hz for the first band
* `f2`: center frequency in Hz for the second band
* `q`: filter Q (higher = narrower band, typically 5-20)

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_freq_ratio_test = db.probe_freq_ratio(36, 1, 440, 660, 12, os.osc(440));
```

## Decay Probes

Decay and release measurement helpers.
Use to track envelope level, peaks, and decay thresholds.

----

### `(db.)probe_env_lin`

Envelope state probe - outputs current envelope level for time-series capture.

#### Usage

```
_ : probe_env_lin(ID, HIDE, att_s, rel_s) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI
* `att_s`: envelope attack time in seconds (e.g., 0.001)
* `rel_s`: envelope release time in seconds (e.g., 0.1)

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_env_lin_test = db.probe_env_lin(37, 1, 0.001, 0.1, os.osc(220));
```

----

### `(db.)probe_env_db`

Envelope state probe in dB - for decay time analysis.

#### Usage

```
_ : probe_env_db(ID, HIDE, att_s, rel_s) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI
* `att_s`: envelope attack time in seconds (e.g., 0.001)
* `rel_s`: envelope release time in seconds (e.g., 0.1)

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_env_db_test = db.probe_env_db(38, 1, 0.001, 0.1, os.osc(220));
```

----

### `(db.)probe_peak_hold`

Peak hold probe - captures and holds peak value until reset.
Useful for measuring maximum amplitude reached.

#### Usage

```
_ : probe_peak_hold(ID, HIDE, decay_s) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI
* `decay_s`: time for held peak to decay (set high for true hold, e.g., 10.0)

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_peak_hold_test = db.probe_peak_hold(39, 1, 2.0, os.osc(220));
```

----

### `(db.)probe_below_threshold`

Threshold crossing probe - outputs 1 when signal drops below threshold.
Useful for detecting when decay is "complete".

#### Usage

```
_ : probe_below_threshold(ID, HIDE, thresh_db) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI
* `thresh_db`: threshold in dB for "below" detection

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_below_threshold_test = db.probe_below_threshold(40, 1, -40, os.osc(220));
```

## Attack Probes

Attack/onset detection helpers.
Useful for timing, transient detection, and trigger validation.

----

### `(db.)probe_attack_state`

Attack phase detector - outputs 1 during attack, 0 otherwise.
Attack is defined as: envelope rising AND above noise floor.

#### Usage

```
_ : probe_attack_state(ID, HIDE, floor_db) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI
* `floor_db`: noise floor threshold in dB

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_attack_state_test = db.probe_attack_state(41, 1, -60, os.osc(220));
```

----

### `(db.)probe_onset`

Onset detector - pulses 1 at signal onset (transition from silence to sound).

#### Usage

```
_ : probe_onset(ID, HIDE, thresh_db, holdoff_ms) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI
* `thresh_db`: threshold for "sound present" (e.g., -40)
* `holdoff_ms`: minimum time between onsets in ms

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_onset_test = db.probe_onset(42, 1, -40, 50, os.osc(220));
```

## Analysis Signal Quality Probes

Additional signal-quality probes for analysis tasks.
Includes precise DC measurement and silence detection.

----

### `(db.)probe_dc_precise`

Precise DC offset probe with very low cutoff for accurate measurement.

#### Usage

```
_ : probe_dc_precise(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_dc_precise_test = db.probe_dc_precise(56, 1, os.osc(2));
```

----

### `(db.)probe_silence`

Silence detector - outputs 1 when signal is effectively silent.

#### Usage

```
_ : probe_silence(ID, HIDE, thresh_db) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI
* `thresh_db`: threshold in dB below which the signal is considered silent

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_silence_test = db.probe_silence(57, 1, -60, os.osc(220));
```

## Time Stamping

Timebase probes for aligning analysis data.
Use sample count or milliseconds for synchronization.

----

### `(db.)probe_sample_count`

Sample counter probe - outputs current sample number (wraps at 2^24).
Useful for synchronizing time-series data.

#### Usage

```
_ : probe_sample_count(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_sample_count_test = db.probe_sample_count(58, 1, os.osc(220));
```

----

### `(db.)probe_time_ms`

Time probe in milliseconds (wraps at ~16 seconds at 44.1kHz).

#### Usage

```
_ : probe_time_ms(ID, HIDE) : _
```

Where:

* `ID`: (CNE) probe id integer used in `[probe:ID]`
* `HIDE`: (CNE) 0 to show, 1 to hide in UI

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
probe_time_ms_test = db.probe_time_ms(59, 1, os.osc(220));
```

## Tap Utilities

Utilities for tapping signals without changing arity.
Use to branch analysis meters while preserving main signal flow.

----

### `(db.)probe_tap` 

Tap a signal for side-effect analysis without changing output arity.

#### Usage

```
_ : probe_tap(F) : _
```

Where:

* `F`: signal processor for the tap (e.g., meter, analyser)

#### Example test program

Tap a pre-filter signal without changing arity:

- The probe taps the signal before the filter.
- The main signal path remains 1-in/1-out, so the lowpass still sees a mono input.
- The RMS probe runs in parallel and is exposed through the UI/metrics.
```
db = library("debug.lib");
os = library("oscillators.lib");
fi = library("filters.lib");
process = os.osc(220)
  : db.probe_tap(db.probe_rms_db(0, 1))
  : fi.lowpass(4, 2000);
```

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
tap_test = db.probe_tap(db.probe_rms_db(0, 1), os.osc(220));
```

----

### `(db.)probe_tap_n` 

Tap an N-channel signal with a processor that takes N inputs and produces 1 output.
The original N-channel signal passes through unchanged.

#### Usage

```
probe_tap_n(N, F)
```

Where:

* `N`: (CNE) number of channels
* `F`: processor with N inputs and 1 output (e.g., sum or mix meter)

#### Example test program

Tap a stereo signal with a mixdown probe:

- Two oscillators build a stereo pair with different filters per channel.
- After a stereo EQ stage, `probe_tap_n` mixes both channels for a single probe.
- The stereo signal continues unchanged after the tap (2-in/2-out).
```
db = library("debug.lib");
os = library("oscillators.lib");
fi = library("filters.lib");
left = os.osc(220) : fi.lowpass(2, 1200);
right = os.osc(330) : fi.highpass(2, 400);
stereo = (left, right)
  : (fi.lowpass(2, 2000), fi.highpass(2, 700));
process = stereo
  : db.probe_tap_n(2,  + : db.probe_rms_db(100, 1))
  : (fi.lowpass(2, 8000), fi.lowpass(2, 8000));
```

#### Test
```
db = library("debug.lib");
os = library("oscillators.lib");
tap_n_test = (os.osc(220), os.osc(330)) : db.probe_tap_n(2, +);
```
