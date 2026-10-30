
----

### `(dx.)operator`

DX7 Operator. Implements a phase-modulable sine wave oscillator connected
to a DX7 envelope generator.

#### Usage:

```
operator(mode,freqCoarse,freqFine,detune,outLev,R1,R2,R3,R4,L1,L2,L3,L4,keyVelSens,ampModSens,rateScale,lfoWave,lfoSpeed,lfoDelay,lfoPMD,lfoAMD,lfoSync,lfoPitchModSens,oscKeySync,pitch_egR1,pitch_egR2,pitch_egR3,pitch_egR4,pitch_egL1,pitch_egL2,pitch_egL3,pitch_egL4,breakpoint,breakpointLDepth,breakpointRDepth,breakpointLCurve,breakpointRCurve,transpose,phaseMod,base_freq,gain,gate) : _
```

Where:

* `mode`: pitch mode (0=ratio; 1=fixed)
* `freqCoarse`: coarse frequency (0-31)
* `freqFine`: fine frequency (0-99)
* `detune`: detune in semitones (-7 - 7), *not* (0 - 14)
* `outLev`: output level (0-99)
* `R1`: envelope rate 1 (0-99)
* `R2`: envelope rate 2 (0-99)
* `R3`: envelope rate 3 (0-99)
* `R4`: envelope rate 4 (0-99)
* `L1`: envelope level 1 (0-99)
* `L2`: envelope level 2 (0-99)
* `L3`: envelope level 3 (0-99)
* `L4`: envelope level 4 (0-99)
* `keyVelSens`: key velocity sensitivity (0-7)
* `ampModSens`: amplitude sensitivity (0-3)
* `rateScale`: envelope rate scale (0-7)
* `breakpoint`: break point position (0-99) // TODO: is it 0-99 or 0-34ish?
* `breakpointLDepth`: break point left depth (0-99)
* `breakpointRDepth`: break point right depth (0-99)
* `breakpointLCurve`: break point left curve (0-3) (-LIN,-EXP,+EXP,+LIN)
* `breakpointRCurve`: break point right curve (0-3) (-LIN,-EXP,+EXP,+LIN)
* `lfoWave`: LFO wave mode (0-5) (triangle, saw down, saw up, square, sine, sample&hold)
* `lfoSpeed`: LFO speed (0-99)
* `lfoDelay`: LFO delay (0-99)
* `lfoPMD`: LFO pitch modulation depth (0-99)
* `lfoAMD`: LFO amplitude modulation depth (0-99)
* `lfoSync`: (0-1) (0=no retrigger; 1=retrigger)
* `lfoPitchModSens`: LFO Pitch modulation sensitivity (0-7)
* `oscKeySync`: osc key sync (0-1)
* `pitch_egR1`: pitch envelope generator rate 1 (0-99)
* `pitch_egR2`: pitch envelope generator rate 2 (0-99)
* `pitch_egR3`: pitch envelope generator rate 3 (0-99)
* `pitch_egR4`: pitch envelope generator rate 4 (0-99)
* `pitch_egL1`: pitch envelope generator level 1 (0-99)
* `pitch_egL2`: pitch envelope generator level 2 (0-99)
* `pitch_egL3`: pitch envelope generator level 3 (0-99)
* `pitch_egL4`: pitch envelope generator level 4 (0-99)
* `transpose`: global transpose (-24 - 24), *not* (0-48)
* `phaseMod`: phase deviation (-1 - 1)
* `base_freq`: frequency of the oscillator
* `gain`: general gain, like a velocity but 0.-1. instead of 0-127.
* `gate`: trigger signal, "is the note on?"

