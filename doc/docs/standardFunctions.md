# Standard Functions

Dozens of functions are implemented in the Faust libraries and many of them are very specialized and not useful to beginners or to people who only need to use Faust for basic applications. This section offers an index organized by categories of the "standard Faust functions" (basic filters, effects, synthesizers, etc.). This index only contains functions without a user interface (UI). Faust functions with a built-in UI can be found in [`demos.lib`]libs/demos.md.md).


## Analysis Tools

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[Amplitude Follower]libs/analyzers.md#anamp_follower.md) | [`an.`]libs/analyzers.md.md)[`amp_follower`]libs/analyzers.md#anamp_follower.md) | Classic analog audio envelope follower
[Octave Analyzers]libs/analyzers.md#anmth_octave_analyzer.md) | [`an.`]libs/analyzers.md.md)[`mth_octave_analyzer[N]`]libs/analyzers.md#anmth_octave_analyzer.md) | Octave analyzers

<div class="table-end"></div>


## Basic Elements

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[Beats]libs/basics.md#babeat.md) | [`ba.`]libs/basics.md.md)[`beat`]libs/basics.md#babeat.md) | Pulses at a specific tempo
[Block]libs/signals.md#siblock.md) | [`si.`]libs/signals.md.md)[`block`]libs/signals.md#siblock.md) | Terminate n signals
[Break Point Function]libs/basics.md#babpf.md) | [`ba.`]libs/basics.md.md)[`bpf`]libs/basics.md#babpf.md) | Beak Point Function (BPF)
[Bus]libs/signals.md#sibus.md) | [`si.`]libs/signals.md.md)[`bus`]libs/signals.md#sibus.md) | Bus of n signals
[Bypass (Mono)]libs/basics.md#babypass1.md) | [`ba.`]libs/basics.md.md)[`bypass1`]libs/basics.md#babypass1.md) | Mono bypass
[Bypass (Stereo)]libs/basics.md#babypass2.md) | [`ba.`]libs/basics.md.md)[`bypass2`]libs/basics.md#babypass2.md) | Stereo bypass
[Count Elements]libs/basics.md#bacount.md) | [`ba.`]libs/basics.md.md)[`count`]libs/basics.md#bacount.md) | Count elements in a list
[Count Down]libs/basics.md#bacountdown.md) | [`ba.`]libs/basics.md.md)[`countdown`]libs/basics.md#bacountdown.md) | Samples count down
[Count Up]libs/basics.md#bacountup.md) | [`ba.`]libs/basics.md.md)[`countup`]libs/basics.md#bacountup.md) | Samples count up
[Delay (Integer)]libs/delays.md#dedelay.md) | [`de.`]libs/delays.md.md)[`delay`]libs/delays.md#dedelay.md) | Integer delay
[Delay (Float)]libs/delays.md#defdelay.md) | [`de.`]libs/delays.md.md)[`fdelay`]libs/delays.md#defdelay.md) | Fractional delay
[Down Sample]libs/basics.md#badownsample.md) | [`ba.`]libs/basics.md.md)[`downSample`]libs/basics.md#badownsample.md) | Down sample a signal
[Impulsify]libs/basics.md#baimpulsify.md) | [`ba.`]libs/basics.md.md)[`impulsify`]libs/basics.md#baimpulsify.md) | Turns a signal into an impulse
[Sample and Hold]libs/basics.md#basandh.md) | [`ba.`]libs/basics.md.md)[`sAndH`]libs/basics.md#basandh.md) | Sample and hold
[Signal Crossing]libs/routes.md#rocross.md) | [`ro.`]libs/routes.md.md)[`cross`]libs/routes.md#rocross.md) | Cross n signals
[Smoother (Default)]libs/signals.md#sismoo.md) | [`si.`]libs/signals.md.md)[`smoo`]libs/signals.md#sismoo.md) | Exponential smoothing
[Smoother]libs/signals.md#sismooth.md) | [`si.`]libs/signals.md.md)[`smooth`]libs/signals.md#sismooth.md) | Exponential smoothing with controllable pole
[Take Element]libs/basics.md#batake.md) | [`ba.`]libs/basics.md.md)[`take`]libs/basics.md#batake.md) | Take en element from a list
[Time]libs/basics.md#batime.md) | [`ba.`]libs/basics.md.md)[`time`]libs/basics.md#batime.md) | A simple timer

