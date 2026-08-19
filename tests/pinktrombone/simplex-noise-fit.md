# The 1-D simplex drift noise

Pink Trombone uses `noise.simplex1(x) = simplex2(1.2 x, −0.7 x)` (josephg's
noisejs, one permutation table seeded from `Date.now()`) for slow random drift of
vibrato (rates 4.07, 2.15 and, with "pitch wobble", 0.98, 0.5), tenseness (0.46,
0.36) and aspiration level (1.99), always evaluated at `totalTime * rate` on the
*same* table.

## Current implementation (exact)

`no.simplex2 / no.simplex1 / no.simplex1_lf` in `noises.lib` are a port of the
same code (permutation table `p`, XOR seeding, 12 gradients, `70·Σ (0.5−r²)⁴ g·d`).
Validated against a Python port of noisejs: 1-D streams match to ~1e-5, 2-D with
negative coordinates to ~1e-5 (float32). `pt.simplexNoise(rate)` =
`no.simplex1_lf(pt.noiseSeed, rate)` with `noiseSeed = 12345` — the only
non-reproducible thing in the original is the seed, which was random per page load.

Faust gotcha met on the way: `^` is *power* in Faust, XOR is `xor`.

## Statistics (for reference; measured on the Python port, 8 seeds)

| statistic (per unit rate) | simplex1 |
|---|---|
| std | 0.44 |
| max abs | ~1.0 |
| median spectral frequency | 0.86 · rate |
| 90 % of power below | 1.67 · rate |

## Earlier substitute (removed)

The first version of the port used sample-and-hold white noise at 3·rate → two
one-pole lowpasses at 4·rate → one-pole highpass at 0.3·rate, fitted to the
statistics above (std 0.433–0.440, median 0.77–0.94·rate, max ≈1.2–1.3). It sounded
fine but had heavier tails (wider wobble excursions), a shallower spectral rolloff
(slightly grainier pitch wander) and none of the lattice structure. Note that
2nd-order `fi.lowpass` sections at sub-hertz cutoffs are unusable in float32 (std
collapses / NaN); one-pole sections are fine.
