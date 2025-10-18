re = library("reverbs.lib");
os = library("oscillators.lib");

jcrev_test = os.osc(440) : re.jcrev;
satrev_test = os.osc(330) : re.satrev;
fdnrev0_test = (os.osc(220), os.osc(330), os.osc(440), os.osc(550))
  <: re.fdnrev0(4096, (149, 211, 263, 293), 1, (800, 4000), (2.5, 2.0, 1.5), 0.8, 0.0);
zita_rev_fdn_test = par(i, 8, os.osc(110 * (i + 1)))
  <: re.zita_rev_fdn(200, 2000, 3.0, 2.0, 48000);
zita_rev1_stereo_test = (os.osc(440), os.osc(550))
  : re.zita_rev1_stereo(20, 200, 2000, 3.0, 2.0, 48000);
zita_rev1_ambi_test = (os.osc(330), os.osc(550))
  : re.zita_rev1_ambi(0.0, 25, 200, 2000, 3.0, 2.0, 48000);
vital_rev_test = (os.osc(330), os.osc(440))
  : re.vital_rev(0.2, 0.8, 0.5, 0.7, 0.4, 0.6, 0.3, 0.2, 0.1, 0.7, 0.5, 0.4);
mono_freeverb_test = os.osc(440) : re.mono_freeverb(0.7, 0.5, 0.3, 30);
stereo_freeverb_test = (os.osc(330), os.osc(550))
  : re.stereo_freeverb(0.7, 0.5, 0.3, 30);
dattorro_rev_test = (os.osc(330), os.osc(550))
  : re.dattorro_rev(200, 0.5, 0.7, 0.6, 0.5, 0.7, 0.5, 0.2);
dattorro_rev_default_test = (os.osc(330), os.osc(550))
  : re.dattorro_rev_default;
jpverb_test = (os.osc(330), os.osc(440))
  : re.jpverb(3.0, 0.2, 1.0, 0.8, 0.3, 0.4, 0.9, 0.8, 0.7, 500, 4000);
greyhole_test = (os.osc(220), os.osc(440))
  : re.greyhole(2.0, 0.3, 1.0, 0.6, 0.5, 0.4, 0.2);
kb_rom_rev1_test = (os.osc(330), os.osc(660))
  : re.kb_rom_rev1(0.7, 0.3);
