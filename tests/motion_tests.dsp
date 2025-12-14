//----------------------------------------------------------------------------
// motion_tests.dsp
// Tests for motion helper functions.
//----------------------------------------------------------------------------

mo = library("motion.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");

shockTrigger_test = mo.shockTrigger(50, 0.5, 50, os.pulsetrain(2, 0.5));

inclinometer_test = mo.inclinometer(2, os.sawtooth(1));

inclineBalance_test =
  mo.inclineBalance(1.5, os.sawtooth(0.2) * 0.5 + 0.5, os.sawtooth(0.2) * (-0.5));

inclineSymmetric_test =
  mo.inclineSymmetric(1.5, os.triangle(0.3) * 0.5 + 0.5, os.triangle(0.3) * (-0.5));

projectedGravity_test = mo.projectedGravity(2, 0.05, os.triangle(0.1));

accelEnvelopeAbs_test =
  mo.accelEnvelopeAbs(0.1, 1.2, 10, 12, os.sawtooth(0.5));

accelEnvelopePos_test =
  mo.accelEnvelopePos(0.05, 1.35, 10, 10, os.triangle(0.25));

accelEnvelopeNeg_test =
  mo.accelEnvelopeNeg(0.05, 1.35, 10, 10, os.triangle(0.25) * (-1));

totalAccel_test =
  mo.totalAccel(0.05, 1.2, 8, 12,
    os.sawtooth(0.2) * 0.2,
    os.triangle(0.15) * 0.1,
    os.sawtooth(0.12) * 0.3);

gyroEnvelopeAbs_test =
  mo.gyroEnvelopeAbs(0.02, 0.9, 25, 30, os.sawtooth(0.5) * 0.2);

gyroEnvelopePos_test =
  mo.gyroEnvelopePos(0.02, 0.9, 25, 30, os.triangle(0.5) * 0.2);

gyroEnvelopeNeg_test =
  mo.gyroEnvelopeNeg(0.02, 0.9, 25, 30, os.triangle(0.5) * (-0.2));

totalGyro_test =
  mo.totalGyro(0.02, 0.9, 25, 30,
    os.sawtooth(0.2) * 0.2,
    os.triangle(0.15) * 0.1,
    os.sawtooth(0.12) * 0.3);

orientationWeight_test =
  mo.orientationWeight(0, 1, 0, 1, os.triangle(0.1), os.sawtooth(0.1), os.triangle(0.05), 10);

orientation6_test =
  mo.orientation6(
    os.triangle(0.05),
    os.sawtooth(0.08),
    os.triangle(0.03),
    1, 1, 1, 1, 1, 1,
    10);

scale_test = os.sawtooth(0.2) : mo.scale(0.2, 0.8, 0, 1);
