// fi.bandpass built on fi.tf2sb, trapezoidal state-variable sections since
// #261. Pins the verdict of each section at the six rates.
fi = library("filters.lib");
process = fi.bandpass(1, 500, 2000);
