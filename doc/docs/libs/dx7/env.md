
----

### `(dx.)env`


Volume Envelope in the DX7, based on Dexed/MSFA code.
The output is a Q24 number, so you may want to use `q24_to_linear`
to get a number in [0,1]

#### Usage
```
env(rates, levels, outlevel, rate_scaling, gate) : q24_to_linear
```

Where:

* `rates`: 4 channels of rates between 0-99
* `levels`: 4 channels of levels between 0-99
* `outlevel`: the output level in Dexed's scale: `scaleoutlevel(level) << 5` for a level in 0-99,
  to which `operator` adds the level scaling and the velocity. A level in 0-99 passed as is
  puts every target below the floor of the envelope, which then stays at 6.4e-5
* `rate_scaling`: added to each rate (0 to 27, from `ScaleRate(midinote, sensitivity)`);
  the rates saturate at 63, so a large value makes every segment instantaneous
* `gate`: trigger

#### Test
```
env = library("env.lib");
ba = library("basics.lib");
ma = library("maths.lib");
env_test = env.env((60,61,62,63), (99,90,70,0), env.scaleoutlevel(80) << 5, 0, button("gate")) : env.q24_to_linear;
env_slider_test = env.env((hslider("env:R1", 60, 0, 99, 1), hslider("env:R2", 61, 0, 99, 1), hslider("env:R3", 62, 0, 99, 1), hslider("env:R4", 63, 0, 99, 1)), (hslider("env:L1", 99, 0, 99, 1), hslider("env:L2", 90, 0, 99, 1), hslider("env:L3", 70, 0, 99, 1), hslider("env:L4", 0, 0, 99, 1)), int(env.scaleoutlevel(hslider("env:outlevel", 80, 0, 99, 1))) << 5, hslider("env:rate_scaling", 0, 0, 27, 1), button("gate")) : env.q24_to_linear;
env_scale_level_test = par(c, 4, env.ScaleLevel(note, 39, 50, 70, c, 3 - c)) with { P = int(ma.SR/10); note = int(128*ba.period(P)/P); };
env_scale_velocity_test = par(s, 8, env.ScaleVelocity(vel, s)) with { P = int(ma.SR/10); vel = 150*ba.period(P)/P - 10; };
env_scale_rate_test = par(s, 8, env.ScaleRate(note, s)) with { P = int(ma.SR/10); note = int(128*ba.period(P)/P); };
env_scaleoutlevel_test = env.scaleoutlevel(int(100*ba.period(P)/P)) with { P = int(ma.SR/10); };
```

#### Reference

* [https://github.com/asb2m10/dexed/blob/master/Source/msfa/env.cc](https://github.com/asb2m10/dexed/blob/master/Source/msfa/env.cc)
