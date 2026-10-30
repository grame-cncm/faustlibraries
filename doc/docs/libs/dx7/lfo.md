
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
ba = library("basics.lib");
ma = library("maths.lib");
lfo_test = lfo.lfo(1, 50, checkbox("Sync"),35, button("gate"));
lfo_wave_test = par(w, 6, lfo.lfo(w, 0, 1, 70, button("gate")) : _, !);
lfo_speed_test = par(s, 5, lfo.lfo(2, 0, 1, 20*s + 10, button("gate")) : _, !);
lfo_delay_test = par(d, 5, lfo.lfo(0, 20*d, 1, 35, button("gate")) : !, _);
lfo_sync_test = par(s, 2, lfo.lfo(0, 20, s, 35, gate)) with { P = int(ma.SR/4); gate = ba.period(P) < int(P/2); };
lfo_slider_test = lfo.lfo(hslider("lfo:wave", 4, 0, 5, 1), hslider("lfo:delay", 20, 0, 99, 1), hslider("lfo:sync", 1, 0, 1, 1), hslider("lfo:speed", 60, 0, 99, 1), button("gate"));
```

#### Reference

* [https://github.com/asb2m10/dexed/blob/master/Source/msfa/lfo.cc](https://github.com/asb2m10/dexed/blob/master/Source/msfa/lfo.cc)
