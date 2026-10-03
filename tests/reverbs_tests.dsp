re = library("reverbs.lib");
os = library("oscillators.lib");
ba = library("basics.lib");
ma = library("maths.lib");
no = library("noises.lib");

jcrev_test = os.tosc(440) : re.jcrev;
satrev_test = os.tosc(330) : re.satrev;
fdnrev0_test = (os.tosc(220), os.tosc(330), os.tosc(440), os.tosc(550))
  <: re.fdnrev0(4096, (149, 211, 263, 293), 1, (800, 4000), (1.5, 2.0, 2.5), 0.8, 0.0);
fdnrev0_slider_test = (os.tosc(220), os.tosc(330), os.tosc(440), os.tosc(550)) <: re.fdnrev0(4096, (149, 211, 263, 293), 1, (hslider("fdnrev0:f1", 800, 50, 5000, 1), hslider("fdnrev0:f2", 4000, 100, 10000, 1)), (hslider("fdnrev0:t60high", 1.5, 0.1, 10, 0.01), hslider("fdnrev0:t60mid", 2.0, 0.1, 10, 0.01), hslider("fdnrev0:t60low", 2.5, 0.1, 10, 0.01)), hslider("fdnrev0:loopgainmax", 0.8, 0, 1, 0.01), hslider("fdnrev0:nonl", 0.0, 0, 0.999, 0.001));
fdnrev0_modulated_test = par(i, 4, no.noises(4, i)) <: re.fdnrev0(4096, (149, 211, 263, 293), 1, (800, 4000), (1.5, 0.5*pow(10, tri), 2.5), 0.8, 0.0) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fdnrev0_jump_test = par(i, 4, no.noises(4, i)) <: re.fdnrev0(4096, (149, 211, 263, 293), 1, (800, 4000), (1.5, 0.5*pow(10, sq), 2.5), 0.8, 0.0) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
zita_rev_fdn_test = par(i, 8, os.tosc(110 * (i + 1)))
  <: re.zita_rev_fdn(200, 2000, 3.0, 2.0, 192000);
zita_rev_fdn_slider_test = par(i, 8, os.tosc(110 * (i + 1))) <: re.zita_rev_fdn(hslider("zita_rev_fdn:f1", 200, 50, 1000, 1), hslider("zita_rev_fdn:f2", 2000, 1500, 20000, 1), hslider("zita_rev_fdn:t60dc", 3.0, 1, 8, 0.1), hslider("zita_rev_fdn:t60m", 2.0, 1, 8, 0.1), 192000);
zita_rev_fdn_modulated_test = par(i, 8, no.noises(8, i)) : re.zita_rev_fdn(200, 2000, 3.0, pow(20, tri), 192000) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
zita_rev_fdn_jump_test = par(i, 8, no.noises(8, i)) : re.zita_rev_fdn(200, 2000, 3.0, pow(20, sq), 192000) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
zita_in_delay_test = os.tosc(440), os.tosc(660) : re.zita_in_delay(60);
zita_in_delay_long_test = no.noise, no.noise : re.zita_in_delay(200);
zita_distrib2_test = os.tosc(440), os.tosc(660) : re.zita_distrib2(8);
zita_rev1_stereo_test = (os.tosc(440), os.tosc(550))
  : re.zita_rev1_stereo(20, 200, 2000, 3.0, 2.0, 192000);
zita_rev1_stereo_slider_test = (os.tosc(440), os.tosc(550)) : re.zita_rev1_stereo(hslider("zita_rev1_stereo:rdel", 20, 0, 100, 1), hslider("zita_rev1_stereo:f1", 200, 50, 1000, 1), hslider("zita_rev1_stereo:f2", 2000, 1500, 20000, 1), hslider("zita_rev1_stereo:t60dc", 3.0, 1, 8, 0.1), hslider("zita_rev1_stereo:t60m", 2.0, 1, 8, 0.1), 192000);
zita_rev1_ambi_test = (os.tosc(330), os.tosc(550))
  : re.zita_rev1_ambi(0.0, 25, 200, 2000, 3.0, 2.0, 192000);
vital_rev_test = (os.tosc(330), os.tosc(440))
  : re.vital_rev(0.2, 0.8, 0.5, 0.7, 0.4, 0.6, 0.3, 0.2, 0.1, 0.7, 0.5, 0.4);
vital_rev_modulated_test = (no.noises(2, 0), no.noises(2, 1)) : re.vital_rev(0.2, 0.8, 0.5, 0.7, 0.4, 0.6, 0, 0.2, 0.1, 0.7, tri, 0.4) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
vital_rev_jump_test = (no.noises(2, 0), no.noises(2, 1)) : re.vital_rev(0.2, 0.8, 0.5, 0.7, 0.4, 0.6, 0, 0.2, 0.1, 0.3 + 0.6*sq, 0.5, 0.4) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
mono_freeverb_test = os.tosc(440) : re.mono_freeverb(0.7, 0.5, 0.3, 30);
mono_freeverb_slider_test = os.tosc(440) : re.mono_freeverb(hslider("mono_freeverb:fb1", 0.7, 0, 0.99, 0.01), hslider("mono_freeverb:fb2", 0.5, 0, 0.99, 0.01), hslider("mono_freeverb:damp", 0.3, 0, 1, 0.01), 30);
mono_freeverb_modulated_test = no.noise : re.mono_freeverb(0.7, 0.5, tri, 30) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
mono_freeverb_jump_test = no.noise : re.mono_freeverb(0.5 + 0.45*sq, 0.5, 0.3, 30) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
stereo_freeverb_test = (os.tosc(330), os.tosc(550))
  : re.stereo_freeverb(0.7, 0.5, 0.3, 30);
