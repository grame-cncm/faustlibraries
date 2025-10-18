//----------------------------------------------------------------------------
// mi_tests.dsp
// Tests for mass-interaction helper functions.
//----------------------------------------------------------------------------

mi = library("mi.lib");
ma = library("maths.lib");
os = library("oscillators.lib");

initState_test = button("impulse") : mi.initState(1.0);

mass_test = 0 : mi.mass(1.0, 0.0, 0.0, 0.0);

oscil_test = 0 : mi.oscil(1.0, 0.5, 0.1, 0.0, 0.0, 0.0);

ground_test = 0 : mi.ground(0.0);

posInput_test = 0, os.osc(1.0) : mi.posInput(0.0);

spring_test = mi.spring(10.0, 0.0, 0.0, 0.1, -0.1);

damper_test = mi.damper(0.5, 0.0, 0.0, 0.2, -0.2);

springDamper_test = mi.springDamper(5.0, 0.3, 0.0, 0.0, 0.1, -0.1);

nlSpringDamper2_test = mi.nlSpringDamper2(5.0, 1.0, 0.2, 0.0, 0.0, 0.1, -0.1);

nlSpringDamper3_test = mi.nlSpringDamper3(5.0, 0.5, 0.2, 0.0, 0.0, 0.1, -0.1);

nlSpringDamperClipped_test = mi.nlSpringDamperClipped(5.0, 0.5, 8.0, 0.2, 0.0, 0.0, 0.1, -0.1);

nlPluck_test = mi.nlPluck(5.0, 0.1, 0.2, 0.0, 0.0, 0.05, -0.05);

nlBow_test = mi.nlBow(0.5, 0.1, 1.0, 0.0, 0.0, 0.05, -0.05);

collision_test = mi.collision(5.0, 0.2, 0.01, 0.0, 0.0, 0.0, -0.02);

nlCollisionClipped_test = mi.nlCollisionClipped(3.0, 0.5, 6.0, 0.2, 0.01, 0.0, 0.0, 0.0, -0.02);
