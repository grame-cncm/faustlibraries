// os.osc: a sine table read through the fixed-point phasor, certify compiling
// in single precision. The phase is masked to [0, 2^30), and the index shifted
// and scaled from it stays below the table size: IN RANGE. In double precision
// os.osc takes the form of phasor_float.dsp.
os = library("oscillators.lib");
process = os.osc(440);
