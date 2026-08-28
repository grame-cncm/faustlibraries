// ba.time — the sample counter (+(1) ~ _). Its pole sits exactly on the
// unit circle, and the Jury criterion is strict: an unbounded ramp is not
// certified stable. Pins the strictness of the boundary case on real code.
ba = library("basics.lib");
process = ba.time;