<div class="table-end"></div>


## Conversion

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[dB to Linear]libs/basics.md#badb2linear.md) | [`ba.`]libs/basics.md.md)[`db2linear`]libs/basics.md#badb2linear.md) | Converts dB to linear values
[Linear to dB]libs/basics.md#balinear2db.md) | [`ba.`]libs/basics.md.md)[`linear2db`]libs/basics.md#balinear2db.md) | Converts linear values to dB
[MIDI Key to Hz]libs/basics.md#bamidikey2hz.md) | [`ba.`]libs/basics.md.md)[`midikey2hz`]libs/basics.md#bamidikey2hz.md) | Converts a MIDI key number into a frequency
[Hz to MIDI Key]libs/basics.md#bahz2midikey.md) | [`ba.`]libs/basics.md.md)[`hz2midikey`]libs/basics.md#bahz2midikey.md) | Converts a frequency into MIDI key number
[Pole to T60]libs/basics.md#bapole2tau.md) | [`ba.`]libs/basics.md.md)[`pole2tau`]libs/basics.md#bapole2tau.md) | Converts a pole into a time constant (t60)
[T60 to Pole]libs/basics.md#batau2pole.md) | [`ba.`]libs/basics.md.md)[`tau2pole`]libs/basics.md#batau2pole.md) | Converts a time constant (t60) into a pole
[Samples to Seconds]libs/basics.md#basamp2sec.md) | [`ba.`]libs/basics.md.md)[`samp2sec`]libs/basics.md#basamp2sec.md) | Converts samples to seconds
[Seconds to Samples]libs/basics.md#basec2samp.md) | [`ba.`]libs/basics.md.md)[`sec2samp`]libs/basics.md#basec2samp.md) | Converts seconds to samples
[Semitones to Frequency ratio]libs/basics.md#semi2ratio.md) | [`ba.`]libs/basics.md.md)[`semi2ratio`]libs/basics.md#semi2ratio.md) | Converts semitones in a frequency multiplicative ratio
[Frequency ratio to semintones]libs/basics.md#ratio2semi.md) | [`ba.`]libs/basics.md.md)[`ratio2semi`]libs/basics.md#ratio2semi.md) | Converts a frequency multiplicative ratio in semitones
<div class="table-end"></div>


## Effects

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[Auto Wah]libs/vaeffects.md#veautowah.md) | [`ve.`]libs/vaeffects.md.md)[`autowah`]libs/vaeffects.md#veautowah.md) | Auto-Wah effect
[Compressor]libs/compressors.md#cocompressor_mono.md) | [`co.`]libs/compressors.md.md)[`compressor_mono`]libs/compressors.md#cocompressor_mono.md) | Dynamic range compressor
[Distortion]libs/misceffects.md#efcubicnl.md) | [`ef.`]libs/misceffects.md.md)[`cubicnl`]libs/misceffects.md#efcubicnl.md) | Cubic nonlinearity distortion
[Crybaby]libs/vaeffects.md#vecrybaby.md) | [`ve.`]libs/vaeffects.md.md)[`crybaby`]libs/vaeffects.md#vecrybaby.md) | Crybaby wah pedal
[Echo]libs/misceffects.md#efecho.md) | [`ef.`]libs/misceffects.md.md)[`echo`]libs/misceffects.md#efecho.md) | Simple echo
[Flanger]libs/phaflangers.md#pfflanger_stereo.md) | [`pf.`]libs/phaflangers.md.md)[`flanger_stereo`]libs/phaflangers.md#pfflanger_stereo.md) | Flanging effect
[Gate]libs/misceffects.md#efgate_mono.md) | [`ef.`]libs/misceffects.md.md)[`gate_mono`]libs/misceffects.md#efgate_mono.md) | Mono signal gate
[Limiter]libs/compressors.md#colimiter_1176_R4_mono.md) | [`co.`]libs/compressors.md.md)[`limiter_1176_R4_mono`]libs/compressors.md#colimiter_1176_R4_mono.md) | Limiter
[Phaser]libs/phaflangers.md#pfphaser2_stereo.md) | [`pf.`]libs/phaflangers.md.md)[`phaser2_stereo`]libs/phaflangers.md#pfphaser2_stereo.md) | Phaser effect
[Reverb (FDN)]libs/reverbs.md#refdnrev0.md) | [`re.`]libs/reverbs.md.md)[`fdnrev0`]libs/reverbs.md#refdnrev0.md) | Feedback delay network reverberator
[Reverb (Freeverb)]libs/reverbs.md#remono_freeverb.md) | [`re.`]libs/reverbs.md.md)[`mono_freeverb`]libs/reverbs.md#remono_freeverb.md) | Most "famous" Schroeder reverberator
[Reverb (Simple)]libs/reverbs.md#rejcrev.md) | [`re.`]libs/reverbs.md.md)[`jcrev`]libs/reverbs.md#rejcrev.md) | Simple Schroeder reverberator
[Reverb (Zita)]libs/reverbs.md#rezita_rev1_stereo.md) | [`re.`]libs/reverbs.md.md)[`zita_rev1_stereo`]libs/reverbs.md#rezita_rev1_stereo.md) | High quality FDN reverberator
[Panner]libs/spats.md#sppanner.md) | [`sp.`]libs/spats.md.md)[`panner`]libs/spats.md#sppanner.md) | Linear stereo panner
[Pitch Shift]libs/misceffects.md#eftranspose.md) | [`ef.`]libs/misceffects.md.md)[`transpose`]libs/misceffects.md#eftranspose.md) | Simple pitch shifter
[Panner]libs/spats.md#spspat.md) | [`sp.`]libs/spats.md.md)[`spat`]libs/spats.md#spspat.md) | N outputs spatializer
[Speaker Simulator]libs/misceffects.md#efspeakerbp.md) | [`ef.`]libs/misceffects.md.md)[`speakerbp`]libs/misceffects.md#efspeakerbp.md) | Simple speaker simulator
[Stereo Width]libs/misceffects.md#efstereo_width.md) | [`ef.`]libs/misceffects.md.md)[`stereo_width`]libs/misceffects.md#efstereo_width.md) | Stereo width effect
[Vocoder]libs/vaeffects.md#vevocoder.md) | [`ve.`]libs/vaeffects.md.md)[`vocoder`]libs/vaeffects.md#vevocoder.md) | Simple vocoder
[Wah]libs/vaeffects.md#vewah4.md) | [`ve.`]libs/vaeffects.md.md)[`wah4`]libs/vaeffects.md#vewah4.md) | Wah effect

<div class="table-end"></div>


## Envelope Generators

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[ADSR]libs/envelopes.md#enasr.md) | [`en.`]libs/envelopes.md.md)[`adsr`]libs/envelopes.md#enadsr.md) | Attack/Decay/Sustain/Release envelope generator
[AR]libs/envelopes.md#enar.md) | [`en.`]libs/envelopes.md.md)[`ar`]libs/envelopes.md#enar.md) | Attack/Release envelope generator
[ASR]libs/envelopes.md#enasr.md) | [`en.`]libs/envelopes.md.md)[`asr`]libs/envelopes.md#enasr.md) | Attack/Sustain/Release envelope generator
[Exponential]libs/envelopes.md#ensmoothEvelope.md) | [`en.`]libs/envelopes.md.md)[`smoothEnvelope`]libs/envelopes.md#ensmoothEnvelope.md) | Exponential envelope generator

<div class="table-end"></div>


