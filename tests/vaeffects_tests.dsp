//----------------------------------------------------------------------------
// vaeffects_tests.dsp
// Tests for virtual analog effects library functions.
//----------------------------------------------------------------------------

ve = library("vaeffects.lib");
os = library("oscillators.lib");
no = library("noises.lib");

moog_vcf_test = os.osc(440)
  : ve.moog_vcf(
      hslider("moog_vcf:res", 0.5, 0, 1, 0.01),
      hslider("moog_vcf:freq", 1000, 50, 4000, 1)
    );

moog_vcf_2b_test = os.osc(330)
  : ve.moog_vcf_2b(
      hslider("moog_vcf_2b:res", 0.4, 0, 1, 0.01),
      hslider("moog_vcf_2b:freq", 1200, 50, 6000, 1)
    );

moog_vcf_2bn_test = os.osc(330)
  : ve.moog_vcf_2bn(
      hslider("moog_vcf_2bn:res", 0.4, 0, 1, 0.01),
      hslider("moog_vcf_2bn:freq", 1200, 50, 6000, 1)
    );

moogLadder_test = os.osc(220)
  : ve.moogLadder(
      hslider("moogLadder:normFreq", 0.3, 0, 1, 0.001),
      hslider("moogLadder:Q", 4, 0.7, 20, 0.1)
    );

lowpassLadder4_test = os.osc(110)
  : ve.lowpassLadder4(
      hslider("lowpassLadder4:k", 2.0, 0, 4, 0.1),
      hslider("lowpassLadder4:freq", 800, 50, 5000, 1)
    );

moogHalfLadder_test = os.osc(220)
  : ve.moogHalfLadder(
      hslider("moogHalfLadder:normFreq", 0.3, 0, 1, 0.001),
      hslider("moogHalfLadder:Q", 4, 0.7, 20, 0.1)
    );

diodeLadder_test = os.osc(220)
  : ve.diodeLadder(
      hslider("diodeLadder:normFreq", 0.4, 0, 1, 0.001),
      hslider("diodeLadder:Q", 4, 0.7, 20, 0.1)
    );

korg35LPF_test = os.osc(220)
  : ve.korg35LPF(
      hslider("korg35LPF:normFreq", 0.35, 0, 1, 0.001),
      hslider("korg35LPF:Q", 3.5, 0.7, 10, 0.1)
    );

korg35HPF_test = os.osc(330)
  : ve.korg35HPF(
      hslider("korg35HPF:normFreq", 0.4, 0, 1, 0.001),
      hslider("korg35HPF:Q", 3.5, 0.7, 10, 0.1)
    );

oberheim_test = os.osc(220)
  : ve.oberheim(
      hslider("oberheim:normFreq", 0.4, 0, 1, 0.001),
      hslider("oberheim:Q", 1.5, 0.5, 10, 0.1)
    );

oberheimBSF_test = os.osc(220)
  : ve.oberheimBSF(
      hslider("oberheimBSF:normFreq", 0.4, 0, 1, 0.001),
      hslider("oberheimBSF:Q", 1.5, 0.5, 10, 0.1)
    );

oberheimBPF_test = os.osc(220)
  : ve.oberheimBPF(
      hslider("oberheimBPF:normFreq", 0.4, 0, 1, 0.001),
      hslider("oberheimBPF:Q", 1.5, 0.5, 10, 0.1)
    );

oberheimHPF_test = os.osc(220)
  : ve.oberheimHPF(
      hslider("oberheimHPF:normFreq", 0.4, 0, 1, 0.001),
      hslider("oberheimHPF:Q", 1.5, 0.5, 10, 0.1)
    );

oberheimLPF_test = os.osc(220)
  : ve.oberheimLPF(
      hslider("oberheimLPF:normFreq", 0.4, 0, 1, 0.001),
      hslider("oberheimLPF:Q", 1.5, 0.5, 10, 0.1)
    );

sallenKeyOnePole_test = os.osc(440)
  : ve.sallenKeyOnePole(
      hslider("sallenKeyOnePole:normFreq", 0.25, 0, 1, 0.001)
    );

sallenKeyOnePoleLPF_test = os.osc(440)
  : ve.sallenKeyOnePoleLPF(
      hslider("sallenKeyOnePoleLPF:normFreq", 0.25, 0, 1, 0.001)
    );

