# Primitives

## User Interface Primitives

### `button`

Creates a button in the user interface. The button is primitive circuit with
one output and no input. The signal produced by the button is 0 when not
pressed and 1 while pressed.

#### Usage

```
button("play") : _;
```

Where `"play"` is the name of the button in the interface.
