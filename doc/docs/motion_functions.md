# motion Conversion Functions

The `motion` library exposes conversion helpers for motion and orientation data. All functions are UI-free and ready to be called through the `mo = library("motion.lib")` environment. Inputs are assumed normalized to approximately [-1, 1]; outputs are in [0, 1] unless noted.

- `shockTrigger(hpHz, threshold, debounceMs, sig)` — high-pass, threshold, and hold to create a debounced trigger from an accelerometer axis; outputs a gate.
- `inclinometer(lpHz, sig)` — low-pass tilt estimate for one accelerometer axis; negative values are dropped before clamping to [0, 1].
- `inclineBalance(lpHz, posSig, negSig)` — blends positive/negative axes into a smoothed 0–1 balance.
- `inclineSymmetric(lpHz, posSig, negSig)` — symmetric gravity comparison that peaks near either pole and falls to 0 around neutral.
- `projectedGravity(lpHz, offset, sig)` — projects one axis onto gravity, maps to [0, 1], and adds an adjustable dead-zone offset.
- `accelEnvelopeAbs(thr, gain, envUpMs, envDownMs, sig)` — envelope of absolute acceleration with threshold/gain and AR smoothing.
- `accelEnvelopePos(thr, gain, envUpMs, envDownMs, sig)` — envelope of positive acceleration only; negative values ignored.
- `accelEnvelopeNeg(thr, gain, envUpMs, envDownMs, sig)` — envelope of negative acceleration only; positive values ignored.
- `totalAccel(thr, gain, envUpMs, envDownMs, ax, ay, az)` — magnitude of 3-axis acceleration with threshold/gain and AR envelope.
- `gyroEnvelopeAbs(thr, gain, envUpMs, envDownMs, sig)` — envelope of absolute gyroscope rotation with threshold/gain.
- `gyroEnvelopePos(thr, gain, envUpMs, envDownMs, sig)` — envelope of positive gyroscope rotation only; negative ignored.
- `gyroEnvelopeNeg(thr, gain, envUpMs, envDownMs, sig)` — envelope of negative gyroscope rotation only; positive ignored.
- `totalGyro(thr, gain, envUpMs, envDownMs, gx, gy, gz)` — magnitude of 3-axis gyroscope rotation with threshold/gain and AR envelope.
- `orientationWeight(targetX, targetY, targetZ, shape, xs, ys, zs, smoothMs)` — weight toward a single target axis with adjustable lobe width and smoothing.
- `orientation6(xs, ys, zs, shapeCour, shapeRear, shapeJardin, shapeFront, shapeDown, shapeUp, smoothMs)` — six weights for the canonical axes (Cour, Rear, Jardin, Front, Down, Up), each in [0, 1].
- `scale(ilow, ihigh, olow, ohigh)` — normalized scaler with input dead-zone and bounded output range; clamps below `ilow` and above `ihigh`.