sallenKeyOnePoleHPF_test = os.osc(440)
  : ve.sallenKeyOnePoleHPF(
      hslider("sallenKeyOnePoleHPF:normFreq", 0.25, 0, 1, 0.001)
    );

sallenKey2ndOrder_test = os.osc(330)
  : ve.sallenKey2ndOrder(
      hslider("sallenKey2ndOrder:normFreq", 0.3, 0, 1, 0.001),
      hslider("sallenKey2ndOrder:Q", 1.0, 0.1, 10, 0.1)
    );

sallenKey2ndOrderLPF_test = os.osc(330)
  : ve.sallenKey2ndOrderLPF(
      hslider("sallenKey2ndOrderLPF:normFreq", 0.3, 0, 1, 0.001),
      hslider("sallenKey2ndOrderLPF:Q", 0.8, 0.1, 10, 0.1)
    );

sallenKey2ndOrderBPF_test = os.osc(330)
  : ve.sallenKey2ndOrderBPF(
      hslider("sallenKey2ndOrderBPF:normFreq", 0.3, 0, 1, 0.001),
      hslider("sallenKey2ndOrderBPF:Q", 1.5, 0.1, 10, 0.1)
    );

sallenKey2ndOrderHPF_test = os.osc(330)
  : ve.sallenKey2ndOrderHPF(
      hslider("sallenKey2ndOrderHPF:normFreq", 0.3, 0, 1, 0.001),
      hslider("sallenKey2ndOrderHPF:Q", 0.8, 0.1, 10, 0.1)
    );

biquad_test = os.osc(440)
  : ve.biquad(0.5, 0.3, 0.2, -0.3, 0.2);

lowpass2Matched_test = os.osc(440)
  : ve.lowpass2Matched(
      hslider("lowpass2Matched:CF", 1000, 50, 5000, 1),
      hslider("lowpass2Matched:Q", 0.707, 0.1, 5, 0.01)
    );

highpass2Matched_test = os.osc(440)
  : ve.highpass2Matched(
      hslider("highpass2Matched:CF", 500, 50, 5000, 1),
      hslider("highpass2Matched:Q", 0.707, 0.1, 5, 0.01)
    );

bandpass2Matched_test = os.osc(440)
  : ve.bandpass2Matched(
      hslider("bandpass2Matched:CF", 1200, 50, 5000, 1),
      hslider("bandpass2Matched:Q", 2.0, 0.1, 10, 0.01)
    );

peaking2Matched_test = os.osc(440)
  : ve.peaking2Matched(
      hslider("peaking2Matched:G", 1.5, 0.1, 4, 0.01),
      hslider("peaking2Matched:CF", 1000, 50, 5000, 1),
      hslider("peaking2Matched:Q", 2.0, 0.1, 10, 0.01)
    );

lowshelf2Matched_test = os.osc(330)
  : ve.lowshelf2Matched(
      hslider("lowshelf2Matched:G", 1.5, 0.5, 4, 0.01),
      hslider("lowshelf2Matched:CF", 500, 50, 5000, 1)
    );

highshelf2Matched_test = os.osc(330)
  : ve.highshelf2Matched(
      hslider("highshelf2Matched:G", 1.5, 0.5, 4, 0.01),
      hslider("highshelf2Matched:CF", 1500, 50, 10000, 1)
    );

wah4_test = os.osc(220)
  : ve.wah4(
      hslider("wah4:freq", 800, 200, 2000, 1)
    );

autowah_test = os.osc(220)
  : ve.autowah(
      hslider("autowah:level", 0.7, 0, 1, 0.01)
    );

crybaby_test = os.osc(220)
  : ve.crybaby(
      hslider("crybaby:wah", 0.3, 0, 1, 0.01)
    );

vocoder_test = (no.noise, os.osc(220))
  : ve.vocoder(
      8,
      hslider("vocoder:att", 0.01, 0.001, 0.1, 0.001),
      hslider("vocoder:rel", 0.1, 0.01, 0.5, 0.01),
      hslider("vocoder:BWRatio", 1.0, 0.5, 1.5, 0.01)
    );

klonCentaur_test = os.osc(330)
   : ve.klonCentaur(
       hslider("klonCentaur:gain", 0.5, 0, 1, 0.01),
       hslider("klonCentaur:treble", 0.5, 0, 1, 0.01),
       hslider("klonCentaur:level", 0.5, 0, 1, 0.01)
     );