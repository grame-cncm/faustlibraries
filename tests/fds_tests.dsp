//----------------------------------------------------------------------------
// fds_tests.dsp
// Tests for finite difference schemes helpers.
//----------------------------------------------------------------------------

fd = library("fds.lib");
si = library("signals.lib");
os = library("oscillators.lib");

scheme1D = 0, 0;
model1D_test = si.bus(2)
  : fd.model1D(2, 0, 0, scheme1D)
  : si.bus(2);

scheme2D = 0, 0, 0, 0;
model2D_test = si.bus(4)
  : fd.model2D(2, 2, 0, 0, scheme2D)
  : si.bus(4);

stairsInterp1D_test = si.bus(4)
  : fd.stairsInterp1D(4, 1);

stairsInterp2D_test = si.bus(4)
  : fd.stairsInterp2D(2, 2, 1, 0);

linInterp1D_test = si.bus(4)
  : fd.linInterp1D(4, 1.25);

linInterp2D_test = si.bus(4)
  : fd.linInterp2D(2, 2, 0.6, 1.2);

stairsInterp1DOut_test = si.bus(4)
  : fd.stairsInterp1DOut(4, 2);

stairsInterp2DOut_test = si.bus(4)
  : fd.stairsInterp2DOut(2, 2, 1, 0);

linInterp1DOut_test = si.bus(4)
  : fd.linInterp1DOut(4, 1.5);

linInterp2DOut_test = si.bus(4)
  : fd.linInterp2DOut(2, 2, 0.6, 1.2);

route1D_test = par(i,3,0)
  : fd.route1D(1, 0, 0)
  : si.bus(3);

route2D_test = par(i,3,0)
  : fd.route2D(1, 1, 0, 0)
  : si.bus(3);

schemePoint_test = par(i,3,0)
  : fd.schemePoint(0, 0, 1);

buildScheme1D_test = par(i,3,0)
  : fd.buildScheme1D(1, 0, 0);

buildScheme2D_test = par(i,3,0)
  : fd.buildScheme2D(1, 1, 0, 0);

hammer_test = os.osc(5)
  : fd.hammer(
      0.1,
      1000,
      0.01,
      1e5,
      2.0,
      1.0/48000,
      0.001,
      button("hammer:trigger")
    );

bow_test = os.osc(5)
  : fd.bow(0.05, 2.0, 1.0/48000, 0.1);