## Filters

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[Bandpass (Butterworth)]libs/filters.md#fibandpass.md) | [`fi.`]libs/filters.md.md)[`bandpass`]libs/filters.md#fibandpass.md) | Generic butterworth bandpass
[Bandpass (Resonant)]libs/filters.md#firesonbp.md) | [`fi.`]libs/filters.md.md)[`resonbp`]libs/filters.md#firesonbp.md) | Virtual analog resonant bandpass
[Bandstop (Butterworth)]libs/filters.md#fibandstop.md) | [`fi.`]libs/filters.md.md)[`bandstop`]libs/filters.md#fibandstop.md) | Generic butterworth bandstop
[Biquad]libs/filters.md#fitf2.md) | [`fi.`]libs/filters.md.md)[`tf2`]libs/filters.md#fitf2.md) | "Standard" biquad filter
[Comb (Allpass)]libs/filters.md#fiallpass_fcomb.md) | [`fi.`]libs/filters.md.md)[`allpass_fcomb`]libs/filters.md#fiallpass_fcomb.md) | Schroeder allpass comb filter
[Comb (Feedback)]libs/filters.md#fifb_fcomb.md) | [`fi.`]libs/filters.md.md)[`fb_fcomb`]libs/filters.md#fifb_fcomb.md) | Feedback comb filter
[Comb (Feedforward)]libs/filters.md#fiff_fcomb.md) | [`fi.`]libs/filters.md.md)[`ff_fcomb`]libs/filters.md#fiff_fcomb.md) | Feed-forward comb filter.
[DC Blocker]libs/filters.md#fidcblocker.md) | [`fi.`]libs/filters.md.md)[`dcblocker`]libs/filters.md#fidcblocker.md) | Default dc blocker
[Filterbank]libs/filters.md#fifilterbank.md) | [`fi.`]libs/filters.md.md)[`filterbank`]libs/filters.md#fifilterbank.md) | Generic filter bank
[FIR (Arbitrary Order)]libs/filters.md#fifir.md) | [`fi.`]libs/filters.md.md)[`fir`]libs/filters.md#fifir.md) | Nth-order FIR filter
[High Shelf]libs/filters.md#fihigh_shelf.md) | [`fi.`]libs/filters.md.md)[`high_shelf`]libs/filters.md#fihigh_shelf.md) | High shelf
[Highpass (Butterworth)]libs/filters.md#fihighpass.md) | [`fi.`]libs/filters.md.md)[`highpass`]libs/filters.md#fihighpass.md) | Nth-order Butterworth highpass
[Highpass (Resonant)]libs/filters.md#firesonhp.md) | [`fi.`]libs/filters.md.md)[`resonhp`]libs/filters.md#firesonhp.md) | Virtual analog resonant highpass
[IIR (Arbitrary Order)]libs/filters.md#fiiir.md) | [`fi.`]libs/filters.md.md)[`iir`]libs/filters.md#fiiir.md) | Nth-order IIR filter
[Level Filter]libs/filters.md#filevelfilter.md) | [`fi.`]libs/filters.md.md)[`levelfilter`]libs/filters.md#filevelfilter.md) | Dynamic level lowpass
[Low Shelf]libs/filters.md#filow_shelf.md) | [`fi.`]libs/filters.md.md)[`low_shelf`]libs/filters.md#filow_shelf.md) | Low shelf
[Lowpass (Butterworth)]libs/filters.md#filowpass.md) | [`fi.`]libs/filters.md.md)[`lowpass`]libs/filters.md#filowpass.md) | Nth-order Butterworth lowpass
[Lowpass (Resonant)]libs/filters.md#firesonlp.md) | [`fi.`]libs/filters.md.md)[`resonlp`]libs/filters.md#firesonlp.md) | Virtual analog resonant lowpass
[Notch Filter]libs/filters.md#finotchw.md) | [`fi.`]libs/filters.md.md)[`notchw`]libs/filters.md#finotchw.md) | Simple notch filter
[Peak Equalizer]libs/filters.md#fipeak_eq.md) | [`fi.`]libs/filters.md.md)[`peak_eq`]libs/filters.md#fipeak_eq.md) | Peaking equalizer section

<div class="table-end"></div>


