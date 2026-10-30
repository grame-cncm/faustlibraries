//----------------------------------------------------------------------------
// mi_tests.dsp
// Tests for mass-interaction helper functions.
//----------------------------------------------------------------------------

mi = library("mi.lib");
ma = library("maths.lib");
os = library("oscillators.lib");
ba = library("basics.lib");
no = library("noises.lib");

initState_test = button("impulse") : mi.initState(1.0);

mass_test = 0.1 : mi.mass(1.0, 0.0, 0.1, 0.0);

oscil_test = 0.1 : mi.oscil(1.0, 0.5, 0.1, 0.0, 0.1, 0.0);
oscil_slider_test = 0.1 : mi.oscil(hslider("oscil:m", 1.0, 0.1, 10, 0.01), hslider("oscil:k", 0.5, 0, 2, 0.001), hslider("oscil:z", 0.1, 0, 1, 0.001), 0.0, 0.1, 0.0);
oscil_modulated_test = 0.1*ba.pulse(P) : mi.oscil(1.0, 0.05 + 0.45*tri, 0.02, 0.0, 0.0, 0.0) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };

ground_test = 0.1 : mi.ground(0.1);

posInput_test = 0, os.tosc(1.0) : mi.posInput(0.0);

spring_test = mi.spring(10.0, 0.0, 0.0, 0.1, -0.1);

damper_test = 0.2*os.tosc(220), -0.2*os.tosc(330) : mi.damper(0.5, 0.0, 0.0);

springDamper_test = 0.1*os.tosc(220), -0.1*os.tosc(330) : mi.springDamper(5.0, 0.3, 0.0, 0.0);
springDamper_slider_test = 0.1*os.tosc(220), -0.1*os.tosc(330) : mi.springDamper(hslider("springDamper:k", 5.0, 0, 20, 0.01), hslider("springDamper:z", 0.3, 0, 2, 0.01), 0.0, 0.0);
springDamper_modulated_test = mi.springDamper(1 + 9*tri, 0.3, 0.0, 0.0, 0.1, -0.1) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };

nlSpringDamper2_test = 0.1*os.tosc(220), -0.1*os.tosc(330) : mi.nlSpringDamper2(5.0, 1.0, 0.2, 0.0, 0.0);

nlSpringDamper3_test = 0.1*os.tosc(220), -0.1*os.tosc(330) : mi.nlSpringDamper3(5.0, 0.5, 0.2, 0.0, 0.0);

nlSpringDamperClipped_test = 2*os.tosc(220), -2*os.tosc(330) : mi.nlSpringDamperClipped(5.0, 0.5, 8.0, 0.2, 0.0, 0.0);

nlPluck_test = (mi.nlPluck(5.0, 0.4, 0.2, 0.2, -0.2, 0.3, -0.3)), os.tosc(110) * 0.001;
nlPluck_moving_test = mi.nlPluck(5.0, 0.4, 0.2, 0.2, -0.2, 0.6*os.tosc(110), 0.6*os.tosc(170));

nlBow_test = no.multinoise(2) : *(0.1), *(0.05) : mi.nlBow(0.5, 0.1, 1.0, 0.0, 0.0);

collision_test = 0.02*os.tosc(220), -0.02*os.tosc(330) : mi.collision(5.0, 0.2, 0.01, 0.0, 0.0);

nlCollisionClipped_test = 2*os.tosc(220), -2*os.tosc(330) : mi.nlCollisionClipped(3.0, 0.5, 6.0, 0.2, 0.01, 0.0, 0.0);
