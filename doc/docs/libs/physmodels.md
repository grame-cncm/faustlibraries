#  physmodels.lib 

Faust physical modeling library. Its official prefix is `pm`.

This library provides an environment to facilitate physical modeling of musical
instruments. It includes waveguide, mass-spring, and digital wave
models for strings, membranes, bars, and resonant systems used in physical modeling
synthesis and acoustic simulation research. It contains dozens of functions implementing
low and high level elements going from a simple waveguide to fully operational models with
built-in UI, etc.

It is organized as follows:

* [Global Variables](#global-variables): useful pre-defined variables for
physical modeling (e.g., speed of sound, etc.).
* [Conversion Tools](#conversion-tools-1): conversion functions specific
to physical modeling (e.g., length to frequency, etc.).
* [Bidirectional Utilities](#bidirectional-utilities): functions to create
bidirectional block diagrams for physical modeling.
* [Basic Elements](#basic-elements-1): waveguides, specific types of filters, etc.
* [String Instruments](#string-instruments): various types of strings
(e.g., steel, nylon, etc.), bridges, guitars, etc.
* [Bowed String Instruments](#bowed-string-instruments): parts and models
specific to bowed string instruments (e.g., bows, bridges, violins, etc.).
* [Wind Instrument](#wind-instruments): parts and models specific to wind
instruments (e.g., reeds, mouthpieces, flutes, clarinets, etc.).
* [Exciters](#exciters): pluck generators, "blowers", etc.
* [Modal Percussions](#modal-percussions): percussion instruments based on
modal models.
* [Vocal Synthesis](#vocal-synthesis): functions for various vocal synthesis
techniques (e.g., fof, source/filter, etc.) and vocal synthesizers.
* [Misc Functions](#misc-functions): any other functions that don't fit in
the previous category (e.g., nonlinear filters, etc.).

This library is part of the Faust Physical Modeling ToolKit.
More information on how to use this library can be found on this [page](https://ccrma.stanford.edu/~rmichon/pmFaust) or this [video](https://faust.grame.fr/community/events/#introduction-to-the-faust-physical-modeling-toolkit-romain-michon). Tutorials on how to make
physical models of musical instruments using Faust can be found
[here](https://ccrma.stanford.edu/~rmichon/faustTutorials/#making-physical-models-of-musical-instruments-with-faust) as well.

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/physmodels.lib](https://github.com/grame-cncm/faustlibraries/blob/master/physmodels.lib)

## Global Variables

Useful pre-defined variables for physical modeling.

----

### `(pm.)speedOfSound`

Speed of sound in meters per second (340m/s).

----

### `(pm.)maxLength`

The default maximum length (3) in meters of strings and tubes used in this
library. This variable should be overriden to allow longer strings or tubes.

## Conversion Tools

Useful conversion tools for physical modeling.

----

### `(pm.)f2l`

Frequency to length in meters.

#### Usage

```
f2l(freq) : distanceInMeters
```

Where:

* `freq`: the frequency

#### Test
```
pm = library("physmodels.lib");
f2l_test = pm.f2l(440);
```

----

### `(pm.)l2f`

Length in meters to frequency.

#### Usage

```
l2f(length) : freq
```

Where:

* `length`: length/distance in meters

#### Test
```
pm = library("physmodels.lib");
l2f_test = pm.l2f(0.75);
```

----

### `(pm.)l2s`

Length in meters to number of samples.

#### Usage

```
l2s(l) : numberOfSamples
```

Where:

* `l`: length in meters

#### Test
```
pm = library("physmodels.lib");
l2s_test = pm.l2s(1.2);
```

## Bidirectional Utilities

Set of fundamental functions to create bi-directional block diagrams in Faust.
These elements are used as the basis of this library to connect high level
elements (e.g., mouthpieces, strings, bridge, instrument body, etc.). Each
block has 3 inputs and 3 outputs. The first input/output carry left going
waves, the second input/output carry right going waves, and the third
input/output is used to carry any potential output signal to the end of the
algorithm.

----

### `(pm.)basicBlock`

Empty bidirectional block to be used with [`chain`](#chain): 3 signals ins
and 3 signals out.

#### Usage

```
chain(basicBlock : basicBlock : etc.)
```

#### Test
```
pm = library("physmodels.lib");
basicBlock_test = 0,0,0 : pm.basicBlock;
```

----

### `(pm.)chain`

Creates a chain of bidirectional blocks.
Blocks must have 3 inputs and outputs. The first input/output carry left
going waves, the second input/output carry right going waves, and the third
input/output is used to carry any potential output signal to the end of the
algorithm. The implied one sample delay created by the `~` operator is
generalized to the left and right going waves. Thus, `n` blocks in `chain()`
will add an `n` samples delay to both left and right going waves.

#### Usage

```
leftGoingWaves,rightGoingWaves,mixedOutput : chain( A : B ) : leftGoingWaves,rightGoingWaves,mixedOutput
with {
   A = _,_,_;
   B = _,_,_;
};
```

#### Test
```
pm = library("physmodels.lib");
chain_test = 0,0,0 : pm.chain(pm.in(0.1) : pm.basicBlock);
```

----

### `(pm.)inLeftWave`

Adds a signal to left going waves anywhere in a [`chain`](#chain) of blocks.

#### Usage

```
model(x) = chain(A : inLeftWave(x) : B)
```

Where `A` and `B` are bidirectional blocks and `x` is the signal added to left
going waves in that chain.

#### Test
```
pm = library("physmodels.lib");
inLeftWave_test = 0,0,0 : pm.inLeftWave(0.25);
```

----

### `(pm.)inRightWave`

Adds a signal to right going waves anywhere in a [`chain`](#chain) of blocks.

#### Usage

```
model(x) = chain(A : inRightWave(x) : B)
```

Where `A` and `B` are bidirectional blocks and `x` is the signal added to right
going waves in that chain.

#### Test
```
pm = library("physmodels.lib");
inRightWave_test = 0,0,0 : pm.inRightWave(0.25);
```

----

### `(pm.)in`

Adds a signal to left and right going waves anywhere in a [`chain`](#chain)
of blocks.

#### Usage

```
model(x) = chain(A : in(x) : B)
```

Where `A` and `B` are bidirectional blocks and `x` is the signal added to
left and right going waves in that chain.

#### Test
```
pm = library("physmodels.lib");
in_test = 0,0,0 : pm.in(0.25);
```

----

### `(pm.)outLeftWave`

Sends the signal of left going waves to the output channel of the [`chain`](#chain).

#### Usage

```
chain(A : outLeftWave : B)
```

Where `A` and `B` are bidirectional blocks.

#### Test
```
pm = library("physmodels.lib");
outLeftWave_test = pm.outLeftWave(0.1, 0.2, 0.3);
```

----

### `(pm.)outRightWave`

Sends the signal of right going waves to the output channel of the [`chain`](#chain).

#### Usage

```
chain(A : outRightWave : B)
```

Where `A` and `B` are bidirectional blocks.

#### Test
```
pm = library("physmodels.lib");
outRightWave_test = pm.outRightWave(0.1, 0.2, 0.3);
```

----

### `(pm.)out`

Sends the signal of right and left going waves to the output channel of the
[`chain`](#chain).

#### Usage

```
chain(A : out : B)
```

Where `A` and `B` are bidirectional blocks.

#### Test
```
pm = library("physmodels.lib");
out_test = pm.out(0.1, 0.2, 0.3);
```

----

### `(pm.)terminations`

Creates terminations on both sides of a [`chain`](#chain) without closing
the inputs and outputs of the bidirectional signals chain. As for
[`chain`](#chain), this function adds a 1 sample delay to the bidirectional
signal, both ways. Of course, this function can be nested within a
[`chain`](#chain).

#### Usage

```
terminations(a,b,c)
with {
   a = *(-1); // left termination
   b = chain(D : E : F); // bidirectional chain of blocks (D, E, F, etc.)
   c = *(-1); // right termination
};
```

#### Test
```
pm = library("physmodels.lib");
terminations_test = 0,0,0 : pm.terminations(*(-1), pm.basicBlock, *(-1));
```

----

### `(pm.)lTermination`

Creates a termination on the left side of a [`chain`](#chain) without
closing the inputs and outputs of the bidirectional signals chain. This
function adds a 1 sample delay near the termination and can be nested
within another [`chain`](#chain).

#### Usage

```
lTerminations(a,b)
with {
   a = *(-1); // left termination
   b = chain(D : E : F); // bidirectional chain of blocks (D, E, F, etc.)
};
```

#### Test
```
pm = library("physmodels.lib");
lTermination_test = 0,0,0 : pm.lTermination(*(-1), pm.basicBlock);
```

----

### `(pm.)rTermination`

Creates a termination on the right side of a [`chain`](#chain) without
closing the inputs and outputs of the bidirectional signals chain. This
function adds a 1 sample delay near the termination and can be nested
within another [`chain`](#chain).

#### Usage

```
rTerminations(b,c)
with {
   b = chain(D : E : F); // bidirectional chain of blocks (D, E, F, etc.)
   c = *(-1); // right termination
};
```

#### Test
```
pm = library("physmodels.lib");
rTermination_test = 0,0,0 : pm.rTermination(pm.basicBlock, *(-1));
```

----

### `(pm.)closeIns`

Closes the inputs of a bidirectional chain in all directions.

#### Usage

```
closeIns : chain(...) : _,_,_
```

#### Test
```
pm = library("physmodels.lib");
closeIns_test = pm.closeIns;
```

----

### `(pm.)closeOuts`

Closes the outputs of a bidirectional chain in all directions except for the
main signal output (3d output).

#### Usage

```
_,_,_ : chain(...) : _
```

#### Test
```
pm = library("physmodels.lib");
closeOuts_test = 0,0,0 : pm.closeOuts;
```

----

### `(pm.)endChain`

Closes the inputs and outputs of a bidirectional chain in all directions
except for the main signal output (3d output).

#### Usage

```
endChain(chain(...)) : _
```

#### Test
```
pm = library("physmodels.lib");
endChain_test = 0,0,0 : pm.endChain(pm.basicBlock);
```

## Basic Elements

Basic elements for physical modeling (e.g., waveguides, specific filters,
etc.).

----

### `(pm.)waveguideN`

A series of waveguide functions based on various types of delays (see
[`fdelay[n]`](#fdelayn)).

#### List of functions

* `waveguideUd`: unit delay waveguide
* `waveguideFd`: fractional delay waveguide
* `waveguideFd2`: second order fractional delay waveguide
* `waveguideFd4`: fourth order fractional delay waveguide

#### Usage

```
chain(A : waveguideUd(nMax,n) : B)
```

Where:

* `nMax`: the maximum length of the delays in the waveguide
* `n`: the length of the delay lines in samples.

#### Test
```
pm = library("physmodels.lib");
waveguideUd_test = 0,0,0 : pm.waveguideUd(512, 32);
waveguideFd_test = 0,0,0 : pm.waveguideFd(512, 32);
waveguideFd2_test = 0,0,0 : pm.waveguideFd2(512, 32);
waveguideFd4_test = 0,0,0 : pm.waveguideFd4(512, 32);
```

----

### `(pm.)waveguide`

Standard `pm.lib` waveguide (based on [`waveguideFd4`](#waveguiden)).

#### Usage

```
chain(A : waveguide(nMax,n) : B)
```

Where:

* `nMax`: the maximum length of the delays in the waveguide
* `n`: the length of the delay lines in samples.

#### Test
```
pm = library("physmodels.lib");
waveguide_test = 0,0,0 : pm.waveguide(512, 32);
```

----

### `(pm.)bridgeFilter`

Generic two zeros bridge FIR filter (as implemented in the
[STK](https://ccrma.stanford.edu/software/stk/)) that can be used to
implement the reflectance violin, guitar, etc. bridges.

#### Usage

```
_ : bridge(brightness,absorption) : _
```

Where:

* `brightness`: controls the damping of high frequencies (0-1)
* `absorption`: controls the absorption of the brige and thus the t60 of
the string plugged to it (0-1) (1 = 20 seconds)

#### Test
```
pm = library("physmodels.lib");
bridgeFilter_test = pm.bridgeFilter(0.6, 0.4, os.osc(110));
```

----

### `(pm.)modeFilter`

Resonant bandpass filter that can be used to implement a single resonance
(mode).

#### Usage

```
_ : modeFilter(freq,t60,gain) : _
```

Where:

* `freq`: mode frequency
* `t60`: mode resonance duration (in seconds)
* `gain`: mode gain (0-1)

#### Test
```
pm = library("physmodels.lib");
modeFilter_test = pm.modeFilter(440, 1.5, 0.8);
```

## String Instruments

Low and high level string instruments parts. Most of the elements in
this section can be used in a bidirectional chain.

----

### `(pm.)stringSegment`

A string segment without terminations (just a simple waveguide).

#### Usage

```
chain(A : stringSegment(maxLength,length) : B)
```

Where:

* `maxLength`: the maximum length of the string in meters (should be static)
* `length`: the length of the string in meters

#### Test
```
pm = library("physmodels.lib");
stringSegment_test = 0,0,0 : pm.stringSegment(1.0, 0.5);
```

----

### `(pm.)openString`

A bidirectional block implementing a basic "generic" string with a
selectable excitation position. Lowpass filters are built-in and
allow to simulate the effect of dispersion on the sound and thus
to change the "stiffness" of the string.

#### Usage

```
chain(... : openString(length,stiffness,pluckPosition,excitation) : ...)
```

Where:

* `length`: the length of the string in meters
* `stiffness`: the stiffness of the string (0-1) (1 for max stiffness)
* `pluckPosition`: excitation position (0-1) (1 is bottom)
* `excitation`: the excitation signal

#### Test
```
pm = library("physmodels.lib");
openString_test = 0,0,0 : pm.openString(0.8, 0.5, 0.2, pm.impulseExcitation(button("gate")));
```

----

### `(pm.)nylonString`

A bidirectional block implementing a basic nylon string with selectable
excitation position. This element is based on [`openString`](#openstring)
and has a fix stiffness corresponding to that of a nylon string.

#### Usage

```
chain(... : nylonString(length,pluckPosition,excitation) : ...)
```

Where:

* `length`: the length of the string in meters
* `pluckPosition`: excitation position (0-1) (1 is bottom)
* `excitation`: the excitation signal

#### Test
```
pm = library("physmodels.lib");
nylonString_test = 0,0,0 : pm.nylonString(0.8, 0.3, pm.impulseExcitation(button("gate")));
```

----

### `(pm.)steelString`

A bidirectional block implementing a basic steel string with selectable
excitation position. This element is based on [`openString`](#openstring)
and has a fix stiffness corresponding to that of a steel string.

#### Usage

```
chain(... : steelString(length,pluckPosition,excitation) : ...)
```

Where:

* `length`: the length of the string in meters
* `pluckPosition`: excitation position (0-1) (1 is bottom)
* `excitation`: the excitation signal

#### Test
```
pm = library("physmodels.lib");
steelString_test = 0,0,0 : pm.steelString(0.8, 0.3, pm.impulseExcitation(button("gate")));
```

----

### `(pm.)openStringPick`

A bidirectional block implementing a "generic" string with selectable
excitation position. It also has a built-in pickup whose position is the
same as the excitation position. Thus, moving the excitation position
will also move the pickup.

#### Usage

```
chain(... : openStringPick(length,stiffness,pluckPosition,excitation) : ...)
```

Where:

* `length`: the length of the string in meters
* `stiffness`: the stiffness of the string (0-1) (1 for max stiffness)
* `pluckPosition`: excitation position (0-1) (1 is bottom)
* `excitation`: the excitation signal

#### Test
```
pm = library("physmodels.lib");
openStringPick_test = 0,0,0 : pm.openStringPick(0.8, 0.4, 0.3, pm.impulseExcitation(button("gate")));
```

----

### `(pm.)openStringPickUp`

A bidirectional block implementing a "generic" string with selectable
excitation position and stiffness. It also has a built-in pickup whose
position can be independenly selected. The only constraint is that the
pickup has to be placed after the excitation position.

#### Usage

```
chain(... : openStringPickUp(length,stiffness,pluckPosition,excitation) : ...)
```

Where:

* `length`: the length of the string in meters
* `stiffness`: the stiffness of the string (0-1) (1 for max stiffness)
* `pluckPosition`: pluck position between the top of the string and the
pickup (0-1) (1 for same as pickup position)
* `pickupPosition`: position of the pickup on the string (0-1) (1 is bottom)
* `excitation`: the excitation signal

#### Test
```
pm = library("physmodels.lib");
openStringPickUp_test = 0,0,0 : pm.openStringPickUp(0.8, 0.4, 0.6, 0.7, pm.impulseExcitation(button("gate")));
```

----

### `(pm.)openStringPickDown`

A bidirectional block implementing a "generic" string with selectable
excitation position and stiffness. It also has a built-in pickup whose
position can be independenly selected. The only constraint is that the
pickup has to be placed before the excitation position.

#### Usage

```
chain(... : openStringPickDown(length,stiffness,pluckPosition,excitation) : ...)
```

Where:

* `length`: the length of the string in meters
* `stiffness`: the stiffness of the string (0-1) (1 for max stiffness)
* `pluckPosition`: pluck position on the string (0-1) (1 is bottom)
* `pickupPosition`: position of the pickup between the top of the string
and the excitation position (0-1) (1 is excitation position)
* `excitation`: the excitation signal

#### Test
```
pm = library("physmodels.lib");
openStringPickDown_test = 0,0,0 : pm.openStringPickDown(0.8, 0.4, 0.6, 0.5, pm.impulseExcitation(button("gate")));
```

----

### `(pm.)ksReflexionFilter`

The "typical" one-zero Karplus-strong feedforward reflexion filter. This
filter will be typically used in a termination (see below).

#### Usage

```
terminations(_,chain(...),ksReflexionFilter)
```

#### Test
```
pm = library("physmodels.lib");
os = library("oscillators.lib");
ksReflexionFilter_test = os.osc(220) : pm.ksReflexionFilter;
```

----

### `(pm.)rStringRigidTermination`

Bidirectional block implementing a right rigid string termination (no damping,
just phase inversion).

#### Usage

```
chain(rStringRigidTermination : stringSegment : ...)
```

#### Test
```
pm = library("physmodels.lib");
rStringRigidTermination_test = 0,0,0 : pm.rStringRigidTermination;
```

----

### `(pm.)lStringRigidTermination`

Bidirectional block implementing a left rigid string termination (no damping,
just phase inversion).

#### Usage

```
chain(... : stringSegment : lStringRigidTermination)
```

#### Test
```
pm = library("physmodels.lib");
lStringRigidTermination_test = 0,0,0 : pm.lStringRigidTermination;
```

----

### `(pm.)elecGuitarBridge`

Bidirectional block implementing a simple electric guitar bridge. This
block is based on [`bridgeFilter`](#bridgeFilter). The bridge doesn't
implement transmittance since it is not meant to be connected to a
body (unlike acoustic guitar). It also partially sets the resonance
duration of the string with the nuts used on the other side.

#### Usage

```
chain(... : stringSegment : elecGuitarBridge)
```

#### Test
```
pm = library("physmodels.lib");
elecGuitarBridge_test = 0,0,0 : pm.elecGuitarBridge;
```

----

### `(pm.)elecGuitarNuts`

Bidirectional block implementing a simple electric guitar nuts. This
block is based on [`bridgeFilter`](#bridgeFilter) and does essentially
the same thing as [`elecGuitarBridge`](#elecguitarbridge), but on the
other side of the chain. It also partially sets the resonance duration of
the string with the bridge used on the other side.

#### Usage

```
chain(elecGuitarNuts : stringSegment : ...)
```

#### Test
```
pm = library("physmodels.lib");
elecGuitarNuts_test = 0,0,0 : pm.elecGuitarNuts;
```

----

### `(pm.)guitarBridge`

Bidirectional block implementing a simple acoustic guitar bridge. This
bridge damps more hight frequencies than
[`elecGuitarBridge`](#elecguitarbridge) and implements a transmittance
filter. It also partially sets the resonance duration of the string with
the nuts used on the other side.

#### Usage

```
chain(... : stringSegment : guitarBridge)
```

#### Test
```
pm = library("physmodels.lib");
guitarBridge_test = 0,0,0 : pm.guitarBridge;
```

----

### `(pm.)guitarNuts`

Bidirectional block implementing a simple acoustic guitar nuts. This
nuts damps more hight frequencies than
[`elecGuitarNuts`](#elecguitarnuts) and implements a transmittance
filter. It also partially sets the resonance duration of the string with
the bridge used on the other side.

#### Usage

```
chain(guitarNuts : stringSegment : ...)
```

#### Test
```
pm = library("physmodels.lib");
guitarNuts_test = 0,0,0 : pm.guitarNuts;
```

----

### `(pm.)idealString`

An "ideal" string with rigid terminations and where the plucking position
and the pick-up position are the same. Since terminations are rigid, this
string will ring forever.

#### Usage

```
1-1' : idealString(length,reflexion,xPosition,excitation)
```

With:

* `length`: the length of the string in meters
* `pluckPosition`: the plucking position (0.001-0.999)
* `excitation`: the input signal for the excitation.

#### Test
```
pm = library("physmodels.lib");
idealString_test = 0,0,0 : pm.idealString(0.9, 0.2, pm.impulseExcitation(button("gate")));
```

----

### `(pm.)ks`

A Karplus-Strong string (in that case, the string is implemented as a
one dimension waveguide).

#### Usage

```
ks(length,damping,excitation) : _
```

Where:

* `length`: the length of the string in meters
* `damping`: string damping (0-1)
* `excitation`: excitation signal

#### Test
```
pm = library("physmodels.lib");
ks_test = pm.ks(0.9, 0.3, pm.impulseExcitation(button("gate")));
```

----

### `(pm.)ks_ui_MIDI`

Ready-to-use, MIDI-enabled Karplus-Strong string with buil-in UI.

#### Usage

```
ks_ui_MIDI : _
```

#### Test
```
pm = library("physmodels.lib");
ks_ui_MIDI_test = pm.ks_ui_MIDI;
```

----

### `(pm.)elecGuitarModel`

A simple electric guitar model (without audio effects, of course) with
selectable pluck position.
This model implements a single string. Additional strings should be created
by making a polyphonic application out of this function. Pitch is changed by
changing the length of the string and not through a finger model.

#### Usage

```
elecGuitarModel(length,pluckPosition,mute,excitation) : _
```

Where:

* `length`: the length of the string in meters
* `pluckPosition`: pluck position (0-1) (1 is on the bridge)
* `mute`: mute coefficient (1 for no mute and 0 for instant mute)
* `excitation`: excitation signal

#### Test
```
pm = library("physmodels.lib");
elecGuitarModel_test = pm.elecGuitarModel(0.9, 0.3, 0.8, pm.impulseExcitation(button("gate")));
```

----

### `(pm.)elecGuitar`

A simple electric guitar model with steel strings (based on
[`elecGuitarModel`](#elecguitarmodel)) implementing an excitation
model.
This model implements a single string. Additional strings should be created
by making a polyphonic application out of this function.

#### Usage

```
elecGuitar(length,pluckPosition,trigger) : _
```

Where:

* `length`: the length of the string in meters
* `pluckPosition`: pluck position (0-1) (1 is on the bridge)
* `mute`: mute coefficient (1 for no mute and 0 for instant mute)
* `gain`: gain of the pluck (0-1)
* `trigger`: trigger signal (1 for on, 0 for off)

#### Test
```
pm = library("physmodels.lib");
elecGuitar_test = pm.elecGuitar(0.9, 0.3, 0.8, 0.6, button("gate"));
```

----

### `(pm.)elecGuitar_ui_MIDI`

Ready-to-use MIDI-enabled electric guitar physical model with built-in UI.

#### Usage

```
elecGuitar_ui_MIDI : _
```

#### Test
```
pm = library("physmodels.lib");
elecGuitar_ui_MIDI_test = pm.elecGuitar_ui_MIDI;
```

----

### `(pm.)guitarBody`

WARNING: not implemented yet!
Bidirectional block implementing a simple acoustic guitar body.

#### Usage

```
chain(... : guitarBody)
```

#### Test
```
pm = library("physmodels.lib");
guitarBody_test = 0,0,0 : pm.guitarBody;
```

----

### `(pm.)guitarModel`

A simple acoustic guitar model with steel strings and selectable excitation
position. This model implements a single string. Additional strings should be created
by making a polyphonic application out of this function. Pitch is changed by
changing the length of the string and not through a finger model.
WARNING: this function doesn't currently implement a body (just strings and
bridge).

#### Usage

```
guitarModel(length,pluckPosition,excitation) : _
```

Where:

* `length`: the length of the string in meters
* `pluckPosition`: pluck position (0-1) (1 is on the bridge)
* `excitation`: excitation signal

#### Test
```
pm = library("physmodels.lib");
guitarModel_test = pm.guitarModel(0.9, 0.25, pm.impulseExcitation(button("gate")));
```

----

### `(pm.)guitar`

A simple acoustic guitar model with steel strings (based on
[`guitarModel`](#guitarmodel)) implementing an excitation model.
This model implements a single string. Additional strings should be created
by making a polyphonic application out of this function.

#### Usage

```
guitar(length,pluckPosition,trigger) : _
```

Where:

* `length`: the length of the string in meters
* `pluckPosition`: pluck position (0-1) (1 is on the bridge)
* `gain`: gain of the excitation
* `trigger`: trigger signal (1 for on, 0 for off)

#### Test
```
pm = library("physmodels.lib");
guitar_test = pm.guitar(0.9, 0.25, 0.8, button("gate"));
```

----

### `(pm.)guitar_ui_MIDI`

Ready-to-use MIDI-enabled steel strings acoustic guitar physical model with
built-in UI.

#### Usage

```
guitar_ui_MIDI : _
```

#### Test
```
pm = library("physmodels.lib");
guitar_ui_MIDI_test = pm.guitar_ui_MIDI;
```

----

### `(pm.)nylonGuitarModel`

A simple acoustic guitar model with nylon strings and selectable excitation
position. This model implements a single string. Additional strings should be created
by making a polyphonic application out of this function. Pitch is changed by
changing the length of the string and not through a finger model.
WARNING: this function doesn't currently implement a body (just strings and
bridge).

#### Usage

```
nylonGuitarModel(length,pluckPosition,excitation) : _
```

Where:

* `length`: the length of the string in meters
* `pluckPosition`: pluck position (0-1) (1 is on the bridge)
* `excitation`: excitation signal

#### Test
```
pm = library("physmodels.lib");
nylonGuitarModel_test = pm.nylonGuitarModel(0.9, 0.25, pm.impulseExcitation(button("gate")));
```

----

### `(pm.)nylonGuitar`

A simple acoustic guitar model with nylon strings (based on
[`nylonGuitarModel`](#nylonguitarmodel)) implementing an excitation model.
This model implements a single string. Additional strings should be created
by making a polyphonic application out of this function.

#### Usage

```
nylonGuitar(length,pluckPosition,trigger) : _
```

Where:

* `length`: the length of the string in meters
* `pluckPosition`: pluck position (0-1) (1 is on the bridge)
* `gain`: gain of the excitation (0-1)
* `trigger`: trigger signal (1 for on, 0 for off)

#### Test
```
pm = library("physmodels.lib");
nylonGuitar_test = pm.nylonGuitar(0.9, 0.25, 0.8, button("gate"));
```

----

### `(pm.)nylonGuitar_ui_MIDI`

Ready-to-use MIDI-enabled nylon strings acoustic guitar physical model with
built-in UI.

#### Usage

```
nylonGuitar_ui_MIDI : _
```

#### Test
```
pm = library("physmodels.lib");
nylonGuitar_ui_MIDI_test = pm.nylonGuitar_ui_MIDI;
```

----

### `(pm.)modeInterpRes`

Modular string instrument resonator based on IR measurements made on 3D 
printed models. The 2D space allowing for the control of the shape and the
scale of the model is enabled by interpolating between modes parameters.
More information about this technique/project can be found here: 
* [https://ccrma.stanford.edu/~rmichon/3dPrintingModeling/](https://ccrma.stanford.edu/~rmichon/3dPrintingModeling/).

#### Usage

```
_ : modeInterpRes(nModes,x,y) : _
```

Where:

* `nModes`: number of modeled modes (40 max)
* `x`: shape of the resonator (0: square, 1: square with rounded corners, 2: round)
* `y`: scale of the resonator (0: small, 1: medium, 2: large)

#### Test
```
pm = library("physmodels.lib");
os = library("oscillators.lib");
modeInterpRes_test = os.osc(110) : pm.modeInterpRes(20, 1.0, 1.5);
```

----

### `(pm.)modularInterpBody`

Bidirectional block implementing a modular string instrument resonator 
(see [`modeInterpRes`](#pm.modeinterpres)).

#### Usage

```
chain(... : modularInterpBody(nModes,shape,scale) : ...)
```

Where:

* `nModes`: number of modeled modes (40 max)
* `shape`: shape of the resonator (0: square, 1: square with rounded corners, 2: round)
* `scale`: scale of the resonator (0: small, 1: medium, 2: large)

#### Test
```
pm = library("physmodels.lib");
modularInterpBody_test = 0,0,0 : pm.modularInterpBody(20, 1.0, 1.5);
```

----

### `(pm.)modularInterpStringModel`

String instrument model with a modular body (see 
[`modeInterpRes`](#pm.modeinterpres) and 
* [https://ccrma.stanford.edu/~rmichon/3dPrintingModeling/](https://ccrma.stanford.edu/~rmichon/3dPrintingModeling/)).

#### Usage

```
modularInterpStringModel(length,pluckPosition,shape,scale,bodyExcitation,stringExcitation) : _
```

Where:

* `stringLength`: the length of the string in meters
* `pluckPosition`: pluck position (0-1) (1 is on the bridge)
* `shape`: shape of the resonator (0: square, 1: square with rounded corners, 2: round)
* `scale`: scale of the resonator (0: small, 1: medium, 2: large)
* `bodyExcitation`: excitation signal for the body
* `stringExcitation`: excitation signal for the string

#### Test
```
pm = library("physmodels.lib");
modularInterpStringModel_test = pm.modularInterpStringModel(0.9, 0.3, 1.0, 1.5, pm.impulseExcitation(button("body")), pm.impulseExcitation(button("string")));
```

----

### `(pm.)modularInterpInstr`

String instrument with a modular body (see 
[`modeInterpRes`](#pm.modeinterpres) and 
* [https://ccrma.stanford.edu/~rmichon/3dPrintingModeling/](https://ccrma.stanford.edu/~rmichon/3dPrintingModeling/)).

#### Usage

```
modularInterpInstr(stringLength,pluckPosition,shape,scale,gain,tapBody,triggerString) : _
```

Where:

* `stringLength`: the length of the string in meters
* `pluckPosition`: pluck position (0-1) (1 is on the bridge)
* `shape`: shape of the resonator (0: square, 1: square with rounded corners, 2: round)
* `scale`: scale of the resonator (0: small, 1: medium, 2: large)
* `gain`: of the string excitation
* `tapBody`: send an impulse in the body of the instrument where the string is connected (1 for on, 0 for off)
* `triggerString`: trigger signal for the string (1 for on, 0 for off)

#### Test
```
pm = library("physmodels.lib");
modularInterpInstr_test = pm.modularInterpInstr(0.9, 0.3, 1.0, 1.5, 0.8, button("body"), button("string"));
```

----

### `(pm.)modularInterpInstr_ui_MIDI`

Ready-to-use MIDI-enabled string instrument with a modular body (see 
[`modeInterpRes`](#pm.modeinterpres) and 
* [https://ccrma.stanford.edu/~rmichon/3dPrintingModeling/](https://ccrma.stanford.edu/~rmichon/3dPrintingModeling/))
with built-in UI.

#### Usage

```
modularInterpInstr_ui_MIDI : _
```

#### Test
```
pm = library("physmodels.lib");
modularInterpInstr_ui_MIDI_test = pm.modularInterpInstr_ui_MIDI;
```

## Bowed String Instruments

Low and high level basic string instruments parts. Most of the elements in
this section can be used in a bidirectional chain.

----

### `(pm.)bowTable`

Extremely basic bow table that can be used to implement a wide range of
bow types for many different bowed string instruments (violin, cello, etc.).

#### Usage

```
excitation : bowTable(offset,slope) : _
```

Where:

* `excitation`: an excitation signal
* `offset`: table offset
* `slope`: table slope

#### Test
```
pm = library("physmodels.lib");
bowTable_test = pm.bowTable(0.4, 0.1);
```

----

### `(pm.)violinBowTable`

Violin bow table based on [`bowTable`](#bowtable).

#### Usage

```
bowVelocity : violinBowTable(bowPressure) : _
```

Where:

* `bowVelocity`: velocity of the bow/excitation signal (0-1)
* `bowPressure`: bow pressure on the string (0-1)

#### Test
```
pm = library("physmodels.lib");
violinBowTable_test = pm.violinBowTable(0.4, 0.1);
```

----

### `(pm.)bowInteraction`

Bidirectional block implementing the interaction of a bow in a
[`chain`](#chain).

#### Usage

```
chain(... : stringSegment : bowInteraction(bowTable) : stringSegment : ...)
```

Where:

* `bowTable`: the bow table

#### Test
```
pm = library("physmodels.lib");
bowInteraction_test = pm.bowInteraction((0.4, 0.05));
```

----

### `(pm.)violinBow`

Bidirectional block implementing a violin bow and its interaction with
a string.

#### Usage

```
chain(... : stringSegment : violinBow(bowPressure,bowVelocity) : stringSegment : ...)
```

Where:

* `bowVelocity`: velocity of the bow / excitation signal (0-1)
* `bowPressure`: bow pressure on the string (0-1)

#### Test
```
pm = library("physmodels.lib");
violinBow_test = pm.violinBow(0.4, 0.05);
```

----

### `(pm.)violinBowedString`

Violin bowed string bidirectional block with controllable bow position.
Terminations are not implemented in this model.

#### Usage

```
chain(nuts : violinBowedString(stringLength,bowPressure,bowVelocity,bowPosition) : bridge)
```

Where:

* `stringLength`: the length of the string in meters
* `bowVelocity`: velocity of the bow / excitation signal (0-1)
* `bowPressure`: bow pressure on the string (0-1)
* `bowPosition`: the position of the bow on the string (0-1)

#### Test
```
pm = library("physmodels.lib");
violinBowedString_test = 0,0,0 : pm.violinBowedString(0.82, 0.35, pm.violinBow(0.4, 0.05), 0.15);
```

----

### `(pm.)violinNuts`

Bidirectional block implementing simple violin nuts. This function is
based on [`bridgeFilter`](#bridgefilter).

#### Usage

```
chain(violinNuts : stringSegment : ...)
```

#### Test
```
pm = library("physmodels.lib");
violinNuts_test = 0,0,0 : pm.violinNuts;
```

----

### `(pm.)violinBridge`

Bidirectional block implementing a simple violin bridge. This function is
based on [`bridgeFilter`](#bridgefilter).

#### Usage

```
chain(... : stringSegment : violinBridge
```

#### Test
```
pm = library("physmodels.lib");
violinBridge_test = 0,0,0 : pm.violinBridge;
```

----

### `(pm.)violinBody`

Bidirectional block implementing a simple violin body (just a simple
resonant lowpass filter).

#### Usage

```
chain(... : stringSegment : violinBridge : violinBody)
```

#### Test
```
pm = library("physmodels.lib");
violinBody_test = 0,0,0 : pm.violinBody;
```

----

### `(pm.)violinModel`

Ready-to-use simple violin physical model. This model implements a single
string. Additional strings should be created
by making a polyphonic application out of this function. Pitch is changed
by changing the length of the string (and not through a finger model).

#### Usage

```
violinModel(stringLength,bowPressure,bowVelocity,bridgeReflexion,
bridgeAbsorption,bowPosition) : _
```

Where:

* `stringLength`: the length of the string in meters
* `bowVelocity`: velocity of the bow / excitation signal (0-1)
* `bowPressure`: bow pressure on the string (0-1))
* `bowPosition`: the position of the bow on the string (0-1)

#### Test
```
pm = library("physmodels.lib");
violinModel_test = pm.violinModel(0.82, 0.35, pm.violinBow(0.4, 0.05), 0.15);
```

----

### `(pm.)violin_ui`

Ready-to-use violin physical model with built-in UI.

#### Usage

```
violinModel_ui : _
```

#### Test
```
pm = library("physmodels.lib");
violin_ui_test = pm.violin_ui;
```

----

### `(pm.)violin_ui_MIDI`

Ready-to-use MIDI-enabled violin physical model with built-in UI.

#### Usage

```
violin_ui_MIDI : _
```

#### Test
```
pm = library("physmodels.lib");
violin_ui_MIDI_test = pm.violin_ui_MIDI;
```

## Wind Instruments

Low and high level basic wind instruments parts. Most of the elements in
this section can be used in a bidirectional chain.

----

### `(pm.)openTube`

A tube segment without terminations (same as [`stringSegment`](#stringsegment)).

#### Usage

```
chain(A : openTube(maxLength,length) : B)
```

Where:

* `maxLength`: the maximum length of the tube in meters (should be static)
* `length`: the length of the tube in meters

#### Test
```
pm = library("physmodels.lib");
openTube_test = pm.openTube(0.9);
```

----

### `(pm.)reedTable`

Extremely basic reed table that can be used to implement a wide range of
single reed types for many different instruments (saxophone, clarinet, etc.).

#### Usage

```
excitation : reedTable(offeset,slope) : _
```

Where:

* `excitation`: an excitation signal
* `offset`: table offset
* `slope`: table slope

#### Test
```
pm = library("physmodels.lib");
reedTable_test = pm.reedTable(0.4, 0.2);
```

----

### `(pm.)fluteJetTable`

Extremely basic flute jet table.

#### Usage

```
excitation : fluteJetTable : _
```

Where:

* `excitation`: an excitation signal

#### Test
```
pm = library("physmodels.lib");
fluteJetTable_test = pm.fluteJetTable(0.5);
```

----

### `(pm.)brassLipsTable`

Simple brass lips/mouthpiece table. Since this implementation is very basic
and that the lips and tube of the instrument are coupled to each other, the
length of that tube must be provided here.

#### Usage

```
excitation : brassLipsTable(tubeLength,lipsTension) : _
```

Where:

* `excitation`: an excitation signal (can be DC)
* `tubeLength`: length in meters of the tube connected to the mouthpiece
* `lipsTension`: tension of the lips (0-1) (default: 0.5)

#### Test
```
pm = library("physmodels.lib");
brassLipsTable_test = pm.brassLipsTable(0.3, 0.2);
```

----

### `(pm.)clarinetReed`

Clarinet reed based on [`reedTable`](#reedtable) with controllable
stiffness.

#### Usage

```
excitation : clarinetReed(stiffness) : _
```

Where:

* `excitation`: an excitation signal
* `stiffness`: reed stiffness (0-1)

#### Test
```
pm = library("physmodels.lib");
clarinetReed_test = pm.clarinetReed(0.6, 0.4, 0.1);
```

----

### `(pm.)clarinetMouthPiece`

Bidirectional block implementing a clarinet mouthpiece as well as the various
interactions happening with traveling waves. This element is ready to be
plugged to a tube...

#### Usage

```
chain(clarinetMouthPiece(reedStiffness,pressure) : tube : etc.)
```

Where:

* `pressure`: the pressure of the air flow (DC) created by the virtual performer (0-1).
This can also be any kind of signal that will directly injected in the mouthpiece
(e.g., breath noise, etc.).
* `reedStiffness`: reed stiffness (0-1)

#### Test
```
pm = library("physmodels.lib");
clarinetMouthPiece_test = pm.clarinetMouthPiece(0.6, 0.4, 0.1);
```

----

### `(pm.)brassLips`

Bidirectional block implementing a brass mouthpiece as well as the various
interactions happening with traveling waves. This element is ready to be
plugged to a tube...

#### Usage

```
chain(brassLips(tubeLength,lipsTension,pressure) : tube : etc.)
```

Where:

* `tubeLength`: length in meters of the tube connected to the mouthpiece
* `lipsTension`: tension of the lips (0-1) (default: 0.5)
* `pressure`: the pressure of the air flow (DC) created by the virtual performer (0-1).
This can also be any kind of signal that will directly injected in the mouthpiece
(e.g., breath noise, etc.).

#### Test
```
pm = library("physmodels.lib");
brassLips_test = pm.brassLips(0.3, 0.2, 0.1);
```

----

### `(pm.)fluteEmbouchure`

Bidirectional block implementing a flute embouchure as well as the various
interactions happening with traveling waves. This element is ready to be
plugged between tubes segments...

#### Usage

```
chain(... : tube : fluteEmbouchure(pressure) : tube : etc.)
```

Where:

* `pressure`: the pressure of the air flow (DC) created by the virtual
performer (0-1).
This can also be any kind of signal that will directly injected in the
mouthpiece (e.g., breath noise, etc.).

#### Test
```
pm = library("physmodels.lib");
fluteEmbouchure_test = pm.fluteEmbouchure(0.5, 0.3);
```

----

### `(pm.)wBell`

Generic wind instrument bell bidirectional block that should be placed at
the end of a [`chain`](#chain).

#### Usage

```
chain(... : wBell(opening))
```

Where:

* `opening`: the "opening" of bell (0-1)

#### Test
```
pm = library("physmodels.lib");
wBell_test = pm.wBell(0.4, 0.6);
```

----

### `(pm.)fluteHead`

Simple flute head implementing waves reflexion.

#### Usage

```
chain(fluteHead : tube : ...)
```

#### Test
```
pm = library("physmodels.lib");
fluteHead_test = pm.fluteHead(0.8, 0.4, 0.3);
```

----

### `(pm.)fluteFoot`

Simple flute foot implementing waves reflexion and dispersion.

#### Usage

```
chain(... : tube : fluteFoot)
```

#### Test
```
pm = library("physmodels.lib");
fluteFoot_test = pm.fluteFoot(0.8, 0.4, 0.3);
```

----

### `(pm.)clarinetModel`

A simple clarinet physical model without tone holes (pitch is changed by
changing the length of the tube of the instrument).

#### Usage

```
clarinetModel(length,pressure,reedStiffness,bellOpening) : _
```

Where:

* `tubeLength`: the length of the tube in meters
* `pressure`: the pressure of the air flow created by the virtual performer (0-1).
This can also be any kind of signal that will directly injected in the mouthpiece
(e.g., breath noise, etc.).
* `reedStiffness`: reed stiffness (0-1)
* `bellOpening`: the opening of bell (0-1)

#### Test
```
pm = library("physmodels.lib");
clarinetModel_test = pm.clarinetModel(0.9, 0.4, 0.3, 0.2);
```

----

### `(pm.)clarinetModel_ui`

Same as [`clarinetModel`](#clarinetModel) but with a built-in UI. This function
doesn't implement a virtual "blower", thus `pressure` remains an argument here.

#### Usage

```
clarinetModel_ui(pressure) : _
```

Where:

* `pressure`: the pressure of the air flow created by the virtual performer (0-1).
This can also be any kind of signal that will be directly injected in the mouthpiece
(e.g., breath noise, etc.).

#### Test
```
pm = library("physmodels.lib");
clarinetModel_ui_test = pm.clarinetModel_ui;
```

----

### `(pm.)clarinet_ui`

Ready-to-use clarinet physical model with built-in UI based on
[`clarinetModel`](#clarinetmodel).

#### Usage

```
clarinet_ui : _
```

#### Test
```
pm = library("physmodels.lib");
clarinet_ui_test = pm.clarinet_ui;
```

----

### `(pm.)clarinet_ui_MIDI`

Ready-to-use MIDI compliant clarinet physical model with built-in UI.

#### Usage

```
clarinet_ui_MIDI : _
```

#### Test
```
pm = library("physmodels.lib");
clarinet_ui_MIDI_test = pm.clarinet_ui_MIDI;
```

----

### `(pm.)brassModel`

A simple generic brass instrument physical model without pistons
(pitch is changed by changing the length of the tube of the instrument).
This model is kind of hard to control and might not sound very good if
bad parameters are given to it...

#### Usage

```
brassModel(tubeLength,lipsTension,mute,pressure) : _
```

Where:

* `tubeLength`: the length of the tube in meters
* `lipsTension`: tension of the lips (0-1) (default: 0.5)
* `mute`: mute opening at the end of the instrument (0-1) (default: 0.5)
* `pressure`: the pressure of the air flow created by the virtual performer (0-1).
This can also be any kind of signal that will directly injected in the mouthpiece
(e.g., breath noise, etc.).

#### Test
```
pm = library("physmodels.lib");
brassModel_test = pm.brassModel(0.9, 0.4, 0.2, 0.6);
```

----

### `(pm.)brassModel_ui`

Same as [`brassModel`](#brassModel) but with a built-in UI. This function
doesn't implement a virtual "blower", thus `pressure` remains an argument here.

#### Usage

```
brassModel_ui(pressure) : _
```

Where:

* `pressure`: the pressure of the air flow created by the virtual performer (0-1).
This can also be any kind of signal that will be directly injected in the mouthpiece
(e.g., breath noise, etc.).

#### Test
```
pm = library("physmodels.lib");
brassModel_ui_test = pm.brassModel_ui;
```

----

### `(pm.)brass_ui`

Ready-to-use brass instrument physical model with built-in UI based on
[`brassModel`](#brassmodel).

#### Usage

```
brass_ui : _
```

#### Test
```
pm = library("physmodels.lib");
brass_ui_test = pm.brass_ui;
```

----

### `(pm.)brass_ui_MIDI`

Ready-to-use MIDI-controllable brass instrument physical model with built-in UI.

#### Usage

```
brass_ui_MIDI : _
```

#### Test
```
pm = library("physmodels.lib");
brass_ui_MIDI_test = pm.brass_ui_MIDI;
```

----

### `(pm.)fluteModel`

A simple generic flute instrument physical model without tone holes
(pitch is changed by changing the length of the tube of the instrument).

#### Usage

```
fluteModel(tubeLength,mouthPosition,pressure) : _
```

Where:

* `tubeLength`: the length of the tube in meters
* `mouthPosition`: position of the mouth on the embouchure (0-1) (default: 0.5)
* `pressure`: the pressure of the air flow created by the virtual performer (0-1).
This can also be any kind of signal that will directly injected in the mouthpiece
(e.g., breath noise, etc.).

#### Test
```
pm = library("physmodels.lib");
fluteModel_test = pm.fluteModel(0.9, 0.4, 0.6);
```

----

### `(pm.)fluteModel_ui`

Same as [`fluteModel`](#fluteModel) but with a built-in UI. This function
doesn't implement a virtual "blower", thus `pressure` remains an argument here.

#### Usage

```
fluteModel_ui(pressure) : _
```

Where:

* `pressure`: the pressure of the air flow created by the virtual performer (0-1).
This can also be any kind of signal that will be directly injected in the mouthpiece
(e.g., breath noise, etc.).

#### Test
```
pm = library("physmodels.lib");
fluteModel_ui_test = pm.fluteModel_ui;
```

----

### `(pm.)flute_ui`

Ready-to-use flute physical model with built-in UI based on
[`fluteModel`](#flutemodel).

#### Usage

```
flute_ui : _
```

#### Test
```
pm = library("physmodels.lib");
flute_ui_test = pm.flute_ui;
```

----

### `(pm.)flute_ui_MIDI`

Ready-to-use MIDI-controllable flute physical model with built-in UI.

#### Usage

```
flute_ui_MIDI : _
```

#### Test
```
pm = library("physmodels.lib");
flute_ui_MIDI_test = pm.flute_ui_MIDI;
```

## Exciters

Various kind of excitation signal generators.

----

### `(pm.)impulseExcitation`

Creates an impulse excitation of one sample.

#### Usage

```
gate = button('gate');
impulseExcitation(gate) : chain;
```

Where:

* `gate`: a gate button

#### Test
```
pm = library("physmodels.lib");
impulseExcitation_test = pm.impulseExcitation(button("gate"));
```

----

### `(pm.)strikeModel`

Creates a filtered noise excitation.

#### Usage

```
gate = button('gate');
strikeModel(LPcutoff,HPcutoff,sharpness,gain,gate) : chain;
```

Where:

* `HPcutoff`: highpass cutoff frequency
* `LPcutoff`: lowpass cutoff frequency
* `sharpness`: sharpness of the attack and release (0-1)
* `gain`: gain of the excitation
* `gate`: a gate button/trigger signal (0/1)

#### Test
```
pm = library("physmodels.lib");
strikeModel_test = pm.strikeModel(200, 4000, 0.5, 0.8, button("gate"));
```

----

### `(pm.)strike`

Strikes generator with controllable excitation position.

#### Usage

```
gate = button('gate');
strike(exPos,sharpness,gain,gate) : chain;
```

Where:

* `exPos`: excitation position wiht 0: for max low freqs and 1: for max high
freqs. So, on membrane for example, 0 would be the middle and 1 the edge
* `sharpness`: sharpness of the attack and release (0-1)
* `gain`: gain of the excitation
* `gate`: a gate button/trigger signal (0/1)

#### Test
```
pm = library("physmodels.lib");
strike_test = pm.strike(0.4, 0.5, 0.8, button("gate"));
```

----

### `(pm.)pluckString`

Creates a plucking excitation signal.

#### Usage

```
trigger = button('gate');
pluckString(stringLength,cutoff,maxFreq,sharpness,trigger)
```

Where:

* `stringLength`: length of the string to pluck
* `cutoff`: cutoff ratio (1 for default)
* `maxFreq`: max frequency ratio (1 for default)
* `sharpness`: sharpness of the attack and release (1 for default)
* `gain`: gain of the excitation (0-1)
* `trigger`: trigger signal (1 for on, 0 for off)

#### Test
```
pm = library("physmodels.lib");
pluckString_test = pm.pluckString(0.9, 1, 1, 1, 0.6, button("gate"));
```

----

### `(pm.)blower`

A virtual blower creating a DC signal with some breath noise in it.

#### Usage

```
blower(pressure,breathGain,breathCutoff) : _
```

Where:

* `pressure`: pressure (0-1)
* `breathGain`: breath noise gain (0-1) (recommended: 0.005)
* `breathCutoff`: breath cuttoff frequency (Hz) (recommended: 2000)

#### Test
```
pm = library("physmodels.lib");
blower_test = pm.blower(0.5, 0.05, 2000, 5, 0.2);
```

----

### `(pm.)blower_ui`

Same as [`blower`](#blower) but with a built-in UI.

#### Usage

```
blower : somethingToBeBlown
```

#### Test
```
pm = library("physmodels.lib");
blower_ui_test = pm.blower_ui;
```

## Modal Percussions

High and low level functions for modal synthesis of percussion instruments.

----

### `(pm.)djembeModel`

Dirt-simple djembe modal physical model. Mode parameters are empirically
calculated and don't correspond to any measurements or 3D model. They
kind of sound good though :).

#### Usage

```
excitation : djembeModel(freq)
```

Where:

* `excitation`: excitation signal
* `freq`: fundamental frequency of the bar

#### Test
```
pm = library("physmodels.lib");
djembeModel_test = pm.djembeModel(110);
```

----

### `(pm.)djembe`

Dirt-simple djembe modal physical model. Mode parameters are empirically
calculated and don't correspond to any measurements or 3D model. They
kind of sound good though :).

This model also implements a virtual "exciter".

#### Usage

```
djembe(freq,strikePosition,strikeSharpness,gain,trigger)
```

Where:

* `freq`: fundamental frequency of the model
* `strikePosition`: strike position (0 for the middle of the membrane and
1 for the edge)
* `strikeSharpness`: sharpness of the strike (0-1, default: 0.5)
* `gain`: gain of the strike
* `trigger`: trigger signal (0: off, 1: on)

#### Test
```
pm = library("physmodels.lib");
djembe_test = pm.djembe(110, 0.3, 0.5, 0.8, button("gate"));
```

----

### `(pm.)djembe_ui_MIDI`

Simple MIDI controllable djembe physical model with built-in UI.

#### Usage

```
djembe_ui_MIDI : _
```

#### Test
```
pm = library("physmodels.lib");
djembe_ui_MIDI_test = pm.djembe_ui_MIDI;
```

----

### `(pm.)marimbaBarModel`

Generic marimba tone bar modal model.

This model was generated using
`mesh2faust` from a 3D CAD model of a marimba tone bar
(`libraries/modalmodels/marimbaBar`). The corresponding CAD model is that
of a C2 tone bar (original fundamental frequency: ~65Hz). While
`marimbaBarModel` allows to translate the harmonic content of the generated
sound by providing a frequency (`freq`), mode transposition has limits and
the model will sound less and less like a marimba tone bar as it
diverges from C2. To make an accurate model of a marimba, we'd want to have
an independent model for each bar...

This model contains 5 excitation positions going linearly from the center
bottom to the center top of the bar. Obviously, a model with more excitation
position could be regenerated using `mesh2faust`.

#### Usage

```
excitation : marimbaBarModel(freq,exPos,t60,t60DecayRatio,t60DecaySlope)
```

Where:

* `excitation`: excitation signal
* `freq`: fundamental frequency of the bar
* `exPos`: excitation position (0-4)
* `t60`: T60 in seconds (recommended value: 0.1)
* `t60DecayRatio`: T60 decay ratio (recommended value: 1)
* `t60DecaySlope`: T60 decay slope (recommended value: 5)

#### Test
```
pm = library("physmodels.lib");
marimbaBarModel_test = pm.marimbaBarModel(220);
```

----

### `(pm.)marimbaResTube`

Simple marimba resonance tube.

#### Usage

```
marimbaResTube(tubeLength,excitation)
```

Where:

* `tubeLength`: the length of the tube in meters
* `excitation`: the excitation signal (audio in)

#### Test
```
pm = library("physmodels.lib");
marimbaResTube_test = pm.marimbaResTube(220);
```

----

### `(pm.)marimbaModel`

Simple marimba physical model implementing a single tone bar connected to
tube. This model is scalable and can be adapted to any size of bar/tube
(see [`marimbaBarModel`](#marimbabarmodel) to know more about the
limitations of this type of system).

#### Usage

```
excitation : marimbaModel(freq,exPos) : _
```

Where:

* `excitation`: the excitation signal
* `freq`: the frequency of the bar/tube couple
* `exPos`: excitation position (0-4)

#### Test
```
pm = library("physmodels.lib");
marimbaModel_test = pm.marimbaModel(220);
```

----

### `(pm.)marimba`

Simple marimba physical model implementing a single tone bar connected to
tube. This model is scalable and can be adapted to any size of bar/tube
(see [`marimbaBarModel`](#marimbabarmodel) to know more about the
limitations of this type of system).

This function also implement a virtual exciter to drive the model.

#### Usage

```
marimba(freq,strikePosition,strikeCutoff,strikeSharpness,gain,trigger) : _
```

Where:

* `freq`: the frequency of the bar/tube couple
* `strikePosition`: strike position (0-4)
* `strikeCutoff`: cuttoff frequency of the strike genarator (recommended: ~7000Hz)
* `strikeSharpness`: sharpness of the strike (recommended: ~0.25)
* `gain`: gain of the strike (0-1)
* `trigger` signal (0: off, 1: on)

#### Test
```
pm = library("physmodels.lib");
marimba_test = pm.marimba(220, 0.4, 1, 0.5, 0.8, button("gate"));
```

----

### `(pm.)marimba_ui_MIDI`

Simple MIDI controllable marimba physical model with built-in UI
implementing a single tone bar connected to
tube. This model is scalable and can be adapted to any size of bar/tube
(see [`marimbaBarModel`](#marimbabarmodel) to know more about the
limitations of this type of system).

#### Usage

```
marimba_ui_MIDI : _
```

#### Test
```
pm = library("physmodels.lib");
marimba_ui_MIDI_test = pm.marimba_ui_MIDI;
```

----

### `(pm.)churchBellModel`

Generic church bell modal model generated by `mesh2faust` from
`libraries/modalmodels/churchBell`.

Modeled after T. Rossing and R. Perrin, Vibrations of Bells, Applied
Acoustics 2, 1987.

Model height is 301 mm.

This model contains 7 excitation positions going linearly from the
bottom to the top of the bell. Obviously, a model with more excitation
position could be regenerated using `mesh2faust`.

#### Usage

```
excitation : churchBellModel(nModes,exPos,t60,t60DecayRatio,t60DecaySlope)
```

Where:

* `excitation`: the excitation signal
* `nModes`: number of synthesized modes (max: 50)
* `exPos`: excitation position (0-6)
* `t60`: T60 in seconds (recommended value: 0.1)
* `t60DecayRatio`: T60 decay ratio (recommended value: 1)
* `t60DecaySlope`: T60 decay slope (recommended value: 5)

#### Test
```
pm = library("physmodels.lib");
churchBellModel_test = pm.churchBellModel(110);
```

----

### `(pm.)churchBell`

Generic church bell modal model.

Modeled after T. Rossing and R. Perrin, Vibrations of Bells, Applied
Acoustics 2, 1987.

Model height is 301 mm.

This model contains 7 excitation positions going linearly from the
bottom to the top of the bell. Obviously, a model with more excitation
position could be regenerated using `mesh2faust`.

This function also implement a virtual exciter to drive the model.

#### Usage

```
churchBell(strikePosition,strikeCutoff,strikeSharpness,gain,trigger) : _
```

Where:

* `strikePosition`: strike position (0-6)
* `strikeCutoff`: cuttoff frequency of the strike genarator (recommended: ~7000Hz)
* `strikeSharpness`: sharpness of the strike (recommended: ~0.25)
* `gain`: gain of the strike (0-1)
* `trigger` signal (0: off, 1: on)

#### Test
```
pm = library("physmodels.lib");
churchBell_test = pm.churchBell(0.4, 2000, 0.5, 0.8, button("gate"));
```

----

### `(pm.)churchBell_ui`

Church bell physical model based on [`churchBell`](#pmchurchbell) with
built-in UI.

#### Usage

```
churchBell_ui : _
```

#### Test
```
pm = library("physmodels.lib");
churchBell_ui_test = pm.churchBell_ui;
```

----

### `(pm.)englishBellModel`

English church bell modal model generated by `mesh2faust` from
`libraries/modalmodels/englishBell`.

Modeled after D.Bartocha and Baron, Influence of Tin Bronze Melting and
Pouring Parameters on Its Properties and Bell' Tone, Archives of Foundry
Engineering, 2016.

Model height is 1 m.

This model contains 7 excitation positions going linearly from the
bottom to the top of the bell. Obviously, a model with more excitation
position could be regenerated using `mesh2faust`.

#### Usage

```
excitation : englishBellModel(nModes,exPos,t60,t60DecayRatio,t60DecaySlope)
```

Where:

* `excitation`: the excitation signal
* `nModes`: number of synthesized modes (max: 50)
* `exPos`: excitation position (0-6)
* `t60`: T60 in seconds (recommended value: 0.1)
* `t60DecayRatio`: T60 decay ratio (recommended value: 1)
* `t60DecaySlope`: T60 decay slope (recommended value: 5)

#### Test
```
pm = library("physmodels.lib");
englishBellModel_test = pm.englishBellModel(110);
```

----

### `(pm.)englishBell`

English church bell modal model.

Modeled after D.Bartocha and Baron, Influence of Tin Bronze Melting and
Pouring Parameters on Its Properties and Bell' Tone, Archives of Foundry
Engineering, 2016.

Model height is 1 m.

This model contains 7 excitation positions going linearly from the
bottom to the top of the bell. Obviously, a model with more excitation
position could be regenerated using `mesh2faust`.

This function also implement a virtual exciter to drive the model.

#### Usage

```
englishBell(strikePosition,strikeCutoff,strikeSharpness,gain,trigger) : _
```

Where:

* `strikePosition`: strike position (0-6)
* `strikeCutoff`: cuttoff frequency of the strike genarator (recommended: ~7000Hz)
* `strikeSharpness`: sharpness of the strike (recommended: ~0.25)
* `gain`: gain of the strike (0-1)
* `trigger` signal (0: off, 1: on)

#### Test
```
pm = library("physmodels.lib");
englishBell_test = pm.englishBell(0.4, 2000, 0.5, 0.8, button("gate"));
```

----

### `(pm.)englishBell_ui`

English church bell physical model based on [`englishBell`](#pmenglishbell) with
built-in UI.

#### Usage

```
englishBell_ui : _
```

#### Test
```
pm = library("physmodels.lib");
englishBell_ui_test = pm.englishBell_ui;
```

----

### `(pm.)frenchBellModel`

French church bell modal model generated by `mesh2faust` from
`libraries/modalmodels/frenchBell`.

Modeled after D.Bartocha and Baron, Influence of Tin Bronze Melting and
Pouring Parameters on Its Properties and Bell' Tone, Archives of Foundry
Engineering, 2016.

Model height is 1 m.

This model contains 7 excitation positions going linearly from the
bottom to the top of the bell. Obviously, a model with more excitation
position could be regenerated using `mesh2faust`.

#### Usage

```
excitation : frenchBellModel(nModes,exPos,t60,t60DecayRatio,t60DecaySlope)
```

Where:

* `excitation`: the excitation signal
* `nModes`: number of synthesized modes (max: 50)
* `exPos`: excitation position (0-6)
* `t60`: T60 in seconds (recommended value: 0.1)
* `t60DecayRatio`: T60 decay ratio (recommended value: 1)
* `t60DecaySlope`: T60 decay slope (recommended value: 5)

#### Test
```
pm = library("physmodels.lib");
frenchBellModel_test = pm.frenchBellModel(110);
```

----

### `(pm.)frenchBell`

French church bell modal model.

Modeled after D.Bartocha and Baron, Influence of Tin Bronze Melting and
Pouring Parameters on Its Properties and Bell' Tone, Archives of Foundry
Engineering, 2016.

Model height is 1 m.

This model contains 7 excitation positions going linearly from the
bottom to the top of the bell. Obviously, a model with more excitation
position could be regenerated using `mesh2faust`.

This function also implement a virtual exciter to drive the model.

#### Usage

```
```

Where:

* `strikePosition`: strike position (0-6)
* `strikeCutoff`: cuttoff frequency of the strike genarator (recommended: ~7000Hz)
* `strikeSharpness`: sharpness of the strike (recommended: ~0.25)
* `gain`: gain of the strike (0-1)
* `trigger` signal (0: off, 1: on)

#### Test
```
pm = library("physmodels.lib");
frenchBell_test = pm.frenchBell(0.4, 2000, 0.5, 0.8, button("gate"));
```

----

### `(pm.)frenchBell_ui`

French church bell physical model based on [`frenchBell`](#pmfrenchbell) with
built-in UI.

#### Usage

```
frenchBell_ui : _
```

#### Test
```
pm = library("physmodels.lib");
frenchBell_ui_test = pm.frenchBell_ui;
```

----

### `(pm.)germanBellModel`

German church bell modal model generated by `mesh2faust` from
`libraries/modalmodels/germanBell`.

Modeled after D.Bartocha and Baron, Influence of Tin Bronze Melting and
Pouring Parameters on Its Properties and Bell' Tone, Archives of Foundry
Engineering, 2016.

Model height is 1 m.

This model contains 7 excitation positions going linearly from the
bottom to the top of the bell. Obviously, a model with more excitation
position could be regenerated using `mesh2faust`.

#### Usage

```
excitation : germanBellModel(nModes,exPos,t60,t60DecayRatio,t60DecaySlope)
```

Where:

* `excitation`: the excitation signal
* `nModes`: number of synthesized modes (max: 50)
* `exPos`: excitation position (0-6)
* `t60`: T60 in seconds (recommended value: 0.1)
* `t60DecayRatio`: T60 decay ratio (recommended value: 1)
* `t60DecaySlope`: T60 decay slope (recommended value: 5)

#### Test
```
pm = library("physmodels.lib");
germanBellModel_test = pm.germanBellModel(110);
```

----

### `(pm.)germanBell`

German church bell modal model.

Modeled after D.Bartocha and Baron, Influence of Tin Bronze Melting and
Pouring Parameters on Its Properties and Bell' Tone, Archives of Foundry
Engineering, 2016.

Model height is 1 m.

This model contains 7 excitation positions going linearly from the
bottom to the top of the bell. Obviously, a model with more excitation
position could be regenerated using `mesh2faust`.

This function also implement a virtual exciter to drive the model.

#### Usage

```
germanBell(strikePosition,strikeCutoff,strikeSharpness,gain,trigger) : _
```

Where:

* `strikePosition`: strike position (0-6)
* `strikeCutoff`: cuttoff frequency of the strike genarator (recommended: ~7000Hz)
* `strikeSharpness`: sharpness of the strike (recommended: ~0.25)
* `gain`: gain of the strike (0-1)
* `trigger` signal (0: off, 1: on)

#### Test
```
pm = library("physmodels.lib");
germanBell_test = pm.germanBell(0.4, 2000, 0.5, 0.8, button("gate"));
```

----

### `(pm.)germanBell_ui`

German church bell physical model based on [`germanBell`](#pmgermanbell) with
built-in UI.

#### Usage

```
germanBell_ui : _
```

#### Test
```
pm = library("physmodels.lib");
germanBell_ui_test = pm.germanBell_ui;
```

----

### `(pm.)russianBellModel`

Russian church bell modal model generated by `mesh2faust` from
`libraries/modalmodels/russianBell`.

Modeled after D.Bartocha and Baron, Influence of Tin Bronze Melting and
Pouring Parameters on Its Properties and Bell' Tone, Archives of Foundry
Engineering, 2016.

Model height is 2 m.

This model contains 7 excitation positions going linearly from the
bottom to the top of the bell. Obviously, a model with more excitation
position could be regenerated using `mesh2faust`.

#### Usage

```
excitation : russianBellModel(nModes,exPos,t60,t60DecayRatio,t60DecaySlope)
```

Where:

* `excitation`: the excitation signal
* `nModes`: number of synthesized modes (max: 50)
* `exPos`: excitation position (0-6)
* `t60`: T60 in seconds (recommended value: 0.1)
* `t60DecayRatio`: T60 decay ratio (recommended value: 1)
* `t60DecaySlope`: T60 decay slope (recommended value: 5)

#### Test
```
pm = library("physmodels.lib");
russianBellModel_test = pm.russianBellModel(110);
```

----

### `(pm.)russianBell`

Russian church bell modal model.

Modeled after D.Bartocha and Baron, Influence of Tin Bronze Melting and
Pouring Parameters on Its Properties and Bell' Tone, Archives of Foundry
Engineering, 2016.

Model height is 2 m.

This model contains 7 excitation positions going linearly from the
bottom to the top of the bell. Obviously, a model with more excitation
position could be regenerated using `mesh2faust`.

This function also implement a virtual exciter to drive the model.

#### Usage

```
russianBell(strikePosition,strikeCutoff,strikeSharpness,gain,trigger) : _
```

Where:

* `strikePosition`: strike position (0-6)
* `strikeCutoff`: cuttoff frequency of the strike genarator (recommended: ~7000Hz)
* `strikeSharpness`: sharpness of the strike (recommended: ~0.25)
* `gain`: gain of the strike (0-1)
* `trigger` signal (0: off, 1: on)

#### Test
```
pm = library("physmodels.lib");
russianBell_test = pm.russianBell(0.4, 2000, 0.5, 0.8, button("gate"));
```

----

### `(pm.)russianBell_ui`

Russian church bell physical model based on [`russianBell`](#pmrussianbell) with
built-in UI.

#### Usage

```
russianBell_ui : _
```

#### Test
```
pm = library("physmodels.lib");
russianBell_ui_test = pm.russianBell_ui;
```

----

### `(pm.)standardBellModel`

Standard church bell modal model generated by `mesh2faust` from
`libraries/modalmodels/standardBell`.

Modeled after T. Rossing and R. Perrin, Vibrations of Bells, Applied
Acoustics 2, 1987.

Model height is 1.8 m.

This model contains 7 excitation positions going linearly from the
bottom to the top of the bell. Obviously, a model with more excitation
position could be regenerated using `mesh2faust`.

#### Usage

```
excitation : standardBellModel(nModes,exPos,t60,t60DecayRatio,t60DecaySlope)
```

Where:

* `excitation`: the excitation signal
* `nModes`: number of synthesized modes (max: 50)
* `exPos`: excitation position (0-6)
* `t60`: T60 in seconds (recommended value: 0.1)
* `t60DecayRatio`: T60 decay ratio (recommended value: 1)
* `t60DecaySlope`: T60 decay slope (recommended value: 5)

#### Test
```
pm = library("physmodels.lib");
standardBellModel_test = pm.standardBellModel(110);
```

----

### `(pm.)standardBell`

Standard church bell modal model.

Modeled after T. Rossing and R. Perrin, Vibrations of Bells, Applied
Acoustics 2, 1987.

Model height is 1.8 m.

This model contains 7 excitation positions going linearly from the
bottom to the top of the bell. Obviously, a model with more excitation
position could be regenerated using `mesh2faust`.

This function also implement a virtual exciter to drive the model.

#### Usage

```
standardBell(strikePosition,strikeCutoff,strikeSharpness,gain,trigger) : _
```

Where:

* `strikePosition`: strike position (0-6)
* `strikeCutoff`: cuttoff frequency of the strike genarator (recommended: ~7000Hz)
* `strikeSharpness`: sharpness of the strike (recommended: ~0.25)
* `gain`: gain of the strike (0-1)
* `trigger` signal (0: off, 1: on)

#### Test
```
pm = library("physmodels.lib");
standardBell_test = pm.standardBell(0.4, 2000, 0.5, 0.8, button("gate"));
```

----

### `(pm.)standardBell_ui`

Standard church bell physical model based on [`standardBell`](#pmstandardbell) with
built-in UI.

#### Usage

```
standardBell_ui : _
```

#### Test
```
pm = library("physmodels.lib");
standardBell_ui_test = pm.standardBell_ui;
```

## Vocal Synthesis

Vocal synthesizer functions (source/filter, fof, etc.).

----

### `(pm.)formantValues`

Formant data values in an environment.

The formant data used here come from the CSOUND manual
* [http://www.csounds.com/manual/html/](http://www.csounds.com/manual/html/).

#### Usage

```
ba.take(j+1,formantValues.f(i)) : _
ba.take(j+1,formantValues.g(i)) : _
ba.take(j+1,formantValues.bw(i)) : _
```

Where:

* `i`: formant number
* `j`: (voiceType*nFormants)+vowel
* `voiceType`: the voice type (0: alto, 1: bass, 2: countertenor, 3:
soprano, 4: tenor)
* `vowel`: the vowel (0: a, 1: e, 2: i, 3: o, 4: u)

#### Test
```
pm = library("physmodels.lib");
formantValues_test = pm.formantValues.f(0);
```

----

### `(pm.)voiceGender`

Calculate the gender for the provided `voiceType` value. (0: male, 1: female)

#### Usage

```
voiceGender(voiceType) : _
```

Where:

* `voiceType`: the voice type (0: alto, 1: bass, 2: countertenor, 3: soprano, 4: tenor)

#### Test
```
pm = library("physmodels.lib");
voiceGender_test = pm.voiceGender(0.5);
```

----

### `(pm.)skirtWidthMultiplier`

Calculates value to multiply bandwidth to obtain `skirtwidth`
for a Fof filter.

#### Usage

```
skirtWidthMultiplier(vowel,freq,gender) : _
```

Where:

* `vowel`: the vowel (0: a, 1: e, 2: i, 3: o, 4: u)
* `freq`: the fundamental frequency of the excitation signal
* `gender`: gender of the voice used in the fof filter (0: male, 1: female)

#### Test
```
pm = library("physmodels.lib");
skirtWidthMultiplier_test = pm.skirtWidthMultiplier(0.5);
```

----

### `(pm.)autobendFreq`

Autobends the center frequencies of formants 1 and 2 based on
the fundamental frequency of the excitation signal and leaves
all other formant frequencies unchanged. Ported from `chant-lib`.


#### Usage

```
_ : autobendFreq(n,freq,voiceType) : _
```

Where:

* `n`: formant index
* `freq`: the fundamental frequency of the excitation signal
* `voiceType`: the voice type (0: alto, 1: bass, 2: countertenor, 3: soprano, 4: tenor)
* input is the center frequency of the corresponding formant

#### Test
```
pm = library("physmodels.lib");
autobendFreq_test = pm.autobendFreq(440, 0.5);
```

#### References

* [https://ccrma.stanford.edu/~rmichon/chantLib/](https://ccrma.stanford.edu/~rmichon/chantLib/).

----

### `(pm.)vocalEffort`

Changes the gains of the formants based on the fundamental
frequency of the excitation signal. Higher formants are
reinforced for higher fundamental frequencies.
Ported from `chant-lib`.

#### Usage

```
_ : vocalEffort(freq,gender) : _
```

Where:

* `freq`: the fundamental frequency of the excitation signal
* `gender`: the gender of the voice type (0: male, 1: female)
* input is the linear amplitude of the formant

#### Test
```
pm = library("physmodels.lib");
vocalEffort_test = pm.vocalEffort(0.6);
```

#### References

* [https://ccrma.stanford.edu/~rmichon/chantLib/](https://ccrma.stanford.edu/~rmichon/chantLib/).

----

### `(pm.)fof`

Function to generate a single Formant-Wave-Function.

#### Usage

```
_ : fof(fc,bw,a,g) : _
```

Where:

* `fc`: formant center frequency,
* `bw`: formant bandwidth (Hz),
* `sw`: formant skirtwidth (Hz)
* `g`: linear scale factor (g=1 gives 0dB amplitude response at fc)
* input is an impulse signal to excite filter

#### Test
```
pm = library("physmodels.lib");
fof_test = pm.fof(0.3, 440, 880, 0.5);
```

#### References

* [https://ccrma.stanford.edu/~mjolsen/pdfs/smc2016_MOlsenFOF.pdf](https://ccrma.stanford.edu/~mjolsen/pdfs/smc2016_MOlsenFOF.pdf).

----

### `(pm.)fofSH`

FOF with sample and hold used on `bw` and a parameter
used in the filter-cycling FOF function `fofCycle`.

#### Usage

```
_ : fofSH(fc,bw,a,g) : _
```

Where: all parameters same as for [`fof`](#fof)

#### Test
```
pm = library("physmodels.lib");
fofSH_test = pm.fofSH(0.3, 440, 880, 0.5);
```

#### References

* [https://ccrma.stanford.edu/~mjolsen/pdfs/smc2016_MOlsenFOF.pdf](https://ccrma.stanford.edu/~mjolsen/pdfs/smc2016_MOlsenFOF.pdf).

----

### `(pm.)fofCycle`

FOF implementation where time-varying filter parameter noise is
mitigated by using a cycle of `n` sample and hold FOF filters.

#### Usage

```
_ : fofCycle(fc,bw,a,g,n) : _
```

Where:

* `n`: the number of FOF filters to cycle through
* all other parameters are same as for [`fof`](#fof)

#### Test
```
pm = library("physmodels.lib");
fofCycle_test = pm.fofCycle(0.3, 440, 880, 0.5, 0.2);
```

#### References

* [https://ccrma.stanford.edu/~mjolsen/pdfs/smc2016_MOlsenFOF.pdf](https://ccrma.stanford.edu/~mjolsen/pdfs/smc2016_MOlsenFOF.pdf).

----

### `(pm.)fofSmooth`

FOF implementation where time-varying filter parameter
noise is mitigated by lowpass filtering the filter
parameters `bw` and `a` with [smooth](#smooth).

#### Usage

```
_ : fofSmooth(fc,bw,sw,g,tau) : _
```

Where:

* `tau`: the desired smoothing time constant in seconds
* all other parameters are same as for [`fof`](#fof)

#### Test
```
pm = library("physmodels.lib");
fofSmooth_test = pm.fofSmooth(0.3, 440, 880, 0.5, 0.2);
```

----

### `(pm.)formantFilterFofCycle`

Formant filter based on a single FOF filter.
Formant parameters are linearly interpolated allowing to go smoothly from
one vowel to another. A cycle of `n` fof filters with sample-and-hold is
used so that the fof filter parameters can be varied in realtime.
This technique is more robust but more computationally expensive than
[`formantFilterFofSmooth`](#formantFilterFofSmooth).Voice type can be
selected but must correspond to
the frequency range of the provided source to be realistic.

#### Usage

```
_ : formantFilterFofCycle(voiceType,vowel,nFormants,i,freq) : _
```

Where:

* `voiceType`: the voice type (0: alto, 1: bass, 2: countertenor,
   3: soprano, 4: tenor)
* `vowel`: the vowel (0: a, 1: e, 2: i, 3: o, 4: u)
* `nFormants`: number of formant regions in frequency domain, typically 5
* `i`: formant number (i.e. 0 - 4) used to index formant data value arrays
* `freq`: fundamental frequency of excitation signal. Used to calculate
        rise time of envelope

#### Test
```
pm = library("physmodels.lib");
formantFilterFofCycle_test = pm.formantFilterFofCycle(0, 0, 5, 0, 200);
```

----

### `(pm.)formantFilterFofSmooth`

Formant filter based on a single FOF filter.
Formant parameters are linearly interpolated allowing to go smoothly from
one vowel to another. Fof filter parameters are lowpass filtered
to mitigate possible noise from varying them in realtime.
Voice type can be selected but must correspond to
the frequency range of the provided source to be realistic.

#### Usage

```
_ : formantFilterFofSmooth(voiceType,vowel,nFormants,i,freq) : _
```

Where:

* `voiceType`: the voice type (0: alto, 1: bass, 2: countertenor,
          3: soprano, 4: tenor)
* `vowel`: the vowel (0: a, 1: e, 2: i, 3: o, 4: u)
* `nFormants`: number of formant regions in frequency domain, typically 5
* `i`: formant number (i.e. 1 - 5) used to index formant data value arrays
* `freq`: fundamental frequency of excitation signal. Used to calculate
rise time of envelope

#### Test
```
pm = library("physmodels.lib");
formantFilterFofSmooth_test = pm.formantFilterFofSmooth(0, 0, 5, 0, 200);
```

----

### `(pm.)formantFilterBP`

Formant filter based on a single resonant bandpass filter.
Formant parameters are linearly interpolated allowing to go smoothly from
one vowel to another. Voice type can be selected but must correspond to
the frequency range of the provided source to be realistic.

#### Usage

```
_ : formantFilterBP(voiceType,vowel,nFormants,i,freq) : _
```

Where:

* `voiceType`: the voice type (0: alto, 1: bass, 2: countertenor, 3: soprano, 4: tenor)
* `vowel`: the vowel (0: a, 1: e, 2: i, 3: o, 4: u)
* `nFormants`: number of formant regions in frequency domain, typically 5
* `i`: formant index used to index formant data value arrays
* `freq`: fundamental frequency of excitation signal.

#### Test
```
pm = library("physmodels.lib");
formantFilterBP_test = pm.formantFilterBP(0, 0, 5, 0, 200);
```

----

### `(pm.)formantFilterbank`

Formant filterbank which can use different types of filterbank
functions and different excitation signals. Formant parameters are
linearly interpolated allowing to go smoothly from one vowel to another.
Voice type can be selected but must correspond to the frequency range
of the provided source to be realistic.

#### Usage

```
_ : formantFilterbank(voiceType,vowel,formantGen,freq) : _
```

Where:

* `voiceType`: the voice type (0: alto, 1: bass, 2: countertenor, 3: soprano, 4: tenor)
* `vowel`: the vowel (0: a, 1: e, 2: i, 3: o, 4: u)
* `formantGen`: the specific formant filterbank function
 (i.e. FormantFilterbankBP, FormantFilterbankFof,...)
* `freq`: fundamental frequency of excitation signal. Needed for FOF
 version to calculate rise time of envelope

#### Test
```
pm = library("physmodels.lib");
formantFilterbank_test = pm.formantFilterbank(0, 0, 5, 0);
```

----

### `(pm.)formantFilterbankFofCycle`

Formant filterbank based on a bank of fof filters.
Formant parameters are linearly interpolated allowing to go smoothly from
one vowel to another. Voice type can be selected but must correspond to
the frequency range of the provided source to be realistic.

#### Usage

```
_ : formantFilterbankFofCycle(voiceType,vowel,freq) : _
```

Where:

* `voiceType`: the voice type (0: alto, 1: bass, 2: countertenor, 3: soprano, 4: tenor)
* `vowel`: the vowel (0: a, 1: e, 2: i, 3: o, 4: u)
* `freq`: the fundamental frequency of the excitation signal. Needed to calculate the skirtwidth 
of the FOF envelopes and for the autobendFreq and vocalEffort functions

#### Test
```
pm = library("physmodels.lib");
formantFilterbankFofCycle_test = pm.formantFilterbankFofCycle(0, 0, 5));
```

----

### `(pm.)formantFilterbankFofSmooth`

Formant filterbank based on a bank of fof filters.
Formant parameters are linearly interpolated allowing to go smoothly from
one vowel to another. Voice type can be selected but must correspond to
the frequency range of the provided source to be realistic.

#### Usage

```
_ : formantFilterbankFofSmooth(voiceType,vowel,freq) : _
```

Where:

* `voiceType`: the voice type (0: alto, 1: bass, 2: countertenor, 3: soprano, 4: tenor)
* `vowel`: the vowel (0: a, 1: e, 2: i, 3: o, 4: u)
* `freq`: the fundamental frequency of the excitation signal. Needed to
calculate the skirtwidth of the FOF envelopes and for the
autobendFreq and vocalEffort functions

#### Test
```
pm = library("physmodels.lib");
formantFilterbankFofSmooth_test = pm.formantFilterbankFofSmooth(0, 0, 5);
```

----

### `(pm.)formantFilterbankBP`

Formant filterbank based on a bank of resonant bandpass filters.
Formant parameters are linearly interpolated allowing to go smoothly from
one vowel to another. Voice type can be selected but must correspond to
the frequency range of the provided source to be realistic.

#### Usage

```
_ : formantFilterbankBP(voiceType,vowel,freq) : _
```

Where:

* `voiceType`: the voice type (0: alto, 1: bass, 2: countertenor, 3: soprano, 4: tenor)
* `vowel`: the vowel (0: a, 1: e, 2: i, 3: o, 4: u)
* `freq`: the fundamental frequency of the excitation signal. Needed for the autobendFreq and vocalEffort functions.

#### Test
```
pm = library("physmodels.lib");
formantFilterbankBP_test = pm.formantFilterbankBP(0, 0, 5);
```

----

### `(pm.)SFFormantModel`

Simple formant/vocal synthesizer based on a source/filter model. The `source`
and `filterbank` must be specified by the user. `filterbank` must take the same
input parameters as [`formantFilterbank`](#formantFilterbank) (`BP`/`FofCycle`
/`FofSmooth`).
Formant parameters are linearly interpolated allowing to go smoothly from
one vowel to another. Voice type can be selected but must correspond to
the frequency range of the synthesized voice to be realistic.

#### Usage

```
SFFormantModel(voiceType,vowel,exType,freq,gain,source,filterbank,isFof) : _
```

Where:

* `voiceType`: the voice type (0: alto, 1: bass, 2: countertenor, 3: soprano, 4: tenor)
* `vowel`: the vowel (0: a, 1: e, 2: i, 3: o, 4: u
* `exType`: voice vs. fricative sound ratio (0-1 where 1 is 100% fricative)
* `freq`: the fundamental frequency of the source signal
* `gain`: linear gain multiplier to multiply the source by
* `isFof`: whether model is FOF based (0: no, 1: yes)

#### Test
```
pm = library("physmodels.lib");
SFFormantModel_test = pm.SFFormantModel(0, 0, 0.5, 0.6, 100, 2, 1, 1);
```

----

### `(pm.)SFFormantModelFofCycle`

Simple formant/vocal synthesizer based on a source/filter model. The source
is just a periodic impulse and the "filter" is a bank of FOF filters.
Formant parameters are linearly interpolated allowing to go smoothly from
one vowel to another. Voice type can be selected but must correspond to
the frequency range of the synthesized voice to be realistic. This model
does not work with noise in the source signal so exType has been removed
and model does not depend on SFFormantModel function.

#### Usage

```
SFFormantModelFofCycle(voiceType,vowel,freq,gain) : _
```

Where:

* `voiceType`: the voice type (0: alto, 1: bass, 2: countertenor, 3: soprano, 4: tenor)
* `vowel`: the vowel (0: a, 1: e, 2: i, 3: o, 4: u
* `freq`: the fundamental frequency of the source signal
* `gain`: linear gain multiplier to multiply the source by

#### Test
```
pm = library("physmodels.lib");
SFFormantModelFofCycle_test = pm.SFFormantModelFofCycle(0.5, 0.6, 0.7);
```

----

### `(pm.)SFFormantModelFofSmooth`

Simple formant/vocal synthesizer based on a source/filter model. The source
is just a periodic impulse and the "filter" is a bank of FOF filters.
Formant parameters are linearly interpolated allowing to go smoothly from
one vowel to another. Voice type can be selected but must correspond to
the frequency range of the synthesized voice to be realistic.

#### Usage

```
SFFormantModelFofSmooth(voiceType,vowel,freq,gain) : _
```

Where:

* `voiceType`: the voice type (0: alto, 1: bass, 2: countertenor, 3: soprano, 4: tenor)
* `vowel`: the vowel (0: a, 1: e, 2: i, 3: o, 4: u
* `freq`: the fundamental frequency of the source signal
* `gain`: linear gain multiplier to multiply the source by

#### Test
```
pm = library("physmodels.lib");
SFFormantModelFofSmooth_test = pm.SFFormantModelFofSmooth(0.5, 0.6, 0.7);
```

----

### `(pm.)SFFormantModelBP`

Simple formant/vocal synthesizer based on a source/filter model. The source
is just a sawtooth wave and the "filter" is a bank of resonant bandpass filters.
Formant parameters are linearly interpolated allowing to go smoothly from
one vowel to another. Voice type can be selected but must correspond to
the frequency range of the synthesized voice to be realistic.

The formant data used here come from the CSOUND manual
* [http://www.csounds.com/manual/html/](http://www.csounds.com/manual/html/).

#### Usage

```
SFFormantModelBP(voiceType,vowel,exType,freq,gain) : _
```

Where:

* `voiceType`: the voice type (0: alto, 1: bass, 2: countertenor, 3: soprano, 4: tenor)
* `vowel`: the vowel (0: a, 1: e, 2: i, 3: o, 4: u
* `exType`: voice vs. fricative sound ratio (0-1 where 1 is 100% fricative)
* `freq`: the fundamental frequency of the source signal
* `gain`: linear gain multiplier to multiply the source by

#### Test
```
pm = library("physmodels.lib");
SFFormantModelBP_test = pm.SFFormantModelBP(0.5, 0.6, 0.7);
```

----

### `(pm.)SFFormantModelFofCycle_ui`

Ready-to-use source-filter vocal synthesizer with built-in user interface.

#### Usage

```
SFFormantModelFofCycle_ui : _
```

#### Test
```
pm = library("physmodels.lib");
SFFormantModelFofCycle_ui_test = pm.SFFormantModelFofCycle_ui;
```

----

### `(pm.)SFFormantModelFofSmooth_ui`

Ready-to-use source-filter vocal synthesizer with built-in user interface.

#### Usage

```
SFFormantModelFofSmooth_ui : _
```

#### Test
```
pm = library("physmodels.lib");
SFFormantModelFofSmooth_ui_test = pm.SFFormantModelFofSmooth_ui;
```

----

### `(pm.)SFFormantModelBP_ui`

Ready-to-use source-filter vocal synthesizer with built-in user interface.

#### Usage

```
SFFormantModelBP_ui : _
```

#### Test
```
pm = library("physmodels.lib");
SFFormantModelBP_ui_test = pm.SFFormantModelBP_ui;
```

----

### `(pm.)SFFormantModelFofCycle_ui_MIDI`

Ready-to-use MIDI-controllable source-filter vocal synthesizer.

#### Usage

```
SFFormantModelFofCycle_ui_MIDI : _
```

#### Test
```
pm = library("physmodels.lib");
SFFormantModelFofCycle_ui_MIDI_test = pm.SFFormantModelFofCycle_ui_MIDI;
```

----

### `(pm.)SFFormantModelFofSmooth_ui_MIDI`

Ready-to-use MIDI-controllable source-filter vocal synthesizer.

#### Usage

```
SFFormantModelFofSmooth_ui_MIDI : _
```

#### Test
```
pm = library("physmodels.lib");
SFFormantModelFofSmooth_ui_MIDI_test = pm.SFFormantModelFofSmooth_ui_MIDI;
```

----

### `(pm.)SFFormantModelBP_ui_MIDI`

Ready-to-use MIDI-controllable source-filter vocal synthesizer.

#### Usage

```
SFFormantModelBP_ui_MIDI : _
```

#### Test
```
pm = library("physmodels.lib");
SFFormantModelBP_ui_MIDI_test = pm.SFFormantModelBP_ui_MIDI;
```

##  Misc Functions 

Various miscellaneous functions.

----

### `(pm.)allpassNL`

Bidirectional block adding nonlinearities in both directions in a chain.
Nonlinearities are created by modulating the coefficients of a passive
allpass filter by the signal it is processing.

#### Usage

```
chain(... : allpassNL(nonlinearity) : ...)
```

Where:

* `nonlinearity`: amount of nonlinearity to be added (0-1)

#### Test
```
pm = library("physmodels.lib");
allpassNL_test = 0,0,0 : pm.allpassNL(0.4);
```

----

### `(pm.)modalModel`


Implement multiple resonance modes using resonant bandpass filters.

#### Usage

```
_ : modalModel(n, freqs, t60s, gains) : _
```

Where:

* `n`: number of given modes
* `freqs` : list of filter center freqencies
* `t60s` : list of mode resonance durations (in seconds)
* `gains` : list of mode gains (0-1)

For example, to generate a model with 2 modes (440 Hz and 660 Hz, a
fifth) where the higher one decays faster and is attenuated:

```
os.impulse : modalModel(2, (440, 660),
                           (0.5, 0.25),
                           (ba.db2linear(-1), ba.db2linear(-6)) : _
```

#### Test
```
pm = library("physmodels.lib");
os = library("oscillators.lib");
modalModel_test = os.impulse : pm.modalModel(3, (440,660,880), (0.5,0.4,0.3), (0.8,0.6,0.4));
```

Further reading: [Grumiaux et. al., 2017:
Impulse-Response and CAD-Model-Based Physical Modeling in
Faust](https://raw.githubusercontent.com/grame-cncm/faust/master-dev/tools/physicalModeling/ir2dsp/lacPaper2017.pdf)


----

### `(pm.)rk_solve`

Solves the system of ordinary differential equations of any order using
the explicit Runge-Kutta methods.

#### Usage

```
rk_solve(ts,ks, ni,h, eq,iv) : si.bus(outputs(eq))
```

Where:

* `ts,ks` : the Butcher tableau (see below)
* `ni` : number of iterations at each tick, compile time constant
         ni > 1 can improve accuracy but will degrade performance
* `h`  : time step, run time constant, e.g. 1/ma.SR
* `eq` : list of derivative functions
* `iv` : list of initial values

`rk_solve()` with the "standard" 1-4 tableaux and ni = 1:
```
rk_solve_1 = rk_solve((0), (1), 1);
rk_solve_2 = rk_solve((0,1/2), (1/2, 0,1), 1);
rk_solve_3 = rk_solve((0,1/2,1), (1/2,-1,2, 1/6,2/3,1/6), 1);
rk_solve_4 = rk_solve((0,1/2,1/2,1), (1/2,0,1/2,0,0,1, 1/6,1/3,1/3,1/6), 1);
```

#### Test
```
pm = library("physmodels.lib");
ma = library("maths.lib");
rk_solve_test = pm.rk_solve((0), (1), 1, 1.0/ma.SR, eq, (1)) with { eq(t,x) = -x; };
```

#### Example test program

Suppose we have a system of differential equations:
```
dx/dt = dx_dt(t,x,y,z)
dy/dt = dy_dt(t,x,y,z)
dz/dt = dz_dt(t,x,y,z)
```
with initial conditions:
```
   x(0) = x0
   y(0) = y0
   z(0) = z0
```
and we want to solve it using this Butcher tableau:
```
 0 |
c2 | a21
c3 | a31 a32
c4 | a41 a42 a43
-------------------
   | b1  b1  b3  b4
```

```
EQ(t,x,y,z) = dx_dt(t,x,y,z),
              dy_dt(t,x,y,z),
              dz_dt(t,x,y,z);

IV = x0, y0, z0;

TS = 0, c2, c3, c4;
KS = a21,
     a31, a32,
     a41, a42, a43,
     b1,  b2,  b3,  b4;

process = rk_solve(TS,KS, 1,1/ma.SR, EQ,IV);
```
Less abstract example which can actually be compiled/tested:

```
// Lotka-Volterra equations parameterized by a,b,c,d:
LV(a,b,c,d, t,x,y) =
    a*x - b*x*y,
    c*x*y - d*y;

// Solved using the "standard" fourth-order method:
process = rk_solve_4(
    0.01,                  // time step
    LV(0.1,0.02,0.03,0.4), // LV() with random parameters
    (3,4)                  // initial values
);
```

#### References

* [https://wikipedia.org/wiki/Runge%E2%80%93Kutta_methods](https://wikipedia.org/wiki/Runge%E2%80%93Kutta_methods)
