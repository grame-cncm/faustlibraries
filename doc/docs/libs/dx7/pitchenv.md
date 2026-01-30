
----

### `(dx.)pitchenv`


Global Pitch Envelope in the DX7, based on Dexed/MSFA code.
The output is a Q24 number, so you may want to divide by 67108864
to get a number in [-1,1].

#### Usage
```
pitchenv(rates, levels, gate) : _
```

Where:

* `rates`: 4 channels of rates between 0-99
* `levels`: 4 channels of levels between 0-99
* `gate`: trigger

#### Test
```
pi = library("pitchenv.lib");
pitchenv_test = pi.pitchenv((60,61,62,63), (60,61,62,63), button("gate"));
```
#### Reference

* [https://github.com/asb2m10/dexed/blob/master/Source/msfa/pitchenv.cc](https://github.com/asb2m10/dexed/blob/master/Source/msfa/pitchenv.cc)
