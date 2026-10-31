// A two-output recursion whose first output is masked and whose second is an
// unbounded counter. The table reads the second: not proven. Pins that the
// range of an output is that of its own body in the group.
loop = (\(a, b).((a + 1) & 15, b + 1)) ~ (_, _);
process = rdtable(16, 1.0, loop : (!, _));