#### Test
```
op = library("operator.lib");
ba = library("basics.lib");
ma = library("maths.lib");
operator_test = op.operator(0,1,0,0,99,99,99,99,99,99,90,70,0,0,0,0,4,35,0,0,0,1,3,99,99,99,99,0,0,0,0,50,0,0,0,0,0,-12,0,440.0,1.0,button("gate"));
operator_modulated_test = op.operator(0,1,0,0,99,99,99,99,99,99,99,99,99,0,0,0,4,35,0,0,0,1,3,99,99,99,99,0,0,0,0,50,0,0,0,0,0,-12,2*tri - 1,440.0,1.0,button("gate")) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
voice = \(mode, coarse, fine, detune, keyvel, ams, ratescale, bp, ld, rd, lc, rc, wave, speed, delay, pmd, amd, sync, pms, keysync, transpose, freq, gain, gate).(op.operator(mode, coarse, fine, detune, 99, 60, 50, 40, 30, 99, 80, 60, 0, keyvel, ams, ratescale, bp, ld, rd, lc, rc, wave, speed, delay, pmd, amd, sync, pms, keysync, 99, 99, 99, 99, 50, 50, 50, 50, transpose, 0, freq, gain, gate));
operator_ratio_test = par(c, 4, voice(0, 2*c, 25, 5 - 3*c, 0, 0, 0, 0, 0, 0, 0, 0, 0, 35, 0, 0, 0, 0, 0, 1, 0, 220, 1, button("gate")));
operator_fixed_test = par(c, 4, voice(1, c, 50, 3*c, 0, 0, 0, 0, 0, 0, 0, 0, 0, 35, 0, 0, 0, 0, 0, 1, 0, 220, 1, button("gate")));
operator_scaling_test = par(c, 4, voice(0, 1, 0, 0, 0, 0, 0, 39, 50, 70, c, 3 - c, 0, 35, 0, 0, 0, 0, 0, 1, 0, 110 + 330*(c > 1), 1, button("gate")));
operator_velocity_test = par(s, 4, voice(0, 1, 0, 0, 2*s + 1, 0, 0, 0, 0, 0, 0, 0, 0, 35, 0, 0, 0, 0, 0, 1, 0, 440, 0.25*(s + 1), button("gate")));
operator_ratescale_test = par(s, 4, voice(0, 1, 0, 0, 0, 0, 2*s + 1, 0, 0, 0, 0, 0, 0, 35, 0, 0, 0, 0, 0, 1, 0, 880, 1, button("gate")));
operator_pmd_test = par(s, 4, voice(0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, s + 2, 60, 10, 60, 0, 1, 2*s + 1, 1, 0, 440, 1, button("gate")));
operator_amd_test = par(s, 4, voice(0, 1, 0, 0, 0, s, 0, 0, 0, 0, 0, 0, s + 2, 60, 10, 0, 60, 1, 0, 1, 0, 440, 1, button("gate")));
operator_keysync_test = par(s, 2, voice(0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 35, 0, 0, 0, 0, 0, s, 7, 220, 1, gate)) with { P = int(ma.SR/4); gate = ba.period(P) < int(P/2); };
operator_pitchenv_test = op.operator(0, 1, 0, 0, 99, 60, 50, 40, 30, 99, 80, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 35, 0, 0, 0, 0, 0, 1, 99, 99, 99, 80, 70, 40, 60, 30, 0, 0, 440, 1, button("gate"));
operator_phasemod_test = op.operator(0, 1, 0, 0, 99, 60, 50, 40, 30, 99, 80, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 35, 0, 0, 0, 0, 0, 1, 99, 99, 99, 99, 50, 50, 50, 50, 0, 0.25, 440, 1, button("gate"));
operator_slider_test = op.operator(0, hslider("operator:coarse", 2, 0, 31, 1), hslider("operator:fine", 25, 0, 99, 1), hslider("operator:detune", 3, -7, 7, 1), hslider("operator:outLev", 90, 0, 99, 1), 60, 50, 40, 30, 99, 80, 60, 0, hslider("operator:keyVelSens", 3, 0, 7, 1), hslider("operator:ampModSens", 2, 0, 3, 1), hslider("operator:rateScale", 3, 0, 7, 1), hslider("operator:breakpoint", 39, 0, 99, 1), hslider("operator:ldepth", 50, 0, 99, 1), hslider("operator:rdepth", 70, 0, 99, 1), hslider("operator:lcurve", 1, 0, 3, 1), hslider("operator:rcurve", 2, 0, 3, 1), hslider("operator:wave", 4, 0, 5, 1), hslider("operator:speed", 60, 0, 99, 1), hslider("operator:delay", 10, 0, 99, 1), hslider("operator:pmd", 40, 0, 99, 1), hslider("operator:amd", 40, 0, 99, 1), 1, hslider("operator:pms", 3, 0, 7, 1), 1, 99, 99, 99, 99, 50, 50, 50, 50, hslider("operator:transpose", 0, -24, 24, 1), 0, hslider("operator:freq", 440, 50, 2000, 1), hslider("operator:gain", 0.8, 0, 1, 0.01), button("gate"));
```