dattorro_rev_test = (os.tosc(330), os.tosc(550))
  : re.dattorro_rev(200, 0.5, 0.7, 0.6, 0.5, 0.7, 0.5, 0.2);
dattorro_rev_slider_test = (os.tosc(330), os.tosc(550)) : re.dattorro_rev(200, hslider("dattorro_rev:bw", 0.5, 0, 1, 0.01), hslider("dattorro_rev:i_diff1", 0.7, 0, 1, 0.01), hslider("dattorro_rev:i_diff2", 0.6, 0, 1, 0.01), hslider("dattorro_rev:decay", 0.5, 0, 0.99, 0.01), hslider("dattorro_rev:d_diff1", 0.7, 0, 1, 0.01), hslider("dattorro_rev:d_diff2", 0.5, 0, 1, 0.01), hslider("dattorro_rev:damping", 0.2, 0, 1, 0.01));
dattorro_rev_modulated_test = (no.noises(2, 0), no.noises(2, 1)) : re.dattorro_rev(200, 0.5, 0.7, 0.6, 0.5, 0.7, 0.5, tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
dattorro_rev_jump_test = (no.noises(2, 0), no.noises(2, 1)) : re.dattorro_rev(200, 0.5, 0.7, 0.6, 0.3 + 0.6*sq, 0.7, 0.5, 0.2) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
dattorro_rev_default_test = (os.tosc(330), os.tosc(550))
  : re.dattorro_rev_default;
jpverb_test = (os.tosc(330), os.tosc(440))
  : re.jpverb(3.0, 0.2, 1.0, 0.8, 0.3, 0.4, 0.9, 0.8, 0.7, 500, 4000);
jpverb_slider_test = (os.tosc(330), os.tosc(440)) : re.jpverb(hslider("jpverb:t60", 3.0, 0.1, 60, 0.1), hslider("jpverb:damp", 0.2, 0, 0.999, 0.001), hslider("jpverb:size", 1.0, 0.5, 5, 0.01), hslider("jpverb:early_diff", 0.8, 0, 0.99, 0.001), hslider("jpverb:mod_depth", 0.3, 0, 1, 0.01), hslider("jpverb:mod_freq", 0.4, 0, 10, 0.01), hslider("jpverb:low", 0.9, 0, 1, 0.01), hslider("jpverb:mid", 0.8, 0, 1, 0.01), hslider("jpverb:high", 0.7, 0, 1, 0.01), hslider("jpverb:low_cutoff", 500, 100, 6000, 1), hslider("jpverb:high_cutoff", 4000, 1000, 10000, 1));
jpverb_modulated_test = (no.noises(2, 0), no.noises(2, 1)) : re.jpverb(0.5*pow(20, tri), 0.2, 1.0, 0.8, 0, 0.4, 0.9, 0.8, 0.7, 500, 4000) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
jpverb_jump_test = (no.noises(2, 0), no.noises(2, 1)) : re.jpverb(3.0, 0.9*sq, 1.0, 0.8, 0, 0.4, 0.9, 0.8, 0.7, 500, 4000) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
greyhole_test = (os.tosc(220), os.tosc(440))
  : re.greyhole(2.0, 0.3, 1.0, 0.6, 0.5, 0.4, 0.2);
greyhole_slider_test = (os.tosc(220), os.tosc(440)) : re.greyhole(hslider("greyhole:dt", 2.0, 0.1, 60, 0.1), hslider("greyhole:damp", 0.3, 0, 0.99, 0.001), hslider("greyhole:size", 1.0, 0.5, 3, 0.01), hslider("greyhole:early_diff", 0.6, 0, 0.99, 0.001), hslider("greyhole:feedback", 0.5, 0, 1, 0.01), hslider("greyhole:mod_depth", 0.4, 0, 1, 0.01), hslider("greyhole:mod_freq", 0.2, 0, 10, 0.01));
greyhole_modulated_test = (no.noises(2, 0), no.noises(2, 1)) : re.greyhole(2.0, 0.3, 1.0, 0.6, 0.2 + 0.7*tri, 0, 0.2) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
greyhole_jump_test = (no.noises(2, 0), no.noises(2, 1)) : re.greyhole(2.0, 0.3, 1.0, 0.6, 0.2 + 0.7*sq, 0, 0.2) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
springreverb_test = os.tosc(330)
  : re.springreverb(0.5, 0.5, 0.5, 0.5, 1);
springreverb_slider_test = os.tosc(330) : re.springreverb(hslider("springreverb:dwell", 0.5, 0, 1, 0.01), hslider("springreverb:blend", 0.5, 0, 1, 0.01), hslider("springreverb:tone", 0.5, 0, 1, 0.01), hslider("springreverb:tension", 0.5, 0, 1, 0.01), 1);
springreverb_modulated_test = no.noise : re.springreverb(0.5, 0.5, tri, 0.5, 1) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
springreverb_jump_test = no.noise : re.springreverb(0.5, 0.5, sq, 0.5, 1) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
kb_rom_rev1_test = (os.tosc(330), os.tosc(660))
  : re.kb_rom_rev1(0.7, 0.3);
kb_rom_rev1_slider_test = (os.tosc(330), os.tosc(660)) : re.kb_rom_rev1(hslider("kb_rom_rev1:rt", 0.7, 0, 0.99, 0.01), hslider("kb_rom_rev1:damp", 0.3, 0, 1, 0.01));