## Oscillators/Sound Generators

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[Impulse]libs/oscillators.md#osimpulse.md) | [`os.`]libs/oscillators.md.md)[`impulse`]libs/oscillators.md#osimpulse.md) | Generate an impulse on start-up
[Impulse Train]libs/oscillators.md#osimptrain.md) | [`os.`]libs/oscillators.md.md)[`imptrain`]libs/oscillators.md#osimptrain.md) | Band-limited impulse train
[Phasor]libs/oscillators.md#osphasor.md) | [`os.`]libs/oscillators.md.md)[`phasor`]libs/oscillators.md#osphasor.md) | Simple phasor
[Pink Noise]libs/noises.md#nopink_noise.md) | [`no.`]libs/noises.md.md)[`pink_noise`]libs/noises.md#nopink_noise.md) | Pink noise generator
[Pulse Train]libs/oscillators.md#ospulsetrain.md) | [`os.`]libs/oscillators.md.md)[`pulsetrain`]libs/oscillators.md#ospulsetrain.md) | Band-limited pulse train
[Pulse Train (Low Frequency)]libs/oscillators.md#oslf_imptrain.md) | [`os.`]libs/oscillators.md.md)[`lf_imptrain`]libs/oscillators.md#oslf_imptrain.md) | Low-frequency pulse train
[Sawtooth]libs/oscillators.md#ossawtooth.md) | [`os.`]libs/oscillators.md.md)[`sawtooth`]libs/oscillators.md#ossawtooth.md) | Band-limited sawtooth wave
[Sawtooth (Low Frequency)]libs/oscillators.md#oslf_saw.md) | [`os.`]libs/oscillators.md.md)[`lf_saw`]libs/oscillators.md#oslf_saw.md) | Low-frequency sawtooth wave
[Sine (Filter-Based)]libs/oscillators.md#ososcs.md) | [`os.`]libs/oscillators.md.md)[`oscs`]libs/oscillators.md#ososcs.md) | Sine oscillator (filter-based)
[Sine (Table-Based)]libs/oscillators.md#ososc.md) | [`os.`]libs/oscillators.md.md)[`osc`]libs/oscillators.md#ososc.md) | Sine oscillator (table-based)
[Square]libs/oscillators.md#ossquare.md) | [`os.`]libs/oscillators.md.md)[`square`]libs/oscillators.md#ossquare.md) | Band-limited square wave
[Square (Low Frequency)]libs/oscillators.md#oslf_squarewave.md) | [`os.`]libs/oscillators.md.md)[`lf_squarewave`]libs/oscillators.md#oslf_squarewave.md) | Low-frequency square wave
[Triangle]libs/oscillators.md#ostriangle.md) | [`os.`]libs/oscillators.md.md)[`triangle`]libs/oscillators.md#ostriangle.md) | Band-limited triangle wave
[Triangle (Low Frequency)]libs/oscillators.md#oslf_triangle.md) | [`os.`]libs/oscillators.md.md)[`lf_triangle`]libs/oscillators.md#oslf_triangle.md) | Low-frequency triangle wave
[White Noise]libs/noises.md#nonoise.md) | [`no.`]libs/noises.md.md)[`noise`]libs/noises.md#nonoise.md) | White noise generator

<div class="table-end"></div>


## Synths

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[Additive Drum]libs/synths.md#syadditivedrum.md) | [`sy.`]libs/synths.md.md)[`additiveDrum`]libs/synths.md#syadditivedrum.md) | Additive synthesis drum
[Bandpassed Sawtooth]libs/synths.md#sydubdub.md) | [`sy.`]libs/synths.md.md)[`dubDub`]libs/synths.md#sydubdub.md) | Sawtooth through resonant bandpass
[Comb String]libs/synths.md#sycombstring.md) | [`sy.`]libs/synths.md.md)[`combString`]libs/synths.md#sycombstring.md) | String model based on a comb filter
[FM]libs/synths.md#syfm.md) | [`sy.`]libs/synths.md.md)[`fm`]libs/synths.md#syfm.md) | Frequency modulation synthesizer
[Lowpassed Sawtooth]libs/synths.md#sysawtrombone.md) | [`sy.`]libs/synths.md.md)[`sawTrombone`]libs/synths.md#sysawtrombone.md) | "Trombone" based on a filtered sawtooth
[Popping Filter]libs/synths.md#sypopfilterperc.md) | [`sy.`]libs/synths.md.md)[`popFilterPerc`]libs/synths.md#sypopfilterperc.md) | Popping filter percussion instrument

<div class="table-end"></div>


<!--
TODO: potentially say something about demos.lib and demo functions here. Also, not sure what to do with math.lib.
-->

<script type="text/javascript">
(function() {
    $('div.table-begin').nextUntil('div.table-end', 'table').addClass('table table-bordered');
	})();
</script>
