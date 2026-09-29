#  synths.lib 

Synths library. Its official prefix is `sy`.

This library provides synthesizer and drum building blocks.

The Synths library is organized into 2 sections:

* [Synthesizers](#synthesizers)
* [Drum Synthesis](#drum-synthesis)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/synths.lib](https://github.com/grame-cncm/faustlibraries/blob/master/synths.lib)

## Synthesizers


----

### `(sy.)popFilterDrum`

A simple percussion instrument based on a "popped" resonant bandpass filter.
`popFilterDrum` is a standard Faust function.

#### Usage

```
popFilterDrum(freq,q,gate) : _
```

Where:

* `freq`: the resonance frequency of the instrument in Hz
* `q`: the q of the res filter (typically, 5 is a good value)
* `gate`: the trigger signal (0 or 1)

#### Test
```
sy = library("synths.lib");
popFilterDrum_test = sy.popFilterDrum(
    hslider("popFilterDrum:freq", 200, 50, 1000, 1),
    hslider("popFilterDrum:q", 5, 1, 20, 0.1),
    button("popFilterDrum:gate")
);
```

----

### `(sy.)dubDub`

A simple synth based on a sawtooth wave filtered by a resonant lowpass.
`dubDub` is a standard Faust function.

#### Usage

```
dubDub(freq,ctFreq,q,gate) : _
```

Where:

* `freq`: frequency of the sawtooth in Hz
* `ctFreq`: cutoff frequency of the filter
* `q`: Q of the filter
* `gate`: the trigger signal (0 or 1)

#### Test
```
sy = library("synths.lib");
dubDub_test = sy.dubDub(
    hslider("dubDub:freq", 220, 50, 1000, 1),
    hslider("dubDub:cutoff", 800, 100, 6000, 1),
    hslider("dubDub:q", 2, 0.2, 10, 0.1),
    button("dubDub:gate")
);
```

----

### `(sy.)sawTrombone`

A simple trombone based on a lowpassed sawtooth wave.
`sawTrombone` is a standard Faust function.

#### Usage

```
sawTrombone(freq,gain,gate) : _
```

Where:

* `freq`: the frequency in Hz
* `gain`: the gain (0-1)
* `gate`: the gate (0 or 1)

#### Test
```
sy = library("synths.lib");
sawTrombone_test = sy.sawTrombone(
    hslider("sawTrombone:freq", 196, 50, 600, 1),
    hslider("sawTrombone:gain", 0.6, 0, 1, 0.01),
    button("sawTrombone:gate")
);
```

----

### `(sy.)combString`

Simplest string physical model ever based on a comb filter.
`combString` is a standard Faust function.

#### Usage

```
combString(freq,res,gate) : _
```

Where:

* `freq`: the frequency of the string in Hz
* `res`: string T60 (resonance time) in second
* `gate`: trigger signal (0 or 1)

#### Test
```
sy = library("synths.lib");
combString_test = sy.combString(
    hslider("combString:freq", 220, 55, 880, 1),
    hslider("combString:res", 4, 0.1, 10, 0.01),
    button("combString:gate")
);
```

----

### `(sy.)additiveDrum`

A simple drum using additive synthesis.
`additiveDrum` is a standard Faust function.

#### Usage

```
additiveDrum(freq,freqRatio,gain,harmDec,att,rel,gate) : _
```

Where:

* `freq`: the resonance frequency of the drum in Hz
* `freqRatio`: a list of ratio to choose the frequency of the mode in
               function of `freq` e.g.(1 1.2 1.5 ...). The first element should always
               be one (fundamental).
* `gain`: the gain of each mode as a list (1 0.9 0.8 ...). The first element
          is the gain of the fundamental.
* `harmDec`: harmonic decay ratio (0-1): configure the speed at which
             higher modes decay compare to lower modes.
* `att`: attack duration in second
* `rel`: release duration in second
* `gate`: trigger signal (0 or 1)

#### Test
```
sy = library("synths.lib");
additiveDrum_test = sy.additiveDrum(
    hslider("additiveDrum:freq", 180, 60, 600, 1),
    (1, 1.3, 2.4, 3.2),
    (1, 0.8, 0.6, 0.4),
    hslider("additiveDrum:harmDec", 0.4, 0, 1, 0.01),
    0.01,
    0.4,
    button("additiveDrum:gate")
);
```

----

### `(sy.)fm`

An FM synthesizer with an arbitrary number of modulators connected as a sequence.
`fm` is a standard Faust function.

#### Usage

```
freqs = (300,400,...);
indices = (20,...);
fm(freqs,indices) : _
```

Where:

* `freqs`: a list of frequencies where the first one is the frequency of the carrier
           and the others, the frequency of the modulator(s)
* `indices`: the indices of modulation (Nfreqs-1)

#### Test
```
sy = library("synths.lib");
fm_test = sy.fm((220, 440, 660), (1.5, 0.8));
```

----

### `(sy.)logicEFM1`

Model of one voice of Apple Logic Pro's EFM1, a two-operator FM synthesizer: a
sine carrier phase-modulated by a modulator whose waveform morphs through ten
wavetables, with volume and modulation envelopes, a key-synced LFO, a sub
oscillator, carrier stereo detune and a unison mode. Stereo output.

EFM1 exists only inside Logic Pro, so it cannot be hosted outside it. The model
was reverse-engineered from single notes rendered by Logic at 48 kHz, each with
one or two controls changed from a neutral patch and every control value read
back from Logic. The laws and constants below were fitted to those renders, and
the wavetables were read out of them. Against 94 of these renders the model
matches the level to 0.03 dB and, for steady tones, the waveform to 0.7 %
(median) and 4.4 % (worst case). The implementation notes give the fit per
feature and list what was not measured: only 48 kHz, only C notes (C0 to C6),
and one or a few settings for several controls.

#### Usage

```
logicEFM1(modHarm, carHarm, modFine, carFine, fixedCar, fmInt, modWave,
          modEnvFM, modPitch, subLevel, stereoDet, unison,
          lfoAmt, lfoRate, velAmt, mainLevel,
          vA, vD, vS, vR, mA, mD, mS, mR,
          freq, gate, gain) : _,_
```

Where:

* `modHarm`: modulator harmonic, an integer >= 1 (modulator frequency = modHarm*freq)
* `carHarm`: carrier harmonic, an integer >= 0 (carrier frequency = carHarm*freq; 0 gives a 0 Hz carrier)
* `modFine`: modulator fine ratio offset (-0.5..0.5), added to modHarm
* `carFine`: carrier fine ratio offset (-0.5..0.5), added to carHarm
* `fixedCar`: Fixed Carrier switch (0/1): the carrier sits at C1 (32.70 Hz) times its ratio, independent of freq and the LFO
* `fmInt`: FM intensity (0-1)
* `modWave`: modulator waveform (0-9): 0 is a sine, and the knob blends the ten wavetables linearly
* `modEnvFM`: modulation envelope to FM intensity (-1..1)
* `modPitch`: modulation envelope to modulator pitch (-1..1; up to +-27.5 semitones)
* `subLevel`: sub oscillator level (0-1; a sine one octave below freq)
* `stereoDet`: carrier stereo detune as displayed (0-50; the carriers move by about 0.75x this many cents)
* `unison`: Unison switch (0/1): a second, slightly detuned copy of the voice
* `lfoAmt`: LFO amount, bipolar (-1 = full vibrato, +-36 semitones .. +1 = full FM modulation)
* `lfoRate`: LFO rate in Hz (0.01-100)
* `velAmt`: velocity sensitivity of the level (0-1)
* `mainLevel`: output gain (linear; 1 = Logic's 0 dB)
* `vA`: volume envelope attack in ms, as Logic displays it (0-10000)
* `vD`: volume envelope decay in ms (0-10000)
* `vS`: volume envelope sustain (0-1)
* `vR`: volume envelope release in ms (0-10000)
* `mA`: modulation envelope attack in ms (0-10000)
* `mD`: modulation envelope decay in ms (0-10000)
* `mS`: modulation envelope sustain (0-1)
* `mR`: modulation envelope release in ms (0-10000)
* `freq`: note frequency in Hz
* `gate`: note gate (0/1)
* `gain`: note velocity (MIDI velocity/127)

#### Test
```
sy = library("synths.lib");
ba = library("basics.lib");
logicEFM1_test = sy.logicEFM1(1, 2, 0, 0, 0, 0.3, 2.5, 0.5, 0.2, 0.3, 10, 0,
                              -0.3, 2, 0.3, 1, 10, 500, 0.7, 300, 0, 800, 0.2, 200,
                              261.63, ba.time < 36000, 0.8);
logicEFM1_unison_test = sy.logicEFM1(3, 4, 0, 0, 1, 0.35, 8.9, 0.7, 0, 0.2, 35, 1,
                                     0.8, 1, 0.8, 1, 5, 1200, 0.3, 500, 0, 2000, 0.1, 400,
                                     261.63, ba.time < 36000, 0.8);
```

#### References

* Apple, Logic Pro User Guide, "EFM1".

## Drum Synthesis

Drum Synthesis ported in Faust from a version written in [Elementary](https://www.elementary.audio/) 
and JavaScript by Nick Thompson. 

#### References

* [https://www.nickwritesablog.com/drum-synthesis-in-javascript/](https://www.nickwritesablog.com/drum-synthesis-in-javascript/)

----

### `(sy.)kick`

Kick drum synthesis via a pitched sine sweep.

#### Usage 

```
kick(pitch, click, attack, decay, drive, gate) : _
```

Where:

* `pitch`: the base frequency of the kick drum in Hz
* `click`: the speed of the pitch envelope, tuned for [0.005s, 1s]
* `attack`: attack time in seconds, tuned for [0.005s, 0.4s]
* `decay`: decay time in seconds, tuned for [0.005s, 4.0s]
* `drive`: a gain multiplier going into the saturator. Tuned for [1, 10]
* `gate`: the gate which triggers the amp envelope

#### Test
```
sy = library("synths.lib");
kick_test = sy.kick(
    hslider("kick:pitch", 60, 30, 120, 0.1),
    hslider("kick:click", 0.2, 0.005, 1, 0.001),
    0.01,
    0.5,
    hslider("kick:drive", 3, 1, 10, 0.1),
    button("kick:gate")
);
```

#### References

* [https://github.com/nick-thompson/drumsynth/blob/master/kick.js](https://github.com/nick-thompson/drumsynth/blob/master/kick.js)

----

### `(sy.)clap`

Clap synthesis via filtered white noise.

#### Usage 

```
clap(tone, attack, decay, gate) : _
```

Where:

* `tone`: bandpass filter cutoff frequency, tuned for [400Hz, 3500Hz]
* `attack`: attack time in seconds, tuned for [0s, 0.2s]
* `decay`: decay time in seconds, tuned for [0s, 4.0s]
* `gate`: the gate which triggers the amp envelope

#### Test
```
sy = library("synths.lib");
clap_test = sy.clap(
    hslider("clap:tone", 1200, 400, 3500, 10),
    0.01,
    0.6,
    button("clap:gate")
);
```

#### References

* [https://github.com/nick-thompson/drumsynth/blob/master/clap.js](https://github.com/nick-thompson/drumsynth/blob/master/clap.js)

----

### `(sy.)hat`

Hi hat drum synthesis via phase modulation.

#### Usage 

```
hat(pitch, tone, attack, decay, gate): _
```

Where:

* `pitch`: base frequency in the range [317Hz, 3170Hz]
* `tone`: bandpass filter cutoff frequency, tuned for [800Hz, 18kHz]
* `attack`: attack time in seconds, tuned for [0.005s, 0.2s]
* `decay`: decay time in seconds, tuned for [0.005s, 4.0s]
* `gate`: the gate which triggers the amp envelope

#### Test
```
sy = library("synths.lib");
hat_test = sy.hat(
    hslider("hat:pitch", 800, 317, 3170, 1),
    hslider("hat:tone", 5000, 800, 18000, 10),
    0.005,
    0.3,
    button("hat:gate")
);
```

#### References

* [https://github.com/nick-thompson/drumsynth/blob/master/hat.js](https://github.com/nick-thompson/drumsynth/blob/master/hat.js)
