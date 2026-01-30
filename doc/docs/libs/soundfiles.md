#  soundfiles.lib 

Soundfiles library. Its official prefix is `so`.

This library provides functions and abstractions to read, write, and manage
audio files in Faust. It supports interpolation and looping controls for integration 
of recorded or pre-rendered audio in synthesis, effects, and compositional contexts.

The Soundfiles library is organized into 1 section:

* [Functions Reference](#functions-reference)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/soundfiles.lib](https://github.com/grame-cncm/faustlibraries/blob/master/soundfiles.lib)

## Functions Reference


----

### `(so.)loop`

Play a soundfile in a loop taking into account its sampling rate.
`loop` is a standard Faust function.

#### Usage

```
loop(sf, part) : si.bus(outputs(sf))
```

Where:

* `sf`: the soundfile
* `part`: the part in the soundfile list of sounds

#### Test
```
so = library("soundfiles.lib");
sf = soundfile("sound[url:{'tests/assets/silence.wav'}]", 1);
loop_test = so.loop(sf, 0);
```

----

### `(so.)loop_speed`

Play a soundfile in a loop taking into account its sampling rate, with speed control.
`loop_speed` is a standard Faust function.

#### Usage

```
loop_speed(sf, part, speed) : si.bus(outputs(sf))
```

Where:

* `sf`: the soundfile
* `part`: the part in the soundfile list of sounds
* `speed`: the speed between 0 and n

#### Test
```
so = library("soundfiles.lib");
sf = soundfile("sound[url:{'tests/assets/silence.wav'}]", 1);
loop_speed_test = so.loop_speed(sf, 0, hslider("loop_speed:speed", 1, 0, 2, 0.01));
```

----

### `(so.)loop_speed_level`

Play a soundfile in a loop taking into account its sampling rate, with speed and level controls.
`loop_speed_level` is a standard Faust function.

#### Usage

```
loop_speed_level(sf, part, speed, level) : si.bus(outputs(sf))
```

Where:

* `sf`: the soundfile
* `part`: the part in the soundfile list of sounds
* `speed`: the speed between 0 and n
* `level`: the volume between 0 and n

#### Test
```
so = library("soundfiles.lib");
sf = soundfile("sound[url:{'tests/assets/silence.wav'}]", 1);
loop_speed_level_test = so.loop_speed_level(
    sf,
    0,
    hslider("loop_speed_level:speed", 1, 0, 2, 0.01),
    hslider("loop_speed_level:level", 0.5, 0, 1, 0.01)
);
```
