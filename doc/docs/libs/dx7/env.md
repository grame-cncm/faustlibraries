
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
* `outlevel`: Out level in 0-99
* `rate_scaling`: A value whose range is hard to describe. See the usage with `ScaleRate`
* `gate`: trigger

#### Test
```
env = library("env.lib");
env_test = env.env((60,61,62,63), (60,61,62,63), 80, 90, button("gate")) : env.q24_to_linear;
env_slider_test = env.env((hslider("env:R1", 60, 0, 99, 1), hslider("env:R2", 61, 0, 99, 1), hslider("env:R3", 62, 0, 99, 1), hslider("env:R4", 63, 0, 99, 1)), (hslider("env:L1", 60, 0, 99, 1), hslider("env:L2", 61, 0, 99, 1), hslider("env:L3", 62, 0, 99, 1), hslider("env:L4", 63, 0, 99, 1)), hslider("env:outlevel", 80, 0, 99, 1), hslider("env:rate_scaling", 90, 0, 99, 1), button("gate")) : env.q24_to_linear;
```

#### Reference

* [https://github.com/asb2m10/dexed/blob/master/Source/msfa/env.cc](https://github.com/asb2m10/dexed/blob/master/Source/msfa/env.cc)
