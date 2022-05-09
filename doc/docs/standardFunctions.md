# Standard Functions

Dozens of functions are implemented in the Faust libraries and many of them are very specialized and not useful to beginners or to people who only need to use Faust for basic applications. This section offers an index organized by categories of the "standard Faust functions" (basic filters, effects, synthesizers, etc.). This index only contains functions without a user interface (UI). Faust functions with a built-in UI can be found in [`demos.lib`](../libs/demos).


## Analysis Tools

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[Amplitude Follower](../libs/analyzers/#anamp_follower) | [`an.`](../libs/analyzers)[`amp_follower`](../libs/analyzers/#anamp_follower) | Classic analog audio envelope follower
[Octave Analyzers](../libs/analyzers/#anmth_octave_analyzer) | [`an.`](../libs/analyzers)[`mth_octave_analyzer[N]`](../libs/analyzers/#anmth_octave_analyzer) | Octave analyzers

<div class="table-end"></div>


## Basic Elements

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[Beats](../libs/basics/#babeat) | [`ba.`](../libs/basics)[`beat`](../libs/basics/#babeat) | Pulses at a specific tempo
[Block](../libs/signals/#siblock) | [`si.`](../libs/signals)[`block`](../libs/signals/#siblock) | Terminate n signals
[Break Point Function](../libs/basics/#babpf) | [`ba.`](../libs/basics)[`bpf`](../libs/basics/#babpf) | Beak Point Function (BPF)
[Bus](../libs/signals/#sibus) | [`si.`](../libs/signals)[`bus`](../libs/signals/#sibus) | Bus of n signals
[Bypass (Mono)](../libs/basics/#babypass1) | [`ba.`](../libs/basics)[`bypass1`](../libs/basics/#babypass1) | Mono bypass
[Bypass (Stereo)](../libs/basics/#babypass2) | [`ba.`](../libs/basics)[`bypass2`](../libs/basics/#babypass2) | Stereo bypass
[Count Elements](../libs/basics/#bacount) | [`ba.`](../libs/basics)[`count`](../libs/basics/#bacount) | Count elements in a list
[Count Down](../libs/basics/#bacountdown) | [`ba.`](../libs/basics)[`countdown`](../libs/basics/#bacountdown) | Samples count down
[Count Up](../libs/basics/#bacountup) | [`ba.`](../libs/basics)[`countup`](../libs/basics/#bacountup) | Samples count up
[Delay (Integer)](../libs/delays/#dedelay) | [`de.`](../libs/delays)[`delay`](../libs/delays/#dedelay) | Integer delay
[Delay (Float)](../libs/delays/#defdelay) | [`de.`](../libs/delays)[`fdelay`](../libs/delays/#defdelay) | Fractional delay
[Down Sample](../libs/basics/#badownsample) | [`ba.`](../libs/basics)[`downSample`](../libs/basics/#badownsample) | Down sample a signal
[Impulsify](../libs/basics/#baimpulsify) | [`ba.`](../libs/basics)[`impulsify`](../libs/basics/#baimpulsify) | Turns a signal into an impulse
[Sample and Hold](../libs/basics/#basandh) | [`ba.`](../libs/basics)[`sAndH`](../libs/basics/#basandh) | Sample and hold
[Signal Crossing](../libs/routes/#rocross) | [`ro.`](../libs/routes)[`cross`](../libs/routes/#rocross) | Cross n signals
[Smoother (Default)](../libs/signals/#sismoo) | [`si.`](../libs/signals)[`smoo`](../libs/signals/#sismoo) | Exponential smoothing
[Smoother](../libs/signals/#sismooth) | [`si.`](../libs/signals)[`smooth`](../libs/signals/#sismooth) | Exponential smoothing with controllable pole
[Take Element](../libs/basics/#batake) | [`ba.`](../libs/basics)[`take`](../libs/basics/#batake) | Take en element from a list
[Time](../libs/basics/#batime) | [`ba.`](../libs/basics)[`time`](../libs/basics/#batime) | A simple timer

<div class="table-end"></div>


## Conversion

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[dB to Linear](../libs/basics/#badb2linear) | [`ba.`](../libs/basics)[`db2linear`](../libs/basics/#badb2linear) | Converts dB to linear values
[Linear to dB](../libs/basics/#balinear2db) | [`ba.`](../libs/basics)[`linear2db`](../libs/basics/#balinear2db) | Converts linear values to dB
[MIDI Key to Hz](../libs/basics/#bamidikey2hz) | [`ba.`](../libs/basics)[`midikey2hz`](../libs/basics/#bamidikey2hz) | Converts a MIDI key number into a frequency
[Hz to MIDI Key](../libs/basics/#bahz2midikey) | [`ba.`](../libs/basics)[`hz2midikey`](../libs/basics/#bahz2midikey) | Converts a frequency into MIDI key number
[Pole to T60](../libs/basics/#bapole2tau) | [`ba.`](../libs/basics)[`pole2tau`](../libs/basics/#bapole2tau) | Converts a pole into a time constant (t60)
[T60 to Pole](../libs/basics/#batau2pole) | [`ba.`](../libs/basics)[`tau2pole`](../libs/basics/#batau2pole) | Converts a time constant (t60) into a pole
[Samples to Seconds](../libs/basics/#basamp2sec) | [`ba.`](../libs/basics)[`samp2sec`](../libs/basics/#basamp2sec) | Converts samples to seconds
[Seconds to Samples](../libs/basics/#basec2samp) | [`ba.`](../libs/basics)[`sec2samp`](../libs/basics/#basec2samp) | Converts seconds to samples
[Semitones to Frequency ratio](../libs/basics/#semi2ratio) | [`ba.`](../libs/basics)[`semi2ratio`](../libs/basics/#semi2ratio) | Converts semitones in a frequency multiplicative ratio
[Frequency ratio to semintones](../libs/basics/#ratio2semi) | [`ba.`](../libs/basics)[`ratio2semi`](../libs/basics/#ratio2semi) | Converts a frequency multiplicative ratio in semitones
<div class="table-end"></div>


## Effects

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[Auto Wah](../libs/vaeffects/#veautowah) | [`ve.`](../libs/vaeffects)[`autowah`](../libs/vaeffects/#veautowah) | Auto-Wah effect
[Compressor](../libs/compressors/#cocompressor_mono) | [`co.`](../libs/compressors)[`compressor_mono`](../libs/compressors/#cocompressor_mono) | Dynamic range compressor
[Distortion](../libs/misceffects/#efcubicnl) | [`ef.`](../libs/misceffects)[`cubicnl`](../libs/misceffects/#efcubicnl) | Cubic nonlinearity distortion
[Crybaby](../libs/vaeffects/#vecrybaby) | [`ve.`](../libs/vaeffects)[`crybaby`](../libs/vaeffects/#vecrybaby) | Crybaby wah pedal
[Echo](../libs/misceffects/#efecho) | [`ef.`](../libs/misceffects)[`echo`](../libs/misceffects/#efecho) | Simple echo
[Flanger](../libs/phaflangers/#pfflanger_stereo) | [`pf.`](../libs/phaflangers)[`flanger_stereo`](../libs/phaflangers/#pfflanger_stereo) | Flanging effect
[Gate](../libs/misceffects/#efgate_mono) | [`ef.`](../libs/misceffects)[`gate_mono`](../libs/misceffects/#efgate_mono) | Mono signal gate
[Limiter](../libs/compressors/#colimiter_1176_R4_mono) | [`co.`](../libs/compressors)[`limiter_1176_R4_mono`](../libs/compressors/#colimiter_1176_R4_mono) | Limiter
[Phaser](../libs/phaflangers/#pfphaser2_stereo) | [`pf.`](../libs/phaflangers)[`phaser2_stereo`](../libs/phaflangers/#pfphaser2_stereo) | Phaser effect
[Reverb (FDN)](../libs/reverbs/#refdnrev0) | [`re.`](../libs/reverbs)[`fdnrev0`](../libs/reverbs/#refdnrev0) | Feedback delay network reverberator
[Reverb (Freeverb)](../libs/reverbs/#remono_freeverb) | [`re.`](../libs/reverbs)[`mono_freeverb`](../libs/reverbs/#remono_freeverb) | Most "famous" Schroeder reverberator
[Reverb (Simple)](../libs/reverbs/#rejcrev) | [`re.`](../libs/reverbs)[`jcrev`](../libs/reverbs/#rejcrev) | Simple Schroeder reverberator
[Reverb (Zita)](../libs/reverbs/#rezita_rev1_stereo) | [`re.`](../libs/reverbs)[`zita_rev1_stereo`](../libs/reverbs/#rezita_rev1_stereo) | High quality FDN reverberator
[Panner](../libs/spats/#sppanner) | [`sp.`](../libs/spats)[`panner`](../libs/spats/#sppanner) | Linear stereo panner
[Pitch Shift](../libs/misceffects/#eftranspose) | [`ef.`](../libs/misceffects)[`transpose`](../libs/misceffects/#eftranspose) | Simple pitch shifter
[Panner](../libs/spats/#spspat) | [`sp.`](../libs/spats)[`spat`](../libs/spats/#spspat) | N outputs spatializer
[Speaker Simulator](../libs/misceffects/#efspeakerbp) | [`ef.`](../libs/misceffects)[`speakerbp`](../libs/misceffects/#efspeakerbp) | Simple speaker simulator
[Stereo Width](../libs/misceffects/#efstereo_width) | [`ef.`](../libs/misceffects)[`stereo_width`](../libs/misceffects/#efstereo_width) | Stereo width effect
[Vocoder](../libs/vaeffects/#vevocoder) | [`ve.`](../libs/vaeffects)[`vocoder`](../libs/vaeffects/#vevocoder) | Simple vocoder
[Wah](../libs/vaeffects/#vewah4) | [`ve.`](../libs/vaeffects)[`wah4`](../libs/vaeffects/#vewah4) | Wah effect

<div class="table-end"></div>


## Envelope Generators

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[ADSR](../libs/envelopes/#enasr) | [`en.`](../libs/envelopes)[`adsr`](../libs/envelopes/#enadsr) | Attack/Decay/Sustain/Release envelope generator
[AR](../libs/envelopes/#enar) | [`en.`](../libs/envelopes)[`ar`](../libs/envelopes/#enar) | Attack/Release envelope generator
[ASR](../libs/envelopes/#enasr) | [`en.`](../libs/envelopes)[`asr`](../libs/envelopes/#enasr) | Attack/Sustain/Release envelope generator
[Exponential](../libs/envelopes/#ensmoothEvelope) | [`en.`](../libs/envelopes)[`smoothEnvelope`](../libs/envelopes/#ensmoothEnvelope) | Exponential envelope generator

<div class="table-end"></div>


## Filters

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[Bandpass (Butterworth)](../libs/filters/#fibandpass) | [`fi.`](../libs/filters)[`bandpass`](../libs/filters/#fibandpass) | Generic butterworth bandpass
[Bandpass (Resonant)](../libs/filters/#firesonbp) | [`fi.`](../libs/filters)[`resonbp`](../libs/filters/#firesonbp) | Virtual analog resonant bandpass
[Bandstop (Butterworth)](../libs/filters/#fibandstop) | [`fi.`](../libs/filters)[`bandstop`](../libs/filters/#fibandstop) | Generic butterworth bandstop
[Biquad](../libs/filters/#fitf2) | [`fi.`](../libs/filters)[`tf2`](../libs/filters/#fitf2) | "Standard" biquad filter
[Comb (Allpass)](../libs/filters/#fiallpass_fcomb) | [`fi.`](../libs/filters)[`allpass_fcomb`](../libs/filters/#fiallpass_fcomb) | Schroeder allpass comb filter
[Comb (Feedback)](../libs/filters/#fifb_fcomb) | [`fi.`](../libs/filters)[`fb_fcomb`](../libs/filters/#fifb_fcomb) | Feedback comb filter
[Comb (Feedforward)](../libs/filters/#fiff_fcomb) | [`fi.`](../libs/filters)[`ff_fcomb`](../libs/filters/#fiff_fcomb) | Feed-forward comb filter.
[DC Blocker](../libs/filters/#fidcblocker) | [`fi.`](../libs/filters)[`dcblocker`](../libs/filters/#fidcblocker) | Default dc blocker
[Filterbank](../libs/filters/#fifilterbank) | [`fi.`](../libs/filters)[`filterbank`](../libs/filters/#fifilterbank) | Generic filter bank
[FIR (Arbitrary Order)](../libs/filters/#fifir) | [`fi.`](../libs/filters)[`fir`](../libs/filters/#fifir) | Nth-order FIR filter
[High Shelf](../libs/filters/#fihigh_shelf) | [`fi.`](../libs/filters)[`high_shelf`](../libs/filters/#fihigh_shelf) | High shelf
[Highpass (Butterworth)](../libs/filters/#fihighpass) | [`fi.`](../libs/filters)[`highpass`](../libs/filters/#fihighpass) | Nth-order Butterworth highpass
[Highpass (Resonant)](../libs/filters/#firesonhp) | [`fi.`](../libs/filters)[`resonhp`](../libs/filters/#firesonhp) | Virtual analog resonant highpass
[IIR (Arbitrary Order)](../libs/filters/#fiiir) | [`fi.`](../libs/filters)[`iir`](../libs/filters/#fiiir) | Nth-order IIR filter
[Level Filter](../libs/filters/#filevelfilter) | [`fi.`](../libs/filters)[`levelfilter`](../libs/filters/#filevelfilter) | Dynamic level lowpass
[Low Shelf](../libs/filters/#filow_shelf) | [`fi.`](../libs/filters)[`low_shelf`](../libs/filters/#filow_shelf) | Low shelf
[Lowpass (Butterworth)](../libs/filters/#filowpass) | [`fi.`](../libs/filters)[`lowpass`](../libs/filters/#filowpass) | Nth-order Butterworth lowpass
[Lowpass (Resonant)](../libs/filters/#firesonlp) | [`fi.`](../libs/filters)[`resonlp`](../libs/filters/#firesonlp) | Virtual analog resonant lowpass
[Notch Filter](../libs/filters/#finotchw) | [`fi.`](../libs/filters)[`notchw`](../libs/filters/#finotchw) | Simple notch filter
[Peak Equalizer](../libs/filters/#fipeak_eq) | [`fi.`](../libs/filters)[`peak_eq`](../libs/filters/#fipeak_eq) | Peaking equalizer section

<div class="table-end"></div>


## Oscillators/Sound Generators

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[Impulse](../libs/oscillators/#osimpulse) | [`os.`](../libs/oscillators)[`impulse`](../libs/oscillators/#osimpulse) | Generate an impulse on start-up
[Impulse Train](../libs/oscillators/#osimptrain) | [`os.`](../libs/oscillators)[`imptrain`](../libs/oscillators/#osimptrain) | Band-limited impulse train
[Phasor](../libs/oscillators/#osphasor) | [`os.`](../libs/oscillators)[`phasor`](../libs/oscillators/#osphasor) | Simple phasor
[Pink Noise](../libs/noises/#nopink_noise) | [`no.`](../libs/noises)[`pink_noise`](../libs/noises/#nopink_noise) | Pink noise generator
[Pulse Train](../libs/oscillators/#ospulsetrain) | [`os.`](../libs/oscillators)[`pulsetrain`](../libs/oscillators/#ospulsetrain) | Band-limited pulse train
[Pulse Train (Low Frequency)](../libs/oscillators/#oslf_imptrain) | [`os.`](../libs/oscillators)[`lf_imptrain`](../libs/oscillators/#oslf_imptrain) | Low-frequency pulse train
[Sawtooth](../libs/oscillators/#ossawtooth) | [`os.`](../libs/oscillators)[`sawtooth`](../libs/oscillators/#ossawtooth) | Band-limited sawtooth wave
[Sawtooth (Low Frequency)](../libs/oscillators/#oslf_saw) | [`os.`](../libs/oscillators)[`lf_saw`](../libs/oscillators/#oslf_saw) | Low-frequency sawtooth wave
[Sine (Filter-Based)](../libs/oscillators/#ososcs) | [`os.`](../libs/oscillators)[`oscs`](../libs/oscillators/#ososcs) | Sine oscillator (filter-based)
[Sine (Table-Based)](../libs/oscillators/#ososc) | [`os.`](../libs/oscillators)[`osc`](../libs/oscillators/#ososc) | Sine oscillator (table-based)
[Square](../libs/oscillators/#ossquare) | [`os.`](../libs/oscillators)[`square`](../libs/oscillators/#ossquare) | Band-limited square wave
[Square (Low Frequency)](../libs/oscillators/#oslf_squarewave) | [`os.`](../libs/oscillators)[`lf_squarewave`](../libs/oscillators/#oslf_squarewave) | Low-frequency square wave
[Triangle](../libs/oscillators/#ostriangle) | [`os.`](../libs/oscillators)[`triangle`](../libs/oscillators/#ostriangle) | Band-limited triangle wave
[Triangle (Low Frequency)](../libs/oscillators/#oslf_triangle) | [`os.`](../libs/oscillators)[`lf_triangle`](../libs/oscillators/#oslf_triangle) | Low-frequency triangle wave
[White Noise](../libs/noises/#nonoise) | [`no.`](../libs/noises)[`noise`](../libs/noises/#nonoise) | White noise generator

<div class="table-end"></div>


## Synths

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[Additive Drum](../libs/synths/#syadditivedrum) | [`sy.`](../libs/synths)[`additiveDrum`](../libs/synths/#syadditivedrum) | Additive synthesis drum
[Bandpassed Sawtooth](../libs/synths/#sydubdub) | [`sy.`](../libs/synths)[`dubDub`](../libs/synths/#sydubdub) | Sawtooth through resonant bandpass
[Comb String](../libs/synths/#sycombstring) | [`sy.`](../libs/synths)[`combString`](../libs/synths/#sycombstring) | String model based on a comb filter
[FM](../libs/synths/#syfm) | [`sy.`](../libs/synths)[`fm`](../libs/synths/#syfm) | Frequency modulation synthesizer
[Lowpassed Sawtooth](../libs/synths/#sysawtrombone) | [`sy.`](../libs/synths)[`sawTrombone`](../libs/synths/#sysawtrombone) | "Trombone" based on a filtered sawtooth
[Popping Filter](../libs/synths/#sypopfilterperc) | [`sy.`](../libs/synths)[`popFilterPerc`](../libs/synths/#sypopfilterperc) | Popping filter percussion instrument

<div class="table-end"></div>


<!--
TODO: potentially say something about demos.lib and demo functions here. Also, not sure what to do with math.lib.
-->

<script type="text/javascript">
(function() {
    $('div.table-begin').nextUntil('div.table-end', 'table').addClass('table table-bordered');
	})();
</script>
