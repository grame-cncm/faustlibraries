# Primitives

## User Interface Primitives

### `button`

Creates a button in the user interface. The `button` is a primitive circuit 
with one output and no input. The signal produced by the `button` is 0 when not
pressed and 1 while pressed.

#### Usage

```
button("play") : _;
```

Where `"play"` is the name of the `button` in the interface.

---

### `checkbox`

Creates a checkbox in the user interface. The `checkbox` is a primitive circuit 
with one output and no input. The signal produced by the checkbox is 0 when not
checked and 1 when checked.

#### Usage

```
checkbox("play") : _;
```

Where `"play"` is the name of the `checkbox` in the interface.

---

### `hslider`

Creates a horizontal slider in the user interface. The `hslider` is a 
primitive circuit with one output and no input. `hslider` produces a signal
between a minimum and a maximum value based on the position of the slider 
cursor. 

#### Usage

```
hslider("volume",-10,-70,12,0.1) : _;
```

Where `volume` is the name of the slider in the interface, `-10` the default
value of the slider when the program starts, `-70` the minimum value, `12` the
maximum value, and `0.1` the step the determines the precision of the control.

---

### `nentry`

Creates a numerical entry in the user interface. The `nentry` is a 
primitive circuit with one output and no input. `nentry` produces a signal
between a minimum and a maximum value based on the user input. 

#### Usage

```
nentry("volume",-10,-70,12,0.1) : _;
```

Where `volume` is the name of the numerical entry in the interface, `-10` the 
default value of the entry when the program starts, `-70` the minimum value, 
`12` the maximum value, and `0.1` the step the determines the precision of the 
control.

---

### `vslider`

Creates a vertical slider in the user interface. The `vslider` is a 
primitive circuit with one output and no input. `vslider` produces a signal
between a minimum and a maximum value based on the position of the slider 
cursor. 

#### Usage

```
vslider("volume",-10,-70,12,0.1) : _;
```

Where `volume` is the name of the slider in the interface, `-10` the default
value of the slider when the program starts, `-70` the minimum value, `12` the
maximum value, and `0.1` the step the determines the precision of the control.
