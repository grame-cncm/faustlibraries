#  dx7.lib 

Yamaha DX7 emulation library. Its official prefix is `dx`.

#### References
* [https://github.com/grame-cncm/faustlibraries/blob/master/dx7/dx7.lib](https://github.com/grame-cncm/faustlibraries/blob/master/dx7/dx7.lib)

----

### `(dx.)fdbkscalef`

DX7 feedback scaling conversion function.
Index 0 is special: it disables the feedback path entirely.

#### Usage:

```
fdbkscalef(fb_shift) : _
```

Where:

* `fb_shift`: DX7 feedback value

#### Test
```
dx = library("dx.lib");
fdbkscalef_test = dx.fdbkscalef(0.5);
```
#### Reference
* [https://github.com/asb2m10/dexed/blob/master/Source/EngineMkI.cpp](https://github.com/asb2m10/dexed/blob/master/Source/EngineMkI.cpp)

----

### `(dx.)fdbkscalef2`

DX7 feedback scaling conversion function for algos 4, 6, 32.
Index 0 is special: it disables the feedback path entirely.

#### Usage:

```
fdbkscalef2(fb_shift) : _
```

Where:

* `fb_shift`: DX7 feedback value

#### Test
```
dx = library("dx.lib");
fdbkscalef2_test = dx.fdbkscalef2(0.5);
```

#### Reference
* [https://github.com/asb2m10/dexed/blob/master/Source/EngineMkI.cpp](https://github.com/asb2m10/dexed/blob/master/Source/EngineMkI.cpp)

----

### `(dx.)algorithms`

Generic DX7 function where all parameters are controllable using UI elements.
This function is MIDI-compatible.

#### Usage

```
algorithms : _
```

#### Test
```
dx = library("dx.lib");
algorithms_test = dx.algorithms;
```

----

### `(dx.)algorithm`

DX7 function for a specific algorithm at compile-time. This function
comes with a GUI and is MIDI-compatible.

#### Usage

```
algorithm(algo) : _
```

Where:

* `algo`: algorithm identifier (1-32)

#### Test
```
dx = library("dx.lib");
algorithm1_test = dx.algorithm(1) <: _,_;
algorithm2_test = dx.algorithm(2) <: _,_;
algorithm3_test = dx.algorithm(3) <: _,_;
algorithm4_test = dx.algorithm(4) <: _,_;
algorithm5_test = dx.algorithm(5) <: _,_;
algorithm6_test = dx.algorithm(6) <: _,_; 
algorithm7_test = dx.algorithm(7) <: _,_;
algorithm8_test = dx.algorithm(8) <: _,_;
algorithm9_test = dx.algorithm(9) <: _,_;
algorithm10_test = dx.algorithm(10) <: _,_;
algorithm11_test = dx.algorithm(11) <: _,_;
algorithm12_test = dx.algorithm(12) <: _,_;
algorithm13_test = dx.algorithm(13) <: _,_;
algorithm14_test = dx.algorithm(14) <: _,_;
algorithm15_test = dx.algorithm(15) <: _,_;
algorithm16_test = dx.algorithm(16) <: _,_;
algorithm17_test = dx.algorithm(17) <: _,_;
algorithm18_test = dx.algorithm(18) <: _,_;
algorithm19_test = dx.algorithm(19) <: _,_;
algorithm20_test = dx.algorithm(20) <: _,_;
algorithm21_test = dx.algorithm(21) <: _,_;
algorithm22_test = dx.algorithm(22) <: _,_;
algorithm23_test = dx.algorithm(23) <: _,_;
algorithm24_test = dx.algorithm(24) <: _,_;
algorithm25_test = dx.algorithm(25) <: _,_;
algorithm26_test = dx.algorithm(26) <: _,_;
algorithm27_test = dx.algorithm(27) <: _,_;
algorithm28_test = dx.algorithm(28) <: _,_;
algorithm29_test = dx.algorithm(29) <: _,_;
algorithm30_test = dx.algorithm(30) <: _,_;
algorithm31_test = dx.algorithm(31) <: _,_;
algorithm32_test = dx.algorithm(32) <: _,_;           
```
