# Standard Functions

Dozens of functions are implemented in the Faust libraries and many of them are very specialized and not useful to beginners or to people who only need to use Faust for basic applications. This section offers an index organized by categories of the "standard Faust functions" (basic filters, effects, synthesizers, etc.). This index only contains functions without a user interface (UI). Faust functions with a built-in UI can be found in [`demos.lib`](libs/demos.md).


## Analysis Tools

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[Amplitude Follower](libs/analyzers.md#anamp_follower) | [`an.`](libs/analyzers.md)[`amp_follower`](libs/analyzers.md#anamp_follower) | Classic analog audio envelope follower
[Octave Analyzers](libs/analyzers.md#anmth_octave_analyzern) | [`an.`](libs/analyzers.md)[`mth_octave_analyzer[N]`](libs/analyzers.md#anmth_octave_analyzern) | Octave analyzers

<div class="table-end"></div>


## Basic Elements

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[Beats](libs/basics.md#babeat) | [`ba.`](libs/basics.md)[`beat`](libs/basics.md#babeat) | Pulses at a specific tempo
[Block](libs/signals.md#siblock) | [`si.`](libs/signals.md)[`block`](libs/signals.md#siblock) | Terminate n signals
[Break Point Function](libs/basics.md#babpf) | [`ba.`](libs/basics.md)[`bpf`](libs/basics.md#babpf) | Beak Point Function (BPF)
[Bus](libs/signals.md#sibus) | [`si.`](libs/signals.md)[`bus`](libs/signals.md#sibus) | Bus of n signals
[Bypass (Mono)](libs/basics.md#babypass1) | [`ba.`](libs/basics.md)[`bypass1`](libs/basics.md#babypass1) | Mono bypass
[Bypass (Stereo)](libs/basics.md#babypass2) | [`ba.`](libs/basics.md)[`bypass2`](libs/basics.md#babypass2) | Stereo bypass
[bypass1to2](libs/basics.md#babypass1to2) | [`ba.`](libs/basics.md)[`bypass1to2`](libs/basics.md#babypass1to2) | Bypass switch for effect `e` having mono input signal and stereo output
[cbus](libs/signals.md#sicbus) | [`si.`](libs/signals.md)[`cbus`](libs/signals.md#sicbus) | N parallel cables for complex signals
[cconj](libs/signals.md#sicconj) | [`si.`](libs/signals.md)[`cconj`](libs/signals.md#sicconj) | Complex conjugation of a (complex) signal
[cmul](libs/signals.md#sicmul) | [`si.`](libs/signals.md)[`cmul`](libs/signals.md#sicmul) | Multiply two complex signals pointwise
[Count Down](libs/basics.md#bacountdown) | [`ba.`](libs/basics.md)[`countdown`](libs/basics.md#bacountdown) | Samples count down
[Count Elements](libs/basics.md#bacount) | [`ba.`](libs/basics.md)[`count`](libs/basics.md#bacount) | Count elements in a list
[Count Up](libs/basics.md#bacountup) | [`ba.`](libs/basics.md)[`countup`](libs/basics.md#bacountup) | Samples count up
[Delay (Float)](libs/delays.md#defdelay) | [`de.`](libs/delays.md)[`fdelay`](libs/delays.md#defdelay) | Fractional delay
[Delay (Integer)](libs/delays.md#dedelay) | [`de.`](libs/delays.md)[`delay`](libs/delays.md#dedelay) | Integer delay
[Down Sample](libs/basics.md#badownsample) | [`ba.`](libs/basics.md)[`downSample`](libs/basics.md#badownsample) | Down sample a signal
[Impulsify](libs/basics.md#baimpulsify) | [`ba.`](libs/basics.md)[`impulsify`](libs/basics.md#baimpulsify) | Turns a signal into an impulse
[Sample and Hold](libs/basics.md#basandh) | [`ba.`](libs/basics.md)[`sAndH`](libs/basics.md#basandh) | Sample and hold
[Signal Crossing](libs/routes.md#rocross) | [`ro.`](libs/routes.md)[`cross`](libs/routes.md#rocross) | Cross n signals
[Smoother](libs/signals.md#sismooth) | [`si.`](libs/signals.md)[`smooth`](libs/signals.md#sismooth) | Exponential smoothing with controllable pole
[Smoother (Default)](libs/signals.md#sismoo) | [`si.`](libs/signals.md)[`smoo`](libs/signals.md#sismoo) | Exponential smoothing
[Take Element](libs/basics.md#batake) | [`ba.`](libs/basics.md)[`take`](libs/basics.md#batake) | Take en element from a list
[Time](libs/basics.md#batime) | [`ba.`](libs/basics.md)[`time`](libs/basics.md#batime) | A simple timer

<div class="table-end"></div>


## Conversion

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[dB to Linear](libs/basics.md#badb2linear) | [`ba.`](libs/basics.md)[`db2linear`](libs/basics.md#badb2linear) | Converts dB to linear values
[Frequency ratio to semintones](libs/basics.md#baratio2semi) | [`ba.`](libs/basics.md)[`ratio2semi`](libs/basics.md#baratio2semi) | Converts a frequency multiplicative ratio in semitones
[Hz to MIDI Key](libs/basics.md#bahz2midikey) | [`ba.`](libs/basics.md)[`hz2midikey`](libs/basics.md#bahz2midikey) | Converts a frequency into MIDI key number
[Linear to dB](libs/basics.md#balinear2db) | [`ba.`](libs/basics.md)[`linear2db`](libs/basics.md#balinear2db) | Converts linear values to dB
[MIDI Key to Hz](libs/basics.md#bamidikey2hz) | [`ba.`](libs/basics.md)[`midikey2hz`](libs/basics.md#bamidikey2hz) | Converts a MIDI key number into a frequency
[Pole to T60](libs/basics.md#bapole2tau) | [`ba.`](libs/basics.md)[`pole2tau`](libs/basics.md#bapole2tau) | Converts a pole into a time constant (t60)
[Samples to Seconds](libs/basics.md#basamp2sec) | [`ba.`](libs/basics.md)[`samp2sec`](libs/basics.md#basamp2sec) | Converts samples to seconds
[Seconds to Samples](libs/basics.md#basec2samp) | [`ba.`](libs/basics.md)[`sec2samp`](libs/basics.md#basec2samp) | Converts seconds to samples
[Semitones to Frequency ratio](libs/basics.md#basemi2ratio) | [`ba.`](libs/basics.md)[`semi2ratio`](libs/basics.md#basemi2ratio) | Converts semitones in a frequency multiplicative ratio
[T60 to Pole](libs/basics.md#batau2pole) | [`ba.`](libs/basics.md)[`tau2pole`](libs/basics.md#batau2pole) | Converts a time constant (t60) into a pole

<div class="table-end"></div>


## Effects

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[Auto Wah](libs/vaeffects.md#veautowah) | [`ve.`](libs/vaeffects.md)[`autowah`](libs/vaeffects.md#veautowah) | Auto-Wah effect
[Compressor](libs/compressors.md#cocompressor_mono) | [`co.`](libs/compressors.md)[`compressor_mono`](libs/compressors.md#cocompressor_mono) | Dynamic range compressor
[compressor_lad_mono](libs/compressors.md#cocompressor_lad_mono) | [`co.`](libs/compressors.md)[`compressor_lad_mono`](libs/compressors.md#cocompressor_lad_mono) | Mono dynamic range compressor with lookahead delay
[Crybaby](libs/vaeffects.md#vecrybaby) | [`ve.`](libs/vaeffects.md)[`crybaby`](libs/vaeffects.md#vecrybaby) | Crybaby wah pedal
[Distortion](libs/misceffects.md#efcubicnl) | [`ef.`](libs/misceffects.md)[`cubicnl`](libs/misceffects.md#efcubicnl) | Cubic nonlinearity distortion
[Echo](libs/misceffects.md#efecho) | [`ef.`](libs/misceffects.md)[`echo`](libs/misceffects.md#efecho) | Simple echo
[expander_N_chan](libs/compressors.md#coexpander_n_chan) | [`co.`](libs/compressors.md)[`expander_N_chan`](libs/compressors.md#coexpander_n_chan) | Feed forward N channels dynamic range expander
[expanderSC_N_chan](libs/compressors.md#coexpandersc_n_chan) | [`co.`](libs/compressors.md)[`expanderSC_N_chan`](libs/compressors.md#coexpandersc_n_chan) | Feed forward N channels dynamic range expander with sidechain
[FBcompressor_N_chan](libs/compressors.md#cofbcompressor_n_chan) | [`co.`](libs/compressors.md)[`FBcompressor_N_chan`](libs/compressors.md#cofbcompressor_n_chan) | Feed back N channels dynamic range compressor
[FBFFcompressor_N_chan](libs/compressors.md#cofbffcompressor_n_chan) | [`co.`](libs/compressors.md)[`FBFFcompressor_N_chan`](libs/compressors.md#cofbffcompressor_n_chan) | Feed forward / feed back N channels dynamic range compressor
[FFcompressor_N_chan](libs/compressors.md#coffcompressor_n_chan) | [`co.`](libs/compressors.md)[`FFcompressor_N_chan`](libs/compressors.md#coffcompressor_n_chan) | Feed forward N channels dynamic range compressor
[Flanger](libs/phaflangers.md#pfflanger_stereo) | [`pf.`](libs/phaflangers.md)[`flanger_stereo`](libs/phaflangers.md#pfflanger_stereo) | Flanging effect
[Gate](libs/misceffects.md#efgate_mono) | [`ef.`](libs/misceffects.md)[`gate_mono`](libs/misceffects.md#efgate_mono) | Mono signal gate
[gate_stereo](libs/misceffects.md#efgate_stereo) | [`ef.`](libs/misceffects.md)[`gate_stereo`](libs/misceffects.md#efgate_stereo) | Stereo signal gates
[Limiter](libs/compressors.md#colimiter_1176_r4_mono) | [`co.`](libs/compressors.md)[`limiter_1176_R4_mono`](libs/compressors.md#colimiter_1176_r4_mono) | Limiter
[Panner](libs/spats.md#sppanner) | [`sp.`](libs/spats.md)[`panner`](libs/spats.md#sppanner) | Linear stereo panner
[Panner](libs/spats.md#spspat) | [`sp.`](libs/spats.md)[`spat`](libs/spats.md#spspat) | N outputs spatializer
[peak_compression_gain_mono](libs/compressors.md#copeak_compression_gain_mono) | [`co.`](libs/compressors.md)[`peak_compression_gain_mono`](libs/compressors.md#copeak_compression_gain_mono) | Mono dynamic range compressor gain computer with linear output
[peak_compression_gain_mono_db](libs/compressors.md#copeak_compression_gain_mono_db) | [`co.`](libs/compressors.md)[`peak_compression_gain_mono_db`](libs/compressors.md#copeak_compression_gain_mono_db) | Mono dynamic range compressor gain computer with dB output
[peak_compression_gain_N_chan](libs/compressors.md#copeak_compression_gain_n_chan) | [`co.`](libs/compressors.md)[`peak_compression_gain_N_chan`](libs/compressors.md#copeak_compression_gain_n_chan) | N channels dynamic range compressor gain computer with linear output
[peak_compression_gain_N_chan_db](libs/compressors.md#copeak_compression_gain_n_chan_db) | [`co.`](libs/compressors.md)[`peak_compression_gain_N_chan_db`](libs/compressors.md#copeak_compression_gain_n_chan_db) | N channels dynamic range compressor gain computer with dB output
[peak_expansion_gain_N_chan_db](libs/compressors.md#copeak_expansion_gain_n_chan_db) | [`co.`](libs/compressors.md)[`peak_expansion_gain_N_chan_db`](libs/compressors.md#copeak_expansion_gain_n_chan_db) | N channels dynamic range expander gain computer
[Phaser](libs/phaflangers.md#pfphaser2_stereo) | [`pf.`](libs/phaflangers.md)[`phaser2_stereo`](libs/phaflangers.md#pfphaser2_stereo) | Phaser effect
[Pitch Shift](libs/misceffects.md#eftranspose) | [`ef.`](libs/misceffects.md)[`transpose`](libs/misceffects.md#eftranspose) | Simple pitch shifter
[rEncoder3D](libs/hoa.md#horencoder3d) | [`ho.`](libs/hoa.md)[`rEncoder3D`](libs/hoa.md#horencoder3d) | Ambisonic encoder in 3D including source rotation. A mono signal is encoded at at certain ambisonic order
[Reverb (FDN)](libs/reverbs.md#refdnrev0) | [`re.`](libs/reverbs.md)[`fdnrev0`](libs/reverbs.md#refdnrev0) | Feedback delay network reverberator
[Reverb (Freeverb)](libs/reverbs.md#remono_freeverb) | [`re.`](libs/reverbs.md)[`mono_freeverb`](libs/reverbs.md#remono_freeverb) | Most "famous" Schroeder reverberator
[Reverb (Simple)](libs/reverbs.md#rejcrev) | [`re.`](libs/reverbs.md)[`jcrev`](libs/reverbs.md#rejcrev) | Simple Schroeder reverberator
[Reverb (Zita)](libs/reverbs.md#rezita_rev1_stereo) | [`re.`](libs/reverbs.md)[`zita_rev1_stereo`](libs/reverbs.md#rezita_rev1_stereo) | High quality FDN reverberator
[RMS_compression_gain_mono](libs/compressors.md#corms_compression_gain_mono) | [`co.`](libs/compressors.md)[`RMS_compression_gain_mono`](libs/compressors.md#corms_compression_gain_mono) | Mono RMS dynamic range compressor gain computer with linear output
[RMS_compression_gain_mono_db](libs/compressors.md#corms_compression_gain_mono_db) | [`co.`](libs/compressors.md)[`RMS_compression_gain_mono_db`](libs/compressors.md#corms_compression_gain_mono_db) | Mono RMS dynamic range compressor gain computer with dB output
[RMS_compression_gain_N_chan](libs/compressors.md#corms_compression_gain_n_chan) | [`co.`](libs/compressors.md)[`RMS_compression_gain_N_chan`](libs/compressors.md#corms_compression_gain_n_chan) | RMS N channels dynamic range compressor gain computer with linear output
[RMS_compression_gain_N_chan_db](libs/compressors.md#corms_compression_gain_n_chan_db) | [`co.`](libs/compressors.md)[`RMS_compression_gain_N_chan_db`](libs/compressors.md#corms_compression_gain_n_chan_db) | RMS N channels dynamic range compressor gain computer with dB output
[RMS_FBcompressor_peak_limiter_N_chan](libs/compressors.md#corms_fbcompressor_peak_limiter_n_chan) | [`co.`](libs/compressors.md)[`RMS_FBcompressor_peak_limiter_N_chan`](libs/compressors.md#corms_fbcompressor_peak_limiter_n_chan) | N channel RMS feed back compressor into peak limiter feeding back into the FB compressor
[RMS_FBFFcompressor_N_chan](libs/compressors.md#corms_fbffcompressor_n_chan) | [`co.`](libs/compressors.md)[`RMS_FBFFcompressor_N_chan`](libs/compressors.md#corms_fbffcompressor_n_chan) | RMS feed forward / feed back N channels dynamic range compressor
[Speaker Simulator](libs/misceffects.md#efspeakerbp) | [`ef.`](libs/misceffects.md)[`speakerbp`](libs/misceffects.md#efspeakerbp) | Simple speaker simulator
[Stereo Width](libs/misceffects.md#efstereo_width) | [`ef.`](libs/misceffects.md)[`stereo_width`](libs/misceffects.md#efstereo_width) | Stereo width effect
[Vocoder](libs/vaeffects.md#vevocoder) | [`ve.`](libs/vaeffects.md)[`vocoder`](libs/vaeffects.md#vevocoder) | Simple vocoder
[Wah](libs/vaeffects.md#vewah4) | [`ve.`](libs/vaeffects.md)[`wah4`](libs/vaeffects.md#vewah4) | Wah effect

<div class="table-end"></div>


## Envelope Generators

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[ADSR](libs/envelopes.md#enadsr) | [`en.`](libs/envelopes.md)[`adsr`](libs/envelopes.md#enadsr) | Attack/Decay/Sustain/Release envelope generator
[AR](libs/envelopes.md#enar) | [`en.`](libs/envelopes.md)[`ar`](libs/envelopes.md#enar) | Attack/Release envelope generator
[ASR](libs/envelopes.md#enasr) | [`en.`](libs/envelopes.md)[`asr`](libs/envelopes.md#enasr) | Attack/Sustain/Release envelope generator
[Exponential](libs/envelopes.md#ensmoothenvelope) | [`en.`](libs/envelopes.md)[`smoothEnvelope`](libs/envelopes.md#ensmoothenvelope) | Exponential envelope generator

<div class="table-end"></div>


## Filters

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[Bandpass (Butterworth)](libs/filters.md#fibandpass) | [`fi.`](libs/filters.md)[`bandpass`](libs/filters.md#fibandpass) | Generic butterworth bandpass
[Bandpass (Resonant)](libs/filters.md#firesonbp) | [`fi.`](libs/filters.md)[`resonbp`](libs/filters.md#firesonbp) | Virtual analog resonant bandpass
[Bandstop (Butterworth)](libs/filters.md#fibandstop) | [`fi.`](libs/filters.md)[`bandstop`](libs/filters.md#fibandstop) | Generic butterworth bandstop
[Biquad](libs/filters.md#fitf2) | [`fi.`](libs/filters.md)[`tf2`](libs/filters.md#fitf2) | "Standard" biquad filter
[Comb (Allpass)](libs/filters.md#fiallpass_fcomb) | [`fi.`](libs/filters.md)[`allpass_fcomb`](libs/filters.md#fiallpass_fcomb) | Schroeder allpass comb filter
[Comb (Feedback)](libs/filters.md#fifb_fcomb) | [`fi.`](libs/filters.md)[`fb_fcomb`](libs/filters.md#fifb_fcomb) | Feedback comb filter
[Comb (Feedforward)](libs/filters.md#fiff_fcomb) | [`fi.`](libs/filters.md)[`ff_fcomb`](libs/filters.md#fiff_fcomb) | Feed-forward comb filter.
[ff_comb](libs/filters.md#fiff_comb) | [`fi.`](libs/filters.md)[`ff_comb`](libs/filters.md#fiff_comb) | Feed-Forward Comb Filter. Note that `ff_comb` requires integer delays
[Filterbank](libs/filters.md#fifilterbank) | [`fi.`](libs/filters.md)[`filterbank`](libs/filters.md#fifilterbank) | Generic filter bank
[FIR (Arbitrary Order)](libs/filters.md#fifir) | [`fi.`](libs/filters.md)[`fir`](libs/filters.md#fifir) | Nth-order FIR filter
[fx](libs/filters.md#fifx) | [`fi.`](libs/filters.md)[`fx`](libs/filters.md#fifx) | Default low shelf filter: 3rd-order Butterworth case of `fi.lowshelf`
[High Shelf](libs/filters.md#fihigh_shelf) | [`fi.`](libs/filters.md)[`high_shelf`](libs/filters.md#fihigh_shelf) | High shelf
[Highpass (Butterworth)](libs/filters.md#fihighpass) | [`fi.`](libs/filters.md)[`highpass`](libs/filters.md#fihighpass) | Nth-order Butterworth highpass
[Highpass (Resonant)](libs/filters.md#firesonhp) | [`fi.`](libs/filters.md)[`resonhp`](libs/filters.md#firesonhp) | Virtual analog resonant highpass
[IIR (Arbitrary Order)](libs/filters.md#fiiir) | [`fi.`](libs/filters.md)[`iir`](libs/filters.md#fiiir) | Nth-order IIR filter
[Level Filter](libs/filters.md#filevelfilter) | [`fi.`](libs/filters.md)[`levelfilter`](libs/filters.md#filevelfilter) | Dynamic level lowpass
[Low Shelf](libs/filters.md#filow_shelf) | [`fi.`](libs/filters.md)[`low_shelf`](libs/filters.md#filow_shelf) | Low shelf
[Lowpass (Butterworth)](libs/filters.md#filowpass) | [`fi.`](libs/filters.md)[`lowpass`](libs/filters.md#filowpass) | Nth-order Butterworth lowpass
[Lowpass (Resonant)](libs/filters.md#firesonlp) | [`fi.`](libs/filters.md)[`resonlp`](libs/filters.md#firesonlp) | Virtual analog resonant lowpass
[Notch Filter](libs/filters.md#finotchw) | [`fi.`](libs/filters.md)[`notchw`](libs/filters.md#finotchw) | Simple notch filter
[Peak Equalizer](libs/filters.md#fipeak_eq) | [`fi.`](libs/filters.md)[`peak_eq`](libs/filters.md#fipeak_eq) | Peaking equalizer section

<div class="table-end"></div>


## Oscillators/Sound Generators

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[CZhalfSine](libs/oscillators.md#osczhalfsine) | [`os.`](libs/oscillators.md)[`CZhalfSine`](libs/oscillators.md#osczhalfsine) | Oscillator that mimics the Casio CZ half sine oscillator
[CZhalfSineP](libs/oscillators.md#osczhalfsinep) | [`os.`](libs/oscillators.md)[`CZhalfSineP`](libs/oscillators.md#osczhalfsinep) | Oscillator that mimics the Casio CZ half sine oscillator,
[CZpulse](libs/oscillators.md#osczpulse) | [`os.`](libs/oscillators.md)[`CZpulse`](libs/oscillators.md#osczpulse) | Oscillator that mimics the Casio CZ pulse oscillator
[CZpulseP](libs/oscillators.md#osczpulsep) | [`os.`](libs/oscillators.md)[`CZpulseP`](libs/oscillators.md#osczpulsep) | Oscillator that mimics the Casio CZ pulse oscillator,
[CZresSaw](libs/oscillators.md#osczressaw) | [`os.`](libs/oscillators.md)[`CZresSaw`](libs/oscillators.md#osczressaw) | Oscillator that mimics the Casio CZ resonant sawtooth oscillator
[CZresTrap](libs/oscillators.md#osczrestrap) | [`os.`](libs/oscillators.md)[`CZresTrap`](libs/oscillators.md#osczrestrap) | Oscillator that mimics the Casio CZ resonant trapeze oscillator
[CZresTriangle](libs/oscillators.md#osczrestriangle) | [`os.`](libs/oscillators.md)[`CZresTriangle`](libs/oscillators.md#osczrestriangle) | Oscillator that mimics the Casio CZ resonant triangle oscillator
[CZsaw](libs/oscillators.md#osczsaw) | [`os.`](libs/oscillators.md)[`CZsaw`](libs/oscillators.md#osczsaw) | Oscillator that mimics the Casio CZ saw oscillator
[CZsawP](libs/oscillators.md#osczsawp) | [`os.`](libs/oscillators.md)[`CZsawP`](libs/oscillators.md#osczsawp) | Oscillator that mimics the Casio CZ saw oscillator,
[CZsinePulse](libs/oscillators.md#osczsinepulse) | [`os.`](libs/oscillators.md)[`CZsinePulse`](libs/oscillators.md#osczsinepulse) | Oscillator that mimics the Casio CZ sine/pulse oscillator
[CZsinePulseP](libs/oscillators.md#osczsinepulsep) | [`os.`](libs/oscillators.md)[`CZsinePulseP`](libs/oscillators.md#osczsinepulsep) | Oscillator that mimics the Casio CZ sine/pulse oscillator,
[CZsquare](libs/oscillators.md#osczsquare) | [`os.`](libs/oscillators.md)[`CZsquare`](libs/oscillators.md#osczsquare) | Oscillator that mimics the Casio CZ square oscillator
[CZsquareP](libs/oscillators.md#osczsquarep) | [`os.`](libs/oscillators.md)[`CZsquareP`](libs/oscillators.md#osczsquarep) | Oscillator that mimics the Casio CZ square oscillator,
[Impulse](libs/oscillators.md#osimpulse) | [`os.`](libs/oscillators.md)[`impulse`](libs/oscillators.md#osimpulse) | Generate an impulse on start-up
[Impulse Train](libs/oscillators.md#osimptrain) | [`os.`](libs/oscillators.md)[`imptrain`](libs/oscillators.md#osimptrain) | Band-limited impulse train
[loop](libs/soundfiles.md#soloop) | [`so.`](libs/soundfiles.md)[`loop`](libs/soundfiles.md#soloop) | Play a soundfile in a loop taking into account its sampling rate
[loop_speed](libs/soundfiles.md#soloop_speed) | [`so.`](libs/soundfiles.md)[`loop_speed`](libs/soundfiles.md#soloop_speed) | Play a soundfile in a loop taking into account its sampling rate, with speed control
[loop_speed_level](libs/soundfiles.md#soloop_speed_level) | [`so.`](libs/soundfiles.md)[`loop_speed_level`](libs/soundfiles.md#soloop_speed_level) | Play a soundfile in a loop taking into account its sampling rate, with speed and level controls
[oscsin](libs/oscillators.md#ososcsin) | [`os.`](libs/oscillators.md)[`oscsin`](libs/oscillators.md#ososcsin) | Sine wave oscillator
[Phasor](libs/oscillators.md#osphasor) | [`os.`](libs/oscillators.md)[`phasor`](libs/oscillators.md#osphasor) | Simple phasor
[Pink Noise](libs/noises.md#nopink_noise) | [`no.`](libs/noises.md)[`pink_noise`](libs/noises.md#nopink_noise) | Pink noise generator
[Pulse Train](libs/oscillators.md#ospulsetrain) | [`os.`](libs/oscillators.md)[`pulsetrain`](libs/oscillators.md#ospulsetrain) | Band-limited pulse train
[Pulse Train (Low Frequency)](libs/oscillators.md#oslf_imptrain) | [`os.`](libs/oscillators.md)[`lf_imptrain`](libs/oscillators.md#oslf_imptrain) | Low-frequency pulse train
[Sawtooth](libs/oscillators.md#ossawtooth) | [`os.`](libs/oscillators.md)[`sawtooth`](libs/oscillators.md#ossawtooth) | Band-limited sawtooth wave
[Sawtooth (Low Frequency)](libs/oscillators.md#oslf_saw) | [`os.`](libs/oscillators.md)[`lf_saw`](libs/oscillators.md#oslf_saw) | Low-frequency sawtooth wave
[Sine (Filter-Based)](libs/oscillators.md#ososcs) | [`os.`](libs/oscillators.md)[`oscs`](libs/oscillators.md#ososcs) | Sine oscillator (filter-based)
[Sine (Table-Based)](libs/oscillators.md#ososc) | [`os.`](libs/oscillators.md)[`osc`](libs/oscillators.md#ososc) | Sine oscillator (table-based)
[Square](libs/oscillators.md#ossquare) | [`os.`](libs/oscillators.md)[`square`](libs/oscillators.md#ossquare) | Band-limited square wave
[Square (Low Frequency)](libs/oscillators.md#oslf_squarewave) | [`os.`](libs/oscillators.md)[`lf_squarewave`](libs/oscillators.md#oslf_squarewave) | Low-frequency square wave
[Triangle](libs/oscillators.md#ostriangle) | [`os.`](libs/oscillators.md)[`triangle`](libs/oscillators.md#ostriangle) | Band-limited triangle wave
[Triangle (Low Frequency)](libs/oscillators.md#oslf_triangle) | [`os.`](libs/oscillators.md)[`lf_triangle`](libs/oscillators.md#oslf_triangle) | Low-frequency triangle wave
[White Noise](libs/noises.md#nonoise) | [`no.`](libs/noises.md)[`noise`](libs/noises.md#nonoise) | White noise generator

<div class="table-end"></div>


## Synths

<div class="table-begin"></div>

Function Type | Function Name | Description
--- | --- | ---
[Additive Drum](libs/synths.md#syadditivedrum) | [`sy.`](libs/synths.md)[`additiveDrum`](libs/synths.md#syadditivedrum) | Additive synthesis drum
[Bandpassed Sawtooth](libs/synths.md#sydubdub) | [`sy.`](libs/synths.md)[`dubDub`](libs/synths.md#sydubdub) | Sawtooth through resonant bandpass
[Comb String](libs/synths.md#sycombstring) | [`sy.`](libs/synths.md)[`combString`](libs/synths.md#sycombstring) | String model based on a comb filter
[FM](libs/synths.md#syfm) | [`sy.`](libs/synths.md)[`fm`](libs/synths.md#syfm) | Frequency modulation synthesizer
[Lowpassed Sawtooth](libs/synths.md#sysawtrombone) | [`sy.`](libs/synths.md)[`sawTrombone`](libs/synths.md#sysawtrombone) | "Trombone" based on a filtered sawtooth
[popFilterDrum](libs/synths.md#sypopfilterdrum) | [`sy.`](libs/synths.md)[`popFilterDrum`](libs/synths.md#sypopfilterdrum) | A simple percussion instrument based on a "popped" resonant bandpass filter

<div class="table-end"></div>

