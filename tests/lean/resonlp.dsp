// fi.resonlp, a direct-form fi.tf2s section used by filter banks and
// vocoders. Pins the verdict at the six rates.
fi = library("filters.lib");
process = fi.resonlp(1000, 2, 0.8);
