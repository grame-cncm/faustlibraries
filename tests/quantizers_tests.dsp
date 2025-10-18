qu = library("quantizers.lib");

quantize_test = qu.quantize(440, qu.ionian, hslider("input", 450, 100, 1000, 1));
quantizeSmoothed_test = qu.quantizeSmoothed(440, qu.ionian, hslider("input", 450, 100, 1000, 1));
ionian_test = qu.quantize(220, qu.ionian, 260);
dorian_test = qu.quantize(220, qu.dorian, 260);
phrygian_test = qu.quantize(220, qu.phrygian, 260);
lydian_test = qu.quantize(220, qu.lydian, 260);
mixo_test = qu.quantize(220, qu.mixo, 260);
eolian_test = qu.quantize(220, qu.eolian, 260);
locrian_test = qu.quantize(220, qu.locrian, 260);
pentanat_test = qu.quantize(220, qu.pentanat, 260);
kumoi_test = qu.quantize(220, qu.kumoi, 260);
natural_test = qu.quantize(220, qu.natural, 260);
dodeca_test = qu.quantize(220, qu.dodeca, 260);
dimin_test = qu.quantize(220, qu.dimin, 260);
penta_test = qu.quantize(220, qu.penta, 260);
