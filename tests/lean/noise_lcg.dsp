// no.noise — the LCG recursion x = 1103515245*x' + 12345 at the heart of
// noises.lib. The generator is only bounded by wrapping int32 semantics,
// which the certified fragment deliberately does not model: the recursion
// is refused ("not recognised"), and that refusal is what this fixture
// pins — if the analysers ever start reading int recursions, the verdict
// flip will surface here.
no = library("noises.lib");
process = no.noise;
