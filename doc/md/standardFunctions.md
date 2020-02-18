# Standard Functions

Dozens of functions are implemented in the Faust libraries and many of them are very specialized and not useful to beginners or to people who only need to use Faust for basic applications. This section offers an index organized by categories of the "standard Faust functions" (basic filters, effects, synthesizers, etc.). This index only contains functions without a user interface (UI). Faust functions with a built-in UI can be found in [`demos.lib`](#demoslib).


## Analysis Tools

<div class="table-begin"></div>

| Function Type                              | Function Name                                                           | Description                            |
| ------------------------------------------ | ----------------------------------------------------------------------- | -------------------------------------- |
| [Amplitude Follower](#anamp_follower)      | [`an.`](#analysislib)[`amp_follower`](#anamp_follower)                  | Classic analog audio envelope follower |
| [Octave Analyzers](#anmth_octave_analyzer) | [`an.`](#analysislib)[`mth_octave_analyzer[N]`](#anmth_octave_analyzer) | Octave analyzers                       |

<div class="table-end"></div>


## Basic Elements

<div class="table-begin"></div>

| Function Type                  | Function Name                                    | Description                                  |
| ------------------------------ | ------------------------------------------------ | -------------------------------------------- |
| [Beats](#babeat)               | [`ba.`](#basicslib)[`beat`](#babeat)             | Pulses at a specific tempo                   |
| [Block](#siblock)              | [`si.`](#signalslib)[`block`](#siblock)          | Terminate n signals                          |
| [Break Point Function](#babpf) | [`ba.`](#basicslib)[`bpf`](#babpf)               | Beak Point Function (BPF)                    |
| [Bus](#sibus)                  | [`si.`](#signalslib)[`bus`](#sibus)              | Bus of n signals                             |
| [Bypass (Mono)](#babypass1)    | [`ba.`](#basicslib)[`bypass1`](#babypass1)       | Mono bypass                                  |
| [Bypass (Stereo)](#babypass2)  | [`ba.`](#basicslib)[`bypass2`](#babypass2)       | Stereo bypass                                |
| [Count Elements](#bacount)     | [`ba.`](#basicslib)[`count`](#bacount)           | Count elements in a list                     |
| [Count Down](#bacountdown)     | [`ba.`](#basicslib)[`countdown`](#bacountdown)   | Samples count down                           |
| [Count Up](#bacountup)         | [`ba.`](#basicslib)[`countup`](#bacountup)       | Samples count up                             |
| [Delay (Integer)](#dedelay)    | [`de.`](#delayslib)[`delay`](#dedelay)           | Integer delay                                |
| [Delay (Float)](#defdelay)     | [`de.`](#delayslib)[`fdelay`](#defdelay)         | Fractional delay                             |
| [Down Sample](#badownsample)   | [`ba.`](#basicslib)[`downSample`](#badownsample) | Down sample a signal                         |
| [Impulsify](#baimpulsify)      | [`ba.`](#basicslib)[`impulsify`](#baimpulsify)   | Turns a signal into an impulse               |
| [Sample and Hold](#basandh)    | [`ba.`](#basicslib)[`sAndH`](#basandh)           | Sample and hold                              |
| [Signal Crossing](#rocross)    | [`ro.`](#routeslib)[`cross`](#rocross)           | Cross n signals                              |
| [Smoother (Default)](#sismoo)  | [`si.`](#signalslib)[`smoo`](#sismoo)            | Exponential smoothing                        |
| [Smoother](#sismooth)          | [`si.`](#signalslib)[`smooth`](#sismooth)        | Exponential smoothing with controllable pole |
| [Take Element](#batake)        | [`ba.`](#basicslib)[`take`](#batake)             | Take en element from a list                  |
| [Time](#batime)                | [`ba.`](#basicslib)[`time`](#batime)             | A simple timer                               |

<div class="table-end"></div>


## Conversion

<div class="table-begin"></div>

| Function Type                     | Function Name                                    | Description                                 |
| --------------------------------- | ------------------------------------------------ | ------------------------------------------- |
| [dB to Linear](#badb2linear)      | [`ba.`](#basicslib)[`db2linear`](#badb2linear)   | Converts dB to linear values                |
| [Linear to dB](#balinear2db)      | [`ba.`](#basicslib)[`linear2db`](#balinear2db)   | Converts linear values to dB                |
| [MIDI Key to Hz](#bamidikey2hz)   | [`ba.`](#basicslib)[`midikey2hz`](#bamidikey2hz) | Converts a MIDI key number into a frequency |
| [Hz to MIDI Key](#bahz2midikey)   | [`ba.`](#basicslib)[`hz2midikey`](#bahz2midikey) | Converts a frequency into MIDI key number   |
| [Pole to T60](#bapole2tau)        | [`ba.`](#basicslib)[`pole2tau`](#bapole2tau)     | Converts a pole into a time constant (t60)  |
| [Samples to Seconds](#basamp2sec) | [`ba.`](#basicslib)[`samp2sec`](#basamp2sec)     | Converts samples to seconds                 |
| [Seconds to Samples](#basec2samp) | [`ba.`](#basicslib)[`sec2samp`](#basec2samp)     | Converts seconds to samples                 |
| [T60 to Pole](#batau2pole)        | [`ba.`](#basicslib)[`tau2pole`](#batau2pole)     | Converts a time constant (t60) into a pole  |

<div class="table-end"></div>


## Effects

<div class="table-begin"></div>

| Function Type                         | Function Name                                                             | Description                          |
| ------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------ |
| [Auto Wah](#veautowah)                | [`ve.`](#vaeffectslib)[`autowah`](#veautowah)                             | Auto-Wah effect                      |
| [Compressor](#cocompressor_mono)      | [`co.`](#compressorslib)[`compressor_mono`](#cocompressor_mono)           | Dynamic range compressor             |
| [Distortion](#efcubicnl)              | [`ef.`](#misceffectslib)[`cubicnl`](#efcubicnl)                           | Cubic nonlinearity distortion        |
| [Crybaby](#vecrybaby)                 | [`ve.`](#vaeffectslib)[`crybaby`](#vecrybaby)                             | Crybaby wah pedal                    |
| [Echo](#efecho)                       | [`ef.`](#misceffectslib)[`echo`](#efecho)                                 | Simple echo                          |
| [Flanger](#pfflanger_stereo)          | [`pf.`](#phaflangerslib)[`flanger_stereo`](#pfflanger_stereo)             | Flanging effect                      |
| [Gate](#efgate_mono)                  | [`ef.`](#misceffectslib)[`gate_mono`](#efgate_mono)                       | Mono signal gate                     |
| [Limiter](#colimiter_1176_R4_mono)    | [`co.`](#compressorslib)[`limiter_1176_R4_mono`](#colimiter_1176_R4_mono) | Limiter                              |
| [Phaser](#pfphaser2_stereo)           | [`pf.`](#phaflangerslib)[`phaser2_stereo`](#pfphaser2_stereo)             | Phaser effect                        |
| [Reverb (FDN)](#refdnrev0)            | [`re.`](#reverbslib)[`fdnrev0`](#refdnrev0)                               | Feedback delay network reverberator  |
| [Reverb (Freeverb)](#remono_freeverb) | [`re.`](#reverbslib)[`mono_freeverb`](#remono_freeverb)                   | Most "famous" Schroeder reverberator |
| [Reverb (Simple)](#rejcrev)           | [`re.`](#reverbslib)[`jcrev`](#rejcrev)                                   | Simple Schroeder reverberator        |
| [Reverb (Zita)](#rezita_rev1_stereo)  | [`re.`](#reverbslib)[`zita_rev1_stereo`](#rezita_rev1_stereo)             | High quality FDN reverberator        |
| [Panner](#sppanner)                   | [`sp.`](#spatslib)[`panner`](#sppanner)                                   | Linear stereo panner                 |
| [Pitch Shift](#eftranspose)           | [`ef.`](#misceffectslib)[`transpose`](#eftranspose)                       | Simple pitch shifter                 |
| [Panner](#spspat)                     | [`sp.`](#spatslib)[`spat`](#spspat)                                       | N outputs spatializer                |
| [Speaker Simulator](#efspeakerbp)     | [`ef.`](#misceffectslib)[`speakerbp`](#efspeakerbp)                       | Simple speaker simulator             |
| [Stereo Width](#efstereo_width)       | [`ef.`](#misceffectslib)[`stereo_width`](#efstereo_width)                 | Stereo width effect                  |
| [Vocoder](#vevocoder)                 | [`ve.`](#vaeffectslib)[`vocoder`](#vevocoder)                             | Simple vocoder                       |
| [Wah](#vewah4)                        | [`ve.`](#vaeffectslib)[`wah4`](#vewah4)                                   | Wah effect                           |

<div class="table-end"></div>


## Envelope Generators

<div class="table-begin"></div>

| Function Type                   | Function Name                                               | Description                                     |
| ------------------------------- | ----------------------------------------------------------- | ----------------------------------------------- |
| [ADSR](#enasr)                  | [`en.`](#envelopeslib)[`adsr`](#enadsr)                     | Attack/Decay/Sustain/Release envelope generator |
| [AR](#enar)                     | [`en.`](#envelopeslib)[`ar`](#enar)                         | Attack/Release envelope generator               |
| [ASR](#enasr)                   | [`en.`](#envelopeslib)[`asr`](#enasr)                       | Attack/Sustain/Release envelope generator       |
| [Exponential](#ensmoothEvelope) | [`en.`](#envelopeslib)[`smoothEnvelope`](#ensmoothEnvelope) | Exponential envelope generator                  |

<div class="table-end"></div>


## Filters

<div class="table-begin"></div>

| Function Type                         | Function Name                                           | Description                      |
| ------------------------------------- | ------------------------------------------------------- | -------------------------------- |
| [Bandpass (Butterworth)](#fibandpass) | [`fi.`](#filterslib)[`bandpass`](#fibandpass)           | Generic butterworth bandpass     |
| [Bandpass (Resonant)](#firesonbp)     | [`fi.`](#filterslib)[`resonbp`](#firesonbp)             | Virtual analog resonant bandpass |
| [Bandstop (Butterworth)](#fibandstop) | [`fi.`](#filterslib)[`bandstop`](#fibandstop)           | Generic butterworth bandstop     |
| [Biquad](#fitf2)                      | [`fi.`](#filterslib)[`tf2`](#fitf2)                     | "Standard" biquad filter         |
| [Comb (Allpass)](#fiallpass_fcomb)    | [`fi.`](#filterslib)[`allpass_fcomb`](#fiallpass_fcomb) | Schroeder allpass comb filter    |
| [Comb (Feedback)](#fifb_fcomb)        | [`fi.`](#filterslib)[`fb_fcomb`](#fifb_fcomb)           | Feedback comb filter             |
| [Comb (Feedforward)](#fiff_fcomb)     | [`fi.`](#filterslib)[`ff_fcomb`](#fiff_fcomb)           | Feed-forward comb filter.        |
| [DC Blocker](#fidcblocker)            | [`fi.`](#filterslib)[`dcblocker`](#fidcblocker)         | Default dc blocker               |
| [Filterbank](#fifilterbank)           | [`fi.`](#filterslib)[`filterbank`](#fifilterbank)       | Generic filter bank              |
| [FIR (Arbitrary Order)](#fifir)       | [`fi.`](#filterslib)[`fir`](#fifir)                     | Nth-order FIR filter             |
| [High Shelf](#fihigh_shelf)           | [`fi.`](#filterslib)[`high_shelf`](#fihigh_shelf)       | High shelf                       |
| [Highpass (Butterworth)](#fihighpass) | [`fi.`](#filterslib)[`highpass`](#fihighpass)           | Nth-order Butterworth highpass   |
| [Highpass (Resonant)](#firesonhp)     | [`fi.`](#filterslib)[`resonhp`](#firesonhp)             | Virtual analog resonant highpass |
| [IIR (Arbitrary Order)](#fiiir)       | [`fi.`](#filterslib)[`iir`](#fiiir)                     | Nth-order IIR filter             |
| [Level Filter](#filevelfilter)        | [`fi.`](#filterslib)[`levelfilter`](#filevelfilter)     | Dynamic level lowpass            |
| [Low Shelf](#filow_shelf)             | [`fi.`](#filterslib)[`low_shelf`](#filow_shelf)         | Low shelf                        |
| [Lowpass (Butterworth)](#filowpass)   | [`fi.`](#filterslib)[`lowpass`](#filowpass)             | Nth-order Butterworth lowpass    |
| [Lowpass (Resonant)](#firesonlp)      | [`fi.`](#filterslib)[`resonlp`](#firesonlp)             | Virtual analog resonant lowpass  |
| [Notch Filter](#finotchw)             | [`fi.`](#filterslib)[`notchw`](#finotchw)               | Simple notch filter              |
| [Peak Equalizer](#fipeak_eq)          | [`fi.`](#filterslib)[`peak_eq`](#fipeak_eq)             | Peaking equalizer section        |

<div class="table-end"></div>


## Oscillators/Sound Generators

<div class="table-begin"></div>

| Function Type                                 | Function Name                                               | Description                     |
| --------------------------------------------- | ----------------------------------------------------------- | ------------------------------- |
| [Impulse](#osimpulse)                         | [`os.`](#oscillatorslib)[`impulse`](#osimpulse)             | Generate an impulse on start-up |
| [Impulse Train](#osimptrain)                  | [`os.`](#oscillatorslib)[`imptrain`](#osimptrain)           | Band-limited impulse train      |
| [Phasor](#osphasor)                           | [`os.`](#oscillatorslib)[`phasor`](#osphasor)               | Simple phasor                   |
| [Pink Noise](#nopink_noise)                   | [`no.`](#noiseslib)[`pink_noise`](#nopink_noise)            | Pink noise generator            |
| [Pulse Train](#ospulsetrain)                  | [`os.`](#oscillatorslib)[`pulsetrain`](#ospulsetrain)       | Band-limited pulse train        |
| [Pulse Train (Low Frequency)](#oslf_imptrain) | [`os.`](#oscillatorslib)[`lf_imptrain`](#oslf_imptrain)     | Low-frequency pulse train       |
| [Sawtooth](#ossawtooth)                       | [`os.`](#oscillatorslib)[`sawtooth`](#ossawtooth)           | Band-limited sawtooth wave      |
| [Sawtooth (Low Frequency)](#oslf_saw)         | [`os.`](#oscillatorslib)[`lf_saw`](#oslf_saw)               | Low-frequency sawtooth wave     |
| [Sine (Filter-Based)](#ososcs)                | [`os.`](#oscillatorslib)[`oscs`](#ososcs)                   | Sine oscillator (filter-based)  |
| [Sine (Table-Based)](#ososc)                  | [`os.`](#oscillatorslib)[`osc`](#ososc)                     | Sine oscillator (table-based)   |
| [Square](#ossquare)                           | [`os.`](#oscillatorslib)[`square`](#ossquare)               | Band-limited square wave        |
| [Square (Low Frequency)](#oslf_squarewave)    | [`os.`](#oscillatorslib)[`lf_squarewave`](#oslf_squarewave) | Low-frequency square wave       |
| [Triangle](#ostriangle)                       | [`os.`](#oscillatorslib)[`triangle`](#ostriangle)           | Band-limited triangle wave      |
| [Triangle (Low Frequency)](#oslf_triangle)    | [`os.`](#oscillatorslib)[`lf_triangle`](#oslf_triangle)     | Low-frequency triangle wave     |
| [White Noise](#nonoise)                       | [`no.`](#noiseslib)[`noise`](#nonoise)                      | White noise generator           |

<div class="table-end"></div>


## Synths

<div class="table-begin"></div>

| Function Type                        | Function Name                                          | Description                             |
| ------------------------------------ | ------------------------------------------------------ | --------------------------------------- |
| [Additive Drum](#syadditivedrum)     | [`sy.`](#synthslib)[`additiveDrum`](#syadditivedrum)   | Additive synthesis drum                 |
| [Bandpassed Sawtooth](#sydubdub)     | [`sy.`](#synthslib)[`dubDub`](#sydubdub)               | Sawtooth through resonant bandpass      |
| [Comb String](#sycombstring)         | [`sy.`](#synthslib)[`combString`](#sycombstring)       | String model based on a comb filter     |
| [FM](#syfm)                          | [`sy.`](#synthslib)[`fm`](#syfm)                       | Frequency modulation synthesizer        |
| [Lowpassed Sawtooth](#sysawtrombone) | [`sy.`](#synthslib)[`sawTrombone`](#sysawtrombone)     | "Trombone" based on a filtered sawtooth |
| [Popping Filter](#sypopfilterperc)   | [`sy.`](#synthslib)[`popFilterPerc`](#sypopfilterperc) | Popping filter percussion instrument    |

<div class="table-end"></div>


<!--
TODO: potentially say something about demos.lib and demo functions here. Also, not sure what to do with math.lib.
-->

<script type="text/javascript">
(function() {
    $('div.table-begin').nextUntil('div.table-end', 'table').addClass('table table-bordered');
	})();
</script>
