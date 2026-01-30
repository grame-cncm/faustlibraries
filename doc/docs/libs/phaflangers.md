#  phaflangers.lib 

Phasers and Flangers library. Its official prefix is `pf`.

This library provides a set of phaser and flanger effects based on delay-line
modulation. 

The Phaflangers library is organized into 1 section:

* [Functions Reference](#functions-reference)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/phaflangers.lib](https://github.com/grame-cncm/faustlibraries/blob/master/phaflangers.lib)

## Functions Reference


----

### `(pf.)flanger_mono`

Mono flanging effect.

#### Usage:

```
_ : flanger_mono(dmax,curdel,depth,fb,invert) : _
```

Where:

* `dmax`: maximum delay-line length (power of 2) - 10 ms typical
* `curdel`: current dynamic delay (not to exceed dmax)
* `depth`: effect strength between 0 and 1 (1 typical)
* `fb`: feedback gain between 0 and 1 (0 typical)
* `invert`: 0 for normal, 1 to invert sign of flanging sum

#### Test
```
pf = library("phaflangers.lib");
os = library("oscillators.lib");
flanger_mono_test = os.osc(440) : pf.flanger_mono(4096, 1024, 0.7, 0.25, 0);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Flanging.html](https://ccrma.stanford.edu/~jos/pasp/Flanging.html)

----

### `(pf.)flanger_stereo`

Stereo flanging effect.
`flanger_stereo` is a standard Faust function.

#### Usage:

```
_,_ : flanger_stereo(dmax,curdel1,curdel2,depth,fb,invert) : _,_
```

Where:

* `dmax`: maximum delay-line length (power of 2) - 10 ms typical
* `curdel1`: current dynamic delay for the left channel (not to exceed dmax)
* `curdel2`: current dynamic delay for the right channel (not to exceed dmax)
* `depth`: effect strength between 0 and 1 (1 typical)
* `fb`: feedback gain between 0 and 1 (0 typical)
* `invert`: 0 for normal, 1 to invert sign of flanging sum

#### Test
```
pf = library("phaflangers.lib");
os = library("oscillators.lib");
flanger_stereo_test = os.osc(440), os.osc(660) : pf.flanger_stereo(4096, 1024, 1536, 0.7, 0.25, 0);
```

#### References      

* [https://ccrma.stanford.edu/~jos/pasp/Flanging.html](https://ccrma.stanford.edu/~jos/pasp/Flanging.html)

----

### `(pf.)phaser2_mono`

Mono phasing effect.

#### Phaser

```
_ : phaser2_mono(Notches,phase,width,frqmin,fratio,frqmax,speed,depth,fb,invert) : _
```

Where:

* `Notches`: number of spectral notches (MACRO ARGUMENT - not a signal)
* `phase`: phase of the oscillator (0-1)
* `width`: approximate width of spectral notches in Hz
* `frqmin`: approximate minimum frequency of first spectral notch in Hz
* `fratio`: ratio of adjacent notch frequencies
* `frqmax`: approximate maximum frequency of first spectral notch in Hz
* `speed`: LFO frequency in Hz (rate of periodic notch sweep cycles)
* `depth`: effect strength between 0 and 1 (1 typical) (aka "intensity")
           when depth=2, "vibrato mode" is obtained (pure allpass chain)
* `fb`: feedback gain between -1 and 1 (0 typical)
* `invert`: 0 for normal, 1 to invert sign of flanging sum

#### Test
```
pf = library("phaflangers.lib");
os = library("oscillators.lib");
phaser2_mono_test = os.osc(330) : pf.phaser2_mono(4, 0.0, 50, 200, 1.5, 4000, 0.5, 0.8, 0.2, 0);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Phasing.html](https://ccrma.stanford.edu/~jos/pasp/Phasing.html)
* [http://www.geofex.com/Article_Folders/phasers/phase.html](http://www.geofex.com/Article_Folders/phasers/phase.html)
* 'An Allpass Approach to Digital Phasing and Flanging', Julius O. Smith III,
  Proc. Int. Computer Music Conf. (ICMC-84), pp. 103-109, Paris, 1984.
* CCRMA Tech. Report STAN-M-21: [https://ccrma.stanford.edu/STANM/stanms/stanm21/](https://ccrma.stanford.edu/STANM/stanms/stanm21/)

----

### `(pf.)phaser2_stereo`

Stereo phasing effect.
`phaser2_stereo` is a standard Faust function.

#### Phaser

```
_,_ : phaser2_stereo(Notches,width,frqmin,fratio,frqmax,speed,depth,fb,invert) : _,_
```

Where:

* `Notches`: number of spectral notches (MACRO ARGUMENT - not a signal)
* `width`: approximate width of spectral notches in Hz
* `frqmin`: approximate minimum frequency of first spectral notch in Hz
* `fratio`: ratio of adjacent notch frequencies
* `frqmax`: approximate maximum frequency of first spectral notch in Hz
* `speed`: LFO frequency in Hz (rate of periodic notch sweep cycles)
* `depth`: effect strength between 0 and 1 (1 typical) (aka "intensity")
           when depth=2, "vibrato mode" is obtained (pure allpass chain)
* `fb`: feedback gain between -1 and 1 (0 typical)
* `invert`: 0 for normal, 1 to invert sign of flanging sum

#### Test
```
pf = library("phaflangers.lib");
os = library("oscillators.lib");
phaser2_stereo_test = os.osc(220), os.osc(330) : pf.phaser2_stereo(4, 50, 200, 1.5, 4000, 0.5, 0.8, 0.2, 0);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Phasing.html](https://ccrma.stanford.edu/~jos/pasp/Phasing.html)
* [http://www.geofex.com/Article_Folders/phasers/phase.html](http://www.geofex.com/Article_Folders/phasers/phase.html)
* 'An Allpass Approach to Digital Phasing and Flanging', Julius O. Smith III,
   Proc. Int. Computer Music Conf. (ICMC-84), pp. 103-109, Paris, 1984.
* CCRMA Tech. Report STAN-M-21: [https://ccrma.stanford.edu/STANM/stanms/stanm21/](https://ccrma.stanford.edu/STANM/stanms/stanm21/)
