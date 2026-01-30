
----

### `(dx.)lfo`

The DX7 LFO module according to Dexed. The two outputs are the LFO
value and LFO delay. Both are between 0 and 1.0.
See `Dx7Note::compute` in Dexed.

#### Usage

```
lfo(lfoWave, lfoDelay, lfoSync, lfoSpeed, gate) : _, _
```

Where:

* `lfoWave`: LFO wave mode (0-5) (triangle, saw down, saw up, square, sine, sample&hold)
* `lfoDelay`: LFO delay (0-99)
* `lfoSync`: (0-1) (0=no retrigger; 1=retrigger)
* `lfoSpeed`: LFO speed (0-99)
* `gate`: trigger signal

#### Test
```
lfo = library("lfo.lib");
lfo_test = lfo.lfo(1, 50, checkbox("Sync"),35, button("gate"));
```

#### Reference

* [https://github.com/asb2m10/dexed/blob/master/Source/msfa/lfo.cc](https://github.com/asb2m10/dexed/blob/master/Source/msfa/lfo.cc)
