//----------------------------------------------------------------------------
// vaeffects_tests.dsp
// Tests for virtual analog effects library functions.
//----------------------------------------------------------------------------

ve = library("vaeffects.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");
ma = library("maths.lib");

moog_vcf_test = os.tosc(440) : ve.moog_vcf(0.5, 1000);
moog_vcf_slider_test = os.tosc(440)
  : ve.moog_vcf(
      hslider("moog_vcf:res", 0.5, 0, 1, 0.01),
      hslider("moog_vcf:freq", 1000, 50, 4000, 1)
    );
moog_vcf_modulated_test = no.noise : ve.moog_vcf(0.9, 50*pow(100, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
moog_vcf_jump_test = no.noise : ve.moog_vcf(0.9, 50*pow(100, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
moog_vcf_audio_modulated_test = 0.1*no.noise : ve.moog_vcf(0.9, max(20, 1000*(1 + 0.9*os.tosc(500))));

moog_vcf_2b_test = os.tosc(330) : ve.moog_vcf_2b(0.4, 1200);
moog_vcf_2b_slider_test = os.tosc(330)
  : ve.moog_vcf_2b(
      hslider("moog_vcf_2b:res", 0.4, 0, 1, 0.01),
      hslider("moog_vcf_2b:freq", 1200, 50, 6000, 1)
    );
moog_vcf_2b_modulated_test = no.noise : ve.moog_vcf_2b(0.95, 20*pow(500, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
moog_vcf_2b_jump_test = no.noise : ve.moog_vcf_2b(0.95, 20*pow(500, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
moog_vcf_2b_audio_modulated_test = 0.1*no.noise : ve.moog_vcf_2b(0.95, max(20, 1000*(1 + 0.9*os.tosc(500))));

moog_vcf_2bn_test = os.tosc(330) : ve.moog_vcf_2bn(0.4, 1200);
moog_vcf_2bn_slider_test = os.tosc(330)
  : ve.moog_vcf_2bn(
      hslider("moog_vcf_2bn:res", 0.4, 0, 1, 0.01),
      hslider("moog_vcf_2bn:freq", 1200, 50, 6000, 1)
    );
moog_vcf_2bn_modulated_test = no.noise : ve.moog_vcf_2bn(0.95, 20*pow(500, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
moog_vcf_2bn_jump_test = no.noise : ve.moog_vcf_2bn(0.95, 20*pow(500, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
moog_vcf_2bn_audio_modulated_test = 0.1*no.noise : ve.moog_vcf_2bn(0.95, max(20, 1000*(1 + 0.9*os.tosc(500))));

moogLadder_test = os.tosc(220) : ve.moogLadder(0.3, 4);
moogLadder_slider_test = os.tosc(220)
  : ve.moogLadder(
      hslider("moogLadder:normFreq", 0.3, 0, 1, 0.001),
      hslider("moogLadder:Q", 4, 0.7, 20, 0.1)
    );
moogLadder_modulated_test = no.noise : ve.moogLadder(0.8*tri, 20) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
moogLadder_jump_test = no.noise : ve.moogLadder(0.8*sq, 20) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
moogLadder_audio_modulated_test = 0.1*no.noise : ve.moogLadder(log10(max(20, 1000*(1 + 0.9*os.tosc(500)))/20)/3, 10);

lowpassLadder4_test = os.tosc(110) : ve.lowpassLadder4(2.0, 800);
lowpassLadder4_slider_test = os.tosc(110)
  : ve.lowpassLadder4(
      hslider("lowpassLadder4:k", 2.0, 0, 4, 0.1),
      hslider("lowpassLadder4:freq", 800, 50, 5000, 1)
    );
lowpassLadder4_modulated_test = no.noise : ve.lowpassLadder4(3.9, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lowpassLadder4_jump_test = no.noise : ve.lowpassLadder4(3.9, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
lowpassLadder4_audio_modulated_test = 0.1*no.noise : ve.lowpassLadder4(3.9, max(20, 1000*(1 + 0.9*os.tosc(500))));

moogHalfLadder_test = os.tosc(220) : ve.moogHalfLadder(0.3, 4);
moogHalfLadder_slider_test = os.tosc(220)
  : ve.moogHalfLadder(
      hslider("moogHalfLadder:normFreq", 0.3, 0, 1, 0.001),
      hslider("moogHalfLadder:Q", 4, 0.7, 20, 0.1)
    );
moogHalfLadder_modulated_test = no.noise : ve.moogHalfLadder(0.8*tri, 20) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
moogHalfLadder_jump_test = no.noise : ve.moogHalfLadder(0.8*sq, 20) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
moogHalfLadder_audio_modulated_test = 0.1*no.noise : ve.moogHalfLadder(log10(max(20, 1000*(1 + 0.9*os.tosc(500)))/20)/3, 10);

diodeLadder_test = os.tosc(220) : ve.diodeLadder(0.4, 4);
diodeLadder_slider_test = os.tosc(220)
  : ve.diodeLadder(
      hslider("diodeLadder:normFreq", 0.4, 0, 1, 0.001),
      hslider("diodeLadder:Q", 4, 0.7, 20, 0.1)
    );
diodeLadder_modulated_test = no.noise : ve.diodeLadder(0.8*tri, 20) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
diodeLadder_jump_test = no.noise : ve.diodeLadder(0.8*sq, 20) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
diodeLadder_audio_modulated_test = 0.1*no.noise : ve.diodeLadder(log10(max(20, 1000*(1 + 0.9*os.tosc(500)))/20)/3, 10);

korg35LPF_test = os.tosc(220) : ve.korg35LPF(0.35, 3.5);
korg35LPF_slider_test = os.tosc(220)
  : ve.korg35LPF(
      hslider("korg35LPF:normFreq", 0.35, 0, 1, 0.001),
      hslider("korg35LPF:Q", 3.5, 0.7, 10, 0.1)
    );
korg35LPF_modulated_test = no.noise : ve.korg35LPF(0.8*tri, 9.5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
korg35LPF_jump_test = no.noise : ve.korg35LPF(0.8*sq, 9.5) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
korg35LPF_audio_modulated_test = 0.1*no.noise : ve.korg35LPF(log10(max(20, 1000*(1 + 0.9*os.tosc(500)))/20)/3, 9.5);

korg35HPF_test = os.tosc(330) : ve.korg35HPF(0.4, 3.5);
korg35HPF_slider_test = os.tosc(330)
  : ve.korg35HPF(
      hslider("korg35HPF:normFreq", 0.4, 0, 1, 0.001),
      hslider("korg35HPF:Q", 3.5, 0.7, 10, 0.1)
    );
korg35HPF_modulated_test = no.noise : ve.korg35HPF(0.8*tri, 9.5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
korg35HPF_jump_test = no.noise : ve.korg35HPF(0.8*sq, 9.5) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
korg35HPF_audio_modulated_test = 0.1*no.noise : ve.korg35HPF(log10(max(20, 1000*(1 + 0.9*os.tosc(500)))/20)/3, 9.5);

oberheim_test = os.tosc(220) : ve.oberheim(0.4, 1.5);
oberheim_slider_test = os.tosc(220)
  : ve.oberheim(
      hslider("oberheim:normFreq", 0.4, 0, 1, 0.001),
      hslider("oberheim:Q", 1.5, 0.5, 10, 0.1)
    );
oberheim_modulated_test = no.noise : ve.oberheim(0.8*tri, 10) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
oberheim_jump_test = no.noise : ve.oberheim(0.8*sq, 10) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
oberheim_audio_modulated_test = 0.1*no.noise : ve.oberheim(log10(max(20, 1000*(1 + 0.9*os.tosc(500)))/20)/3, 10);

oberheimBSF_test = os.tosc(220) : ve.oberheimBSF(0.4, 1.5);
oberheimBSF_slider_test = os.tosc(220)
  : ve.oberheimBSF(
      hslider("oberheimBSF:normFreq", 0.4, 0, 1, 0.001),
      hslider("oberheimBSF:Q", 1.5, 0.5, 10, 0.1)
    );

oberheimBPF_test = os.tosc(220) : ve.oberheimBPF(0.4, 1.5);
oberheimBPF_slider_test = os.tosc(220)
  : ve.oberheimBPF(
      hslider("oberheimBPF:normFreq", 0.4, 0, 1, 0.001),
      hslider("oberheimBPF:Q", 1.5, 0.5, 10, 0.1)
    );

oberheimHPF_test = os.tosc(220) : ve.oberheimHPF(0.4, 1.5);
oberheimHPF_slider_test = os.tosc(220)
  : ve.oberheimHPF(
      hslider("oberheimHPF:normFreq", 0.4, 0, 1, 0.001),
      hslider("oberheimHPF:Q", 1.5, 0.5, 10, 0.1)
    );

oberheimLPF_test = os.tosc(220) : ve.oberheimLPF(0.4, 1.5);
oberheimLPF_slider_test = os.tosc(220)
  : ve.oberheimLPF(
      hslider("oberheimLPF:normFreq", 0.4, 0, 1, 0.001),
      hslider("oberheimLPF:Q", 1.5, 0.5, 10, 0.1)
    );

sallenKeyOnePole_test = os.tosc(440) : ve.sallenKeyOnePole(0.25);
sallenKeyOnePole_slider_test = os.tosc(440)
  : ve.sallenKeyOnePole(
      hslider("sallenKeyOnePole:normFreq", 0.25, 0, 1, 0.001)
    );
sallenKeyOnePole_modulated_test = no.noise : ve.sallenKeyOnePole(0.8*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
sallenKeyOnePole_jump_test = no.noise : ve.sallenKeyOnePole(0.8*sq) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };

sallenKeyOnePoleLPF_test = os.tosc(440) : ve.sallenKeyOnePoleLPF(0.25);
sallenKeyOnePoleLPF_slider_test = os.tosc(440)
  : ve.sallenKeyOnePoleLPF(
      hslider("sallenKeyOnePoleLPF:normFreq", 0.25, 0, 1, 0.001)
    );

sallenKeyOnePoleHPF_test = os.tosc(440) : ve.sallenKeyOnePoleHPF(0.25);
sallenKeyOnePoleHPF_slider_test = os.tosc(440)
  : ve.sallenKeyOnePoleHPF(
      hslider("sallenKeyOnePoleHPF:normFreq", 0.25, 0, 1, 0.001)
    );

sallenKey2ndOrder_test = os.tosc(330) : ve.sallenKey2ndOrder(0.3, 1.0);
sallenKey2ndOrder_slider_test = os.tosc(330)
  : ve.sallenKey2ndOrder(
      hslider("sallenKey2ndOrder:normFreq", 0.3, 0, 1, 0.001),
      hslider("sallenKey2ndOrder:Q", 1.0, 0.1, 10, 0.1)
    );
sallenKey2ndOrder_modulated_test = no.noise : ve.sallenKey2ndOrder(0.8*tri, 10) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
sallenKey2ndOrder_jump_test = no.noise : ve.sallenKey2ndOrder(0.8*sq, 10) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
sallenKey2ndOrder_audio_modulated_test = 0.1*no.noise : ve.sallenKey2ndOrder(log10(max(20, 1000*(1 + 0.9*os.tosc(500)))/20)/3, 10);

sallenKey2ndOrderLPF_test = os.tosc(330) : ve.sallenKey2ndOrderLPF(0.3, 0.8);
sallenKey2ndOrderLPF_slider_test = os.tosc(330)
  : ve.sallenKey2ndOrderLPF(
      hslider("sallenKey2ndOrderLPF:normFreq", 0.3, 0, 1, 0.001),
      hslider("sallenKey2ndOrderLPF:Q", 0.8, 0.1, 10, 0.1)
    );

sallenKey2ndOrderBPF_test = os.tosc(330) : ve.sallenKey2ndOrderBPF(0.3, 1.5);
sallenKey2ndOrderBPF_slider_test = os.tosc(330)
  : ve.sallenKey2ndOrderBPF(
      hslider("sallenKey2ndOrderBPF:normFreq", 0.3, 0, 1, 0.001),
      hslider("sallenKey2ndOrderBPF:Q", 1.5, 0.1, 10, 0.1)
    );

sallenKey2ndOrderHPF_test = os.tosc(330) : ve.sallenKey2ndOrderHPF(0.3, 0.8);
sallenKey2ndOrderHPF_slider_test = os.tosc(330)
  : ve.sallenKey2ndOrderHPF(
      hslider("sallenKey2ndOrderHPF:normFreq", 0.3, 0, 1, 0.001),
      hslider("sallenKey2ndOrderHPF:Q", 0.8, 0.1, 10, 0.1)
    );

biquad_test = os.tosc(440)
  : ve.biquad(0.5, 0.3, 0.2, -0.3, 0.2);

lowpass2Matched_test = os.tosc(440) : ve.lowpass2Matched(1000, 0.707);
lowpass2Matched_slider_test = os.tosc(440)
  : ve.lowpass2Matched(
      hslider("lowpass2Matched:CF", 1000, 50, 5000, 1),
      hslider("lowpass2Matched:Q", 0.707, 0.1, 5, 0.01)
    );
lowpass2Matched_modulated_test = no.noise : ve.lowpass2Matched(20*pow(250, tri), 5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lowpass2Matched_low_test = no.noise : ve.lowpass2Matched(50, 10);

highpass2Matched_test = os.tosc(440) : ve.highpass2Matched(500, 0.707);
highpass2Matched_slider_test = os.tosc(440)
  : ve.highpass2Matched(
      hslider("highpass2Matched:CF", 500, 50, 5000, 1),
      hslider("highpass2Matched:Q", 0.707, 0.1, 5, 0.01)
    );
highpass2Matched_modulated_test = no.noise : ve.highpass2Matched(20*pow(250, tri), 5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highpass2Matched_low_test = no.noise : ve.highpass2Matched(50, 10);

bandpass2Matched_test = os.tosc(440) : ve.bandpass2Matched(1200, 2.0);
bandpass2Matched_slider_test = os.tosc(440)
  : ve.bandpass2Matched(
      hslider("bandpass2Matched:CF", 1200, 50, 5000, 1),
      hslider("bandpass2Matched:Q", 2.0, 0.1, 10, 0.01)
    );
bandpass2Matched_modulated_test = no.noise : ve.bandpass2Matched(20*pow(250, tri), 5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
bandpass2Matched_low_test = no.noise : ve.bandpass2Matched(50, 10);

peaking2Matched_test = os.tosc(440) : ve.peaking2Matched(1.5, 1000, 2.0);
peaking2Matched_slider_test = os.tosc(440)
  : ve.peaking2Matched(
      hslider("peaking2Matched:G", 1.5, 0.1, 4, 0.01),
      hslider("peaking2Matched:CF", 1000, 50, 5000, 1),
      hslider("peaking2Matched:Q", 2.0, 0.1, 10, 0.01)
    );
peaking2Matched_modulated_test = no.noise : ve.peaking2Matched(2, 20*pow(250, tri), 5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
peaking2Matched_low_test = no.noise : ve.peaking2Matched(4, 50, 10);

lowshelf2Matched_test = os.tosc(330) : ve.lowshelf2Matched(1.5, 500);
lowshelf2Matched_slider_test = os.tosc(330)
  : ve.lowshelf2Matched(
      hslider("lowshelf2Matched:G", 1.5, 0.5, 4, 0.01),
      hslider("lowshelf2Matched:CF", 500, 50, 5000, 1)
    );
lowshelf2Matched_modulated_test = no.noise : ve.lowshelf2Matched(0.25*pow(16, tri), 1000) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lowshelf2Matched_low_test = no.noise : ve.lowshelf2Matched(4, 20);
lowshelf2Matched_unity_test = no.noise : ve.lowshelf2Matched(1, 500);

highshelf2Matched_test = os.tosc(330) : ve.highshelf2Matched(1.5, 1500);
highshelf2Matched_slider_test = os.tosc(330)
  : ve.highshelf2Matched(
      hslider("highshelf2Matched:G", 1.5, 0.5, 4, 0.01),
      hslider("highshelf2Matched:CF", 1500, 50, 10000, 1)
    );
highshelf2Matched_modulated_test = no.noise : ve.highshelf2Matched(0.25*pow(16, tri), 1000) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highshelf2Matched_low_test = no.noise : ve.highshelf2Matched(0.25, 20);
highshelf2Matched_unity_test = no.noise : ve.highshelf2Matched(1, 500);

wah4_test = os.tosc(220) : ve.wah4(800);
wah4_slider_test = os.tosc(220)
  : ve.wah4(
      hslider("wah4:freq", 800, 200, 2000, 1)
    );
wah4_modulated_test = no.noise : ve.wah4(200*pow(10, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };

autowah_test = os.tosc(220) : ve.autowah(0.7);
autowah_slider_test = os.tosc(220)
  : ve.autowah(
      hslider("autowah:level", 0.7, 0, 1, 0.01)
    );
autowah_hot_test = 4*no.noise : ve.autowah(1);

crybaby_test = os.tosc(220) : ve.crybaby(0.3);
crybaby_slider_test = os.tosc(220)
  : ve.crybaby(
      hslider("crybaby:wah", 0.3, 0, 1, 0.01)
    );
crybaby_modulated_test = no.noise : ve.crybaby(tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
crybaby_jump_test = no.noise : ve.crybaby(sq) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
crybaby_noise_test = no.noise : ve.crybaby(0);
crybaby_clamp_test = no.noise <: ve.crybaby(-1), ve.crybaby(3);

vocoder_test = (no.noise, os.tosc(220)) : ve.vocoder(8, 0.01, 0.1, 1.0);
vocoder_slider_test = (no.noise, os.tosc(220))
  : ve.vocoder(
      8,
      hslider("vocoder:att", 0.01, 0.001, 0.1, 0.001),
      hslider("vocoder:rel", 0.1, 0.01, 0.5, 0.01),
      hslider("vocoder:BWRatio", 1.0, 0.5, 1.5, 0.01)
    );

klonCentaur_test = os.tosc(330) : ve.klonCentaur(0.5, 0.5, 0.5);
klonCentaur_slider_test = os.tosc(330)
   : ve.klonCentaur(
       hslider("klonCentaur:gain", 0.5, 0, 1, 0.01),
       hslider("klonCentaur:treble", 0.5, 0, 1, 0.01),
       hslider("klonCentaur:level", 0.5, 0, 1, 0.01)
     );
klonCentaur_modulated_test = 0.5*no.noise : ve.klonCentaur(0.1 + 0.9*tri, 0.5, 0.5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
klonCentaur_jump_test = 0.5*no.noise : ve.klonCentaur(0.1 + 0.9*sq, 0.5, 0.5) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };

klonCentaur_hot_test = os.tosc(110)*0.5 : ve.klonCentaur(1, 0, 1);
