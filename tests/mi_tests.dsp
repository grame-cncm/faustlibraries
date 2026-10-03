//----------------------------------------------------------------------------
// mi_tests.dsp
// Tests for mass-interaction helper functions.
//----------------------------------------------------------------------------

mi = library("mi.lib");
ma = library("maths.lib");
os = library("oscillators.lib");
ba = library("basics.lib");

initState_test = button("impulse") : mi.initState(1.0);

mass_test = 0.1 : mi.mass(1.0, 0.0, 0.1, 0.0);

oscil_test = 0.1 : mi.oscil(1.0, 0.5, 0.1, 0.0, 0.1, 0.0);
oscil_slider_test = 0.1 : mi.oscil(hslider("oscil:m", 1.0, 0.1, 10, 0.01), hslider("oscil:k", 0.5, 0, 2, 0.001), hslider("oscil:z", 0.1, 0, 1, 0.001), 0.0, 0.1, 0.0);
oscil_modulated_test = 0.1*ba.pulse(P) : mi.oscil(1.0, 0.05 + 0.45*tri, 0.02, 0.0, 0.0, 0.0) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };

ground_test = 0.1 : mi.ground(0.1);

posInput_test = 0, os.tosc(1.0) : mi.posInput(0.0);

spring_test = mi.spring(10.0, 0.0, 0.0, 0.1, -0.1);

damper_test = mi.damper(0.5, 0.0, 0.0, 0.2, -0.2);

springDamper_test = mi.springDamper(5.0, 0.3, 0.0, 0.0, 0.1, -0.1);
springDamper_slider_test = mi.springDamper(hslider("springDamper:k", 5.0, 0, 20, 0.01), hslider("springDamper:z", 0.3, 0, 2, 0.01), 0.0, 0.0, 0.1, -0.1);
springDamper_modulated_test = mi.springDamper(1 + 9*tri, 0.3, 0.0, 0.0, 0.1, -0.1) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };

nlSpringDamper2_test = mi.nlSpringDamper2(5.0, 1.0, 0.2, 0.0, 0.0, 0.1, -0.1);

nlSpringDamper3_test = mi.nlSpringDamper3(5.0, 0.5, 0.2, 0.0, 0.0, 0.1, -0.1);

nlSpringDamperClipped_test = mi.nlSpringDamperClipped(5.0, 0.5, 8.0, 0.2, 0.0, 0.0, 0.1, -0.1);

nlPluck_test = (mi.nlPluck(5.0, 0.4, 0.2, 0.2, -0.2, 0.3, -0.3)), os.tosc(110) * 0.001;

nlBow_test = mi.nlBow(0.5, 0.1, 1.0, 0.0, 0.0, 0.05, -0.05);

collision_test = mi.collision(5.0, 0.2, 0.01, 0.0, 0.0, 0.0, -0.02);

nlCollisionClipped_test = mi.nlCollisionClipped(3.0, 0.5, 6.0, 0.2, 0.01, 0.0, 0.0, 0.0, -0.02);
