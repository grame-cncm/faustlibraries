#  motion.lib 

Motion library. Its official prefix is `mo`.

This library provides helpers for motion and orientation processing: shock detection,
inclination and gravity projection, acceleration and gyroscope envelopes, orientation
weighting toward the device axes, and utilities for normalized motion streams.

Usage:

```
mo = library("motion.lib");
process = mo.shockTrigger(50, 0.75, 75, accX);
```

All motion axes are expected to be normalized to [-1, 1] (e.g., gravity ~= 1 g).
Functions return signals in [0, 1] unless documented otherwise. Time parameters
are in milliseconds unless noted. Some helpers (e.g., projectedGravity) allow an
optional dead-zone offset: low magnitudes are zeroed, and the remaining span is
rescaled to preserve the 0..1 range.

Typical use-cases:

* Map shocks to drum triggers or one-shot events.
* Derive smooth inclination or projected-gravity controls for fades/pans.
* Track acceleration/gyro envelopes to drive dynamics (filters, gains, FX sends).
* Weight device orientation toward axes for spatial routing or mode selection.
* Normalize motion streams with dead-zones to reduce jitter or false positives.

The Motion library is organized into 7 sections:

* [Shock Detection](#shock-detection)
* [Inclination and Gravity Projection](#inclination-and-gravity-projection)
* [Envelopes Helpers](#envelopes-helpers)
* [Acceleration Envelopes](#acceleration-envelopes)
* [Gyroscope Envelopes](#gyroscope-envelopes)
* [Orientation Weighting](#orientation-weighting)
* [Utility Scaling](#utility-scaling)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/motion.lib](https://github.com/grame-cncm/faustlibraries/blob/master/motion.lib)

## Shock Detection


----

### `(mo.)shockTrigger`

Debounced shock trigger from an accelerometer axis.

#### Usage

```
shockTrigger(hpHz, threshold, debounceMs, sig) : _
```

Where:

* `hpHz`: high-pass frequency (Hz) used to isolate shocks ( > 0 )
* `threshold`: trigger threshold applied after high-pass (normalized g units)
* `debounceMs`: time in milliseconds to hold the trigger high (>= 0)
* `sig`: accelerometer axis signal (normalized, typically [-1, 1])
  - Output is a gate in [0, 1].

#### Example

```
mo = library("motion.lib");
process = mo.shockTrigger(50, 0.75, 75, accX);
```

#### Test
```
shockTrigger_test =
  with {
    mo = library("motion.lib");
    os = library("oscillators.lib");
    accX = os.pulsetrain(4) * 2;
  } : mo.shockTrigger(50, 0.5, 50);
```

## Inclination and Gravity Projection


----

### `(mo.)inclinometer`

Low-pass inclinometer for a single axis.

#### Usage

```
inclinometer(lpHz, sig) : _
```

Where:

* `lpHz`: low-pass frequency (Hz) ( > 0 )
* `sig`: accelerometer axis signal (normalized, typically [-1, 1])
  - Output is clamped to [0, 1] with negative values removed.

#### Example

```
mo = library("motion.lib");
process = mo.inclinometer(1.5, accX);
```

#### Test
```
inclinometer_test =
  with {
    mo = library("motion.lib");
    os = library("oscillators.lib");
  } : mo.inclinometer(2, os.sawtooth(1));
```

----

### `(mo.)inclineBalance`

Balance between positive and negative inclination on the same axis.

#### Usage

```
inclineBalance(lpHz, posSig, negSig) : _
```

Where:

* `lpHz`: low-pass frequency (Hz) ( > 0 )
* `posSig`: positive-facing accelerometer axis signal (normalized, typically [-1, 1])
* `negSig`: negative-facing accelerometer axis signal (normalized, typically [-1, 1])
  - Output maps posSig -> 1 and negSig -> 0 with smoothing and clamping.

#### Example

```
mo = library("motion.lib");
process = mo.inclineBalance(1.5, accPosX, accNegX);
```

#### Test
```
inclineBalance_test =
  with {
    mo = library("motion.lib");
    os = library("oscillators.lib");
    accPosX = os.sawtooth(0.1) * 0.5 + 0.5;
    accNegX = accPosX * (-1);
  } : mo.inclineBalance(1, accPosX, accNegX);
```

----

### `(mo.)inclineSymmetric`

Symmetric gravity comparison (0->1->0) from positive and negative axes.

#### Usage

```
inclineSymmetric(lpHz, posSig, negSig) : _
```

Where:

* `lpHz`: low-pass frequency (Hz) ( > 0 )
* `posSig`: positive-facing accelerometer axis signal (normalized, typically [-1, 1])
* `negSig`: negative-facing accelerometer axis signal (normalized, typically [-1, 1])
  - Output peaks at 1 near either pole and returns to 0 near the midpoint.

#### Example

```
mo = library("motion.lib");
process = mo.inclineSymmetric(1.5, accPosX, accNegX);
```

#### Test
```
inclineSymmetric_test =
  with {
    mo = library("motion.lib");
    os = library("oscillators.lib");
    accPosX = os.triangle(0.2) * 0.5 + 0.5;
    accNegX = accPosX * (-1);
  } : mo.inclineSymmetric(2, accPosX, accNegX);
```

----

### `(mo.)projectedGravity`

Projects an axis onto gravity with optional dead-zone offset.

#### Usage

```
projectedGravity(lpHz, offset, sig) : _
```

Where:

* `lpHz`: low-pass frequency (Hz) ( > 0 )
* `offset`: dead-zone offset applied after projection (0..0.33). Magnitudes below
  `offset` clamp to 0, and the remaining range is rescaled to keep the output in [0, 1].
* `sig`: accelerometer axis signal (normalized, typically [-1, 1])
  - Output is normalized to [0, 1] with an optional dead zone near 0.

#### Example

```
mo = library("motion.lib");
process = mo.projectedGravity(1.5, 0.08, accX);
```

#### Test
```
projectedGravity_test =
  with {
    mo = library("motion.lib");
    os = library("oscillators.lib");
  } : mo.projectedGravity(2, 0.05, os.triangle(0.1));
```

## Envelopes Helpers


----

### `(mo.)motionEnvelope`

Base thresholded AR envelope used by the accelerometer and gyroscope helpers.

#### Usage

```
motionEnvelope(thr, gain, envUpMs, envDownMs, sig) : _
```

Where:

* `thr`: threshold subtracted before detection (normalized)
* `gain`: linear gain applied after thresholding
* `envUpMs`: attack time in milliseconds (>= 0)
* `envDownMs`: release time in milliseconds (>= 0)
* `sig`: input signal (normalized)
  - Signal is offset by `thr`, floored at 0, scaled by `gain`, clamped to [0, 1], then
    fed to an attack/release follower (`an.amp_follower_ar`).

#### Example

```
mo = library("motion.lib");
process = mo.motionEnvelope(0.05, 1.25, 15, 25, accX);
```

----

### `(mo.)envelopeAbs`

Envelope on the absolute value of a signal (responds to both polarities).

#### Usage
```
envelopeAbs(thr, gain, envUpMs, envDownMs, sig) : _
```
Where:

* `thr`, `gain`, `envUpMs`, `envDownMs`: passed to `motionEnvelope`
* `sig`: input signal
  - Absolute value is taken before envelope detection.

----

### `(mo.)envelopePos`

Envelope for the positive portion of a signal.

#### Usage
```
envelopePos(thr, gain, envUpMs, envDownMs, sig) : _
```
Where:

* `thr`, `gain`, `envUpMs`, `envDownMs`: passed to `motionEnvelope`
* `sig`: input signal
  - Negative values are ignored by the thresholding stage.

----

### `(mo.)envelopeNeg`

Envelope for the negative portion of a signal (by flipping its polarity first).

#### Usage
```
envelopeNeg(thr, gain, envUpMs, envDownMs, sig) : _
```
Where:

* `thr`, `gain`, `envUpMs`, `envDownMs`: passed to `motionEnvelope`
* `sig`: input signal
  - The signal is negated before the shared positive-only detector.

----

### `(mo.)pita3`

3D magnitude helper `sqrt(x^2 + y^2 + z^2)` used for total envelopes.

#### Usage
```
pita3(x, y, z) : _
```

----

### `(mo.)totalEnvelope`

Magnitude-based envelope across three axes.

#### Usage
```
totalEnvelope(thr, gain, envUpMs, envDownMs, x, y, z) : _
```
Where:

* `thr`, `gain`, `envUpMs`, `envDownMs`: passed to `motionEnvelope`
* `x`, `y`, `z`: three-axis signals (normalized)
  - Computes a magnitude via `pita3` then applies `motionEnvelope`.

## Acceleration Envelopes


----

### `(mo.)accelEnvelopeAbs`

Envelope follower on the absolute value of an accelerometer axis.

#### Usage

```
accelEnvelopeAbs(thr, gain, envUpMs, envDownMs, sig) : _
```

Where:

* `thr`: threshold subtracted before detection (normalized)
* `gain`: linear gain applied after thresholding
* `envUpMs`: attack time in milliseconds (>= 0)
* `envDownMs`: release time in milliseconds (>= 0)
* `sig`: accelerometer axis signal (normalized, typically [-1, 1])
  - Output envelope is clamped to [0, 1].

#### Example

```
mo = library("motion.lib");
process = mo.accelEnvelopeAbs(0.1, 1.2, 10, 12, accX);
```

#### Test
```
accelEnvelopeAbs_test =
  with {
    mo = library("motion.lib");
    os = library("oscillators.lib");
    accX = os.sawtooth(0.5);
  } : mo.accelEnvelopeAbs(0.1, 1.5, 5, 20, accX);
```

----

### `(mo.)accelEnvelopePos`

Envelope follower for positive acceleration on one axis.

#### Usage

```
accelEnvelopePos(thr, gain, envUpMs, envDownMs, sig) : _
```

Where:

* `thr`: threshold subtracted before detection (normalized)
* `gain`: linear gain applied after thresholding
* `envUpMs`: attack time in milliseconds (>= 0)
* `envDownMs`: release time in milliseconds (>= 0)
* `sig`: accelerometer axis signal (normalized, typically [-1, 1])
  - Negative values are ignored; output envelope is clamped to [0, 1].

#### Example

```
mo = library("motion.lib");
process = mo.accelEnvelopePos(0.05, 1.35, 10, 10, accX);
```

#### Test
```
accelEnvelopePos_test =
  with {
    mo = library("motion.lib");
    os = library("oscillators.lib");
  } : mo.accelEnvelopePos(0.05, 1, 5, 5, os.triangle(0.25));
```

----

### `(mo.)accelEnvelopeNeg`

Envelope follower for negative acceleration on one axis.

#### Usage

```
accelEnvelopeNeg(thr, gain, envUpMs, envDownMs, sig) : _
```

Where:

* `thr`: threshold subtracted before detection (normalized)
* `gain`: linear gain applied after thresholding
* `envUpMs`: attack time in milliseconds (>= 0)
* `envDownMs`: release time in milliseconds (>= 0)
* `sig`: accelerometer axis signal (normalized, typically [-1, 1])
  - Positive values are ignored; output envelope is clamped to [0, 1].

#### Example

```
mo = library("motion.lib");
process = mo.accelEnvelopeNeg(0.05, 1.35, 10, 10, accX);
```

#### Test
```
accelEnvelopeNeg_test =
  with {
    mo = library("motion.lib");
    os = library("oscillators.lib");
  } : mo.accelEnvelopeNeg(0.05, 1, 5, 5, os.triangle(0.25));
```

----

### `(mo.)totalAccel`

Total acceleration magnitude with thresholding and envelope.

#### Usage

```
totalAccel(thr, gain, envUpMs, envDownMs, ax, ay, az) : _
```

Where:

* `thr`: threshold subtracted before detection (normalized)
* `gain`: linear gain applied after thresholding
* `envUpMs`: attack time in milliseconds (>= 0)
* `envDownMs`: release time in milliseconds (>= 0)
* `ax`: accelerometer X axis (normalized, typically [-1, 1])
* `ay`: accelerometer Y axis (normalized, typically [-1, 1])
* `az`: accelerometer Z axis (normalized, typically [-1, 1])
  - Output magnitude is clamped to [0, 1].

#### Example

```
mo = library("motion.lib");
process = mo.totalAccel(0.1, 1.35, 10, 10, ax, ay, az);
```

#### Test
```
totalAccel_test =
  with {
    mo = library("motion.lib");
    os = library("oscillators.lib");
    ax = os.sawtooth(0.2) * 0.2;
    ay = os.triangle(0.15) * 0.1;
    az = os.sawtooth(0.12) * 0.3;
  } : mo.totalAccel(0.05, 1.2, 8, 12, ax, ay, az);
```

## Gyroscope Envelopes


----

### `(mo.)gyroEnvelopeAbs`

Envelope follower on the absolute value of a gyroscope axis.

#### Usage

```
gyroEnvelopeAbs(thr, gain, envUpMs, envDownMs, sig) : _
```

Where:

* `thr`: threshold subtracted before detection (normalized)
* `gain`: linear gain applied after thresholding
* `envUpMs`: attack time in milliseconds (>= 0)
* `envDownMs`: release time in milliseconds (>= 0)
* `sig`: gyroscope axis signal (normalized rad/s range)
  - Output envelope is clamped to [0, 1].

#### Example

```
mo = library("motion.lib");
process = mo.gyroEnvelopeAbs(0.01, 0.8, 50, 50, gx);
```

#### Test
```
gyroEnvelopeAbs_test =
  with {
    mo = library("motion.lib");
    os = library("oscillators.lib");
  } : mo.gyroEnvelopeAbs(0.02, 0.9, 25, 30, os.sawtooth(0.5));
```

----

### `(mo.)gyroEnvelopePos`

Envelope follower for positive gyroscope rotation on one axis.

#### Usage

```
gyroEnvelopePos(thr, gain, envUpMs, envDownMs, sig) : _
```

Where:

* `thr`: threshold subtracted before detection (normalized)
* `gain`: linear gain applied after thresholding
* `envUpMs`: attack time in milliseconds (>= 0)
* `envDownMs`: release time in milliseconds (>= 0)
* `sig`: gyroscope axis signal (normalized rad/s range)
  - Negative values are ignored; output envelope is clamped to [0, 1].

#### Example

```
mo = library("motion.lib");
process = mo.gyroEnvelopePos(0.01, 0.8, 50, 50, gx);
```

#### Test
```
gyroEnvelopePos_test =
  with {
    mo = library("motion.lib");
    os = library("oscillators.lib");
  } : mo.gyroEnvelopePos(0.02, 0.9, 25, 30, os.triangle(0.5));
```

----

### `(mo.)gyroEnvelopeNeg`

Envelope follower for negative gyroscope rotation on one axis.

#### Usage

```
gyroEnvelopeNeg(thr, gain, envUpMs, envDownMs, sig) : _
```

Where:

* `thr`: threshold subtracted before detection (normalized)
* `gain`: linear gain applied after thresholding
* `envUpMs`: attack time in milliseconds (>= 0)
* `envDownMs`: release time in milliseconds (>= 0)
* `sig`: gyroscope axis signal (normalized rad/s range)
  - Positive values are ignored; output envelope is clamped to [0, 1].

#### Example

```
mo = library("motion.lib");
process = mo.gyroEnvelopeNeg(0.01, 0.8, 50, 50, gx);
```

#### Test
```
gyroEnvelopeNeg_test =
  with {
    mo = library("motion.lib");
    os = library("oscillators.lib");
  } : mo.gyroEnvelopeNeg(0.02, 0.9, 25, 30, os.triangle(0.5));
```

----

### `(mo.)totalGyro`

Total gyroscope magnitude with thresholding and envelope.

#### Usage

```
totalGyro(thr, gain, envUpMs, envDownMs, gx, gy, gz) : _
```

Where:

* `thr`: threshold subtracted before detection (normalized)
* `gain`: linear gain applied after thresholding
* `envUpMs`: attack time in milliseconds (>= 0)
* `envDownMs`: release time in milliseconds (>= 0)
* `gx`: gyroscope X axis (normalized rad/s range)
* `gy`: gyroscope Y axis (normalized rad/s range)
* `gz`: gyroscope Z axis (normalized rad/s range)
  - Output magnitude is clamped to [0, 1].

#### Example

```
mo = library("motion.lib");
process = mo.totalGyro(0.01, 0.8, 50, 50, gx, gy, gz);
```

#### Test
```
totalGyro_test =
  with {
    mo = library("motion.lib");
    os = library("oscillators.lib");
    gx = os.sawtooth(0.2) * 0.2;
    gy = os.triangle(0.15) * 0.1;
    gz = os.sawtooth(0.12) * 0.3;
  } : mo.totalGyro(0.01, 0.9, 25, 30, gx, gy, gz);
```

## Orientation Weighting


----

### `(mo.)orientationWeight`

Weighting of a 3D vector toward a target axis with shape and smoothing.

#### Usage

```
orientationWeight(targetX, targetY, targetZ, shape, xs, ys, zs, smoothMs) : _
```

Where:

* `targetX`: target X coordinate (-1..1)
* `targetY`: target Y coordinate (-1..1)
* `targetZ`: target Z coordinate (-1..1)
* `shape`: scaling applied to the distance (>= 0, larger tightens the lobe)
* `xs`: current X coordinate (normalized)
* `ys`: current Y coordinate (normalized)
* `zs`: current Z coordinate (normalized)
* `smoothMs`: smoothing time in milliseconds (>= 0)
  - Output weight is clamped to [0, 1].

#### Example

```
mo = library("motion.lib");
process = mo.orientationWeight(0, 1, 0, 1, x, y, z, 10);
```

#### Test
```
orientationWeight_test =
  with {
    mo = library("motion.lib");
    os = library("oscillators.lib");
    x = os.triangle(0.1);
    y = os.sawtooth(0.1);
    z = os.triangle(0.05);
  } : mo.orientationWeight(0, 1, 0, 1, x, y, z, 10);
```

----

### `(mo.)orientation6`

Weights toward the six device axes (Cour/stage left -X, Rear -Y, Jardin/stage right +X,
Front +Y, Down -Z, Up +Z).

#### Usage

```
orientation6(xs, ys, zs,
             shapeCour, shapeRear, shapeJardin, shapeFront, shapeDown, shapeUp,
             smoothMs) : _
```

Where:

* `xs`: current X coordinate (normalized)
* `ys`: current Y coordinate (normalized)
* `zs`: current Z coordinate (normalized)
* `shapeCour`: shape for Cour (-X)
* `shapeRear`: shape for Rear (-Y)
* `shapeJardin`: shape for Jardin (+X)
* `shapeFront`: shape for Front (+Y)
* `shapeDown`: shape for Down (-Z)
* `shapeUp`: shape for Up (+Z)
* `smoothMs`: smoothing time in milliseconds (>= 0)
  - Output is six weights (Cour, Rear, Jardin, Front, Down, Up), each in [0, 1].

#### Example

```
mo = library("motion.lib");
process = mo.orientation6(x, y, z, 1, 1, 1, 1, 1, 1, 10);
```

#### Test
```
orientation6_test =
  with {
    mo = library("motion.lib");
    os = library("oscillators.lib");
    x = os.triangle(0.05);
    y = os.sawtooth(0.08);
    z = os.triangle(0.03);
  } : mo.orientation6(x, y, z, 1, 1, 1, 1, 1, 1, 10);
```

## Utility Scaling


----

### `(mo.)scale`

Normalized scaler with input dead-zone and bounded output range.

#### Usage

```
scale(ilow, ihigh, olow, ohigh) : _
```

Where:

* `ilow`: minimum input value before scaling starts (0..1)
* `ihigh`: maximum input value before clamping (must be > ilow)
* `olow`: minimum output value
* `ohigh`: maximum output value
  - Inputs below ilow clamp to olow; above ihigh clamp to ohigh.

#### Example

```
mo = library("motion.lib");
process = _ : mo.scale(0.2, 0.8, 100, 20000) : _;
```

#### Test
```
scale_test =
  with {
    mo = library("motion.lib");
    os = library("oscillators.lib");
  } : os.sawtooth(0.2) : mo.scale(0.2, 0.8, 0, 1);
```
