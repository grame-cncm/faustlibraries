
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
operator_test = op.operator(0,1,0,0,99,99,99,99,99,0,0,0,0,0,0,0,4,35,0,0,0,1,3,99,99,99,99,0,0,0,0,50,0,0,0,0,0,-12,0,440.0,1.0,button("gate"));
```
