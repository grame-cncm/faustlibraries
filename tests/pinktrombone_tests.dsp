//----------------------------------------------------------------------------
// pinktrombone_tests.dsp
// Deterministic tests for the Pink Trombone port
// (pinktrombone.lib).
//----------------------------------------------------------------------------

pt = library("pinktrombone.lib");
os = library("oscillators.lib");
ba = library("basics.lib");
si = library("signals.lib");
no = library("noises.lib");

pt_ticksPerSample_test = pt[ticksPerSample=1;].pinkTrombone(140, 0.6, 1, 0, 12.9, 2.43, 30, 3, 0, 0);
pt_noiseSeed_test = pt[noiseSeed=7;].glottis(140, 0.6, 1, 1) : _, !, !, !;
lfWaveform_test = par(i, 3, pt.lfWaveform(0.5 + i, os.lf_sawpos(100)));
lfWaveform_modulated_test = pt.lfWaveform(0.5 + 1.1*(1 + os.osc(2)), os.lf_sawpos(200));
glottis_test = pt.glottis(140, 0.6, (ba.time < 24000), 0);
glottis_modulated_test = pt.glottis(150 + 50*os.osc(0.8), 0.5 + 0.45*os.osc(4), (ba.time % 48000) > 12000, 1);
tractDiameters_test = pt.tractDiameters(12.9, 2.43, 30, 3, 0);
tractDiameters_constricted_test = pt.tractDiameters(20, 3.0, 30.4, 0.55, 1);
tractDiameters2_test = pt.tractDiameters2(20, 3.0, 36.3, 0.5, 1, 20.6, 0.8, 1);
tract_test = (os.lf_imptrain(140), 0.3) : pt.tract(12.9, 2.43, 30, 3, 0, 0);
tract_nasal_test = (os.lf_imptrain(140), 0.3) : pt.tract(27, 2.2, 30, 3, 0, 1);
tract_closure_test = (os.lf_imptrain(140), 0.3) : pt.tract(12.9, 2.43, 40, 0, 1, 0);
tract_release_test = (os.lf_imptrain(140), 0.3) : pt.tract(12.9, 2.43, 30, 0, ba.time < 12000, 0);
tract2_test = (os.lf_imptrain(140), 0.3) : pt.tract2(12.9, 2.43, 36.3, 0.5, 1, 20.6, 0.8, 1, 0);
tractExt_test = pt.tractExt(no.noise, 12.9, 2.43, 30.4, 0.55, 1, 0, os.lf_imptrain(140), 0.3);
tract2Ext_test = pt.tract2Ext(no.noise, 12.9, 2.43, 36.3, 0.5, 1, 20.6, 0.8, 1, 0, os.lf_imptrain(140), 0.3);
pinkTrombone_test = pt.pinkTrombone(140, 0.6, 1, 0, 12.9, 2.43, 30, 3, 0, 0);
pinkTrombone2_test = pt.pinkTrombone2(140, 0.6, 1, 0, 12.9, 2.43, 40, 0.2, 1, 20, 1.0, 1, 1);
