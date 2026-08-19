"""Phoneme-to-trajectory sequencer for the Pink Trombone Faust port.

Compiles an ARPAbet-ish phoneme string into per-sample parameter trajectories for
`dm.pink_trombone_demo` (rendered with DawDreamer) — tongue, two constriction buses, velum,
tenseness and pitch. The tract's own `moveTowards` dynamics (15-30 cm/s) provide
the coarticulation smoothing, as in the original.

Vowel tongue positions were calibrated empirically (2026-08-19): grid sweep of
(tongueIndex, tongueDiameter) [x lip constriction for rounded vowels] rendered
through the actual engine at pitch ~110 Hz, F1/F2 measured by LPC (order 12 at
11 kHz), matched to Peterson & Barney-style male targets in log-frequency
(F2 weight 0.6). Residuals < 0.15 log units for all vowels ([iy] 0.11, [uw] 0.05).

Consonant places follow the tract geometry (lips 39-43, tip ~32-36, velar ~20-24).
Voicelessness = tenseness -> 0.05 (lax, quiet pulse; loudness = tenseness^0.25) PLUS
the voice gate off during voiceless stop closures — tenseness alone leaves a
half-amplitude pulse that hums through any open velum. The velum itself closes at
only ~1.5/s (engine-faithful), so nasals followed by stops close it early, like
real [nk]/[mp] sequences do.

Usage:
    python3.11 speak.py "HH AH . L OW | W ER L D" out.wav [semitones]
    python3.11 speak.py --demo            # render demo phrases into listening/

Tokens: phonemes below, '.' = syllable boundary (accent bump), '|' = word gap.
Two constriction buses: bus 1 = primary articulator, bus 2 = lip rounding of the
neighbouring vowel or the second member of a cluster (overlapping transitions).
"""
import sys, os
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fh  # noqa: E402  (DawDreamer helper; defines LIBS/render)
import dawdreamer as dd  # noqa: E402

SR = 44100
LIPS = 41.0          # bilabial place
LABIODENTAL = 40.3
DENTAL = 36.0
ALVEOLAR = 34.0
POSTALV = 32.5
VELAR = 22.0

# ---------------------------------------------------------------------------
# Phoneme table.
# type: V vowel, D diphthong, S stop, F fricative, N nasal, A approximant, H aspirate
# tongue: (index, diameter); lip: rounding diameter on bus 2 (None = unrounded)
# cons: (index, diameter) constriction on bus 1; voiced: pulse on during segment
# dur: default duration in seconds
# ---------------------------------------------------------------------------
P = {
    # --- vowels (calibrated; see module docstring) ---
    'IY': dict(t='V', tongue=(29.0, 2.29), lip=None, dur=0.16),
    'IH': dict(t='V', tongue=(25.9, 2.53), lip=None, dur=0.12),
    'EH': dict(t='V', tongue=(25.9, 3.26), lip=None, dur=0.14),
    'AE': dict(t='V', tongue=(22.8, 3.50), lip=None, dur=0.18),
    'AA': dict(t='V', tongue=(15.1, 2.29), lip=None, dur=0.18),
    'AH': dict(t='V', tongue=(18.2, 2.29), lip=None, dur=0.12),
    'AO': dict(t='V', tongue=(17.0, 2.05), lip=1.4, dur=0.18),
    'UH': dict(t='V', tongue=(19.7, 2.05), lip=1.4, dur=0.12),
    'UW': dict(t='V', tongue=(23.0, 2.05), lip=0.9, dur=0.16),
    'ER': dict(t='V', tongue=(21.3, 2.29), lip=None, cons=(28.0, 1.2), dur=0.16),  # rhotic: R-constriction
    # --- diphthongs: glide from `tongue` to `tongue2` (and lip to lip2) ---
    'EY': dict(t='D', tongue=(25.9, 3.26), tongue2=(29.0, 2.29), lip=None, lip2=None, dur=0.20),
    'AY': dict(t='D', tongue=(15.1, 2.29), tongue2=(29.0, 2.29), lip=None, lip2=None, dur=0.22),
    'OY': dict(t='D', tongue=(17.0, 2.05), tongue2=(29.0, 2.29), lip=1.4, lip2=None, dur=0.22),
    'AW': dict(t='D', tongue=(15.1, 2.29), tongue2=(23.0, 2.05), lip=None, lip2=0.9, dur=0.22),
    'OW': dict(t='D', tongue=(17.0, 2.29), tongue2=(23.0, 2.05), lip=1.1, lip2=0.9, dur=0.20),
    # --- stops: closure then release (transient + aspiration for voiceless) ---
    'P': dict(t='S', cons=(LIPS, 0.0), voiced=False, dur=0.08),
    'B': dict(t='S', cons=(LIPS, 0.0), voiced=True, dur=0.07),
    'T': dict(t='S', cons=(ALVEOLAR, 0.0), voiced=False, dur=0.08),
    'D': dict(t='S', cons=(ALVEOLAR, 0.0), voiced=True, dur=0.07),
    'K': dict(t='S', cons=(VELAR, 0.0), voiced=False, dur=0.09),
    'G': dict(t='S', cons=(VELAR, 0.0), voiced=True, dur=0.08),
    # --- fricatives ---
    'F': dict(t='F', cons=(LABIODENTAL, 0.40), voiced=False, dur=0.13),
    'V': dict(t='F', cons=(LABIODENTAL, 0.45), voiced=True, dur=0.09),
    'TH': dict(t='F', cons=(DENTAL, 0.50), voiced=False, dur=0.12),
    'DH': dict(t='F', cons=(DENTAL, 0.55), voiced=True, dur=0.07),
    'S': dict(t='F', cons=(34.5, 0.45), voiced=False, dur=0.14),
    'Z': dict(t='F', cons=(34.5, 0.50), voiced=True, dur=0.10),
    'SH': dict(t='F', cons=(POSTALV, 0.55), voiced=False, lip=1.4, dur=0.14),
    'ZH': dict(t='F', cons=(POSTALV, 0.60), voiced=True, lip=1.4, dur=0.10),
    # --- affricates: closure segment auto-inserted before the fricative part ---
    'CH': dict(t='F', cons=(POSTALV, 0.50), voiced=False, lip=1.4, dur=0.10, closure=(ALVEOLAR, 0.0, 0.06)),
    'JH': dict(t='F', cons=(POSTALV, 0.55), voiced=True, lip=1.4, dur=0.08, closure=(ALVEOLAR, 0.0, 0.05)),
    # --- nasals: oral closure + velum open ---
    'M': dict(t='N', cons=(LIPS, 0.0), dur=0.10),
    'N': dict(t='N', cons=(ALVEOLAR, 0.0), dur=0.09),
    'NG': dict(t='N', cons=(VELAR, 0.0), dur=0.10),
    # --- approximants (no laterals/trills in a 1-D tract: L and R are approximations) ---
    'W': dict(t='A', tongue=(23.0, 2.05), cons=(LIPS, 0.7), dur=0.09),
    'Y': dict(t='A', tongue=(29.0, 2.29), cons=None, dur=0.08),
    'L': dict(t='A', tongue=(21.3, 2.6), cons=(ALVEOLAR, 0.60), dur=0.06),
    'R': dict(t='A', tongue=(21.3, 2.29), cons=(28.0, 1.2), lip=1.4, dur=0.09),
    # --- aspirate: breath through the following vowel's shape ---
    'HH': dict(t='H', dur=0.09),
}

NEUTRAL_TONGUE = (18.2, 2.29)   # AH-ish rest position
TENSE_V = 0.62                  # vowel tenseness
TENSE_VOICED_C = 0.45           # voiced consonant tenseness
TENSE_OFF = 0.05                # voiceless: pulse off, aspiration on
REL_ASP = 0.045                 # voiceless stop aspiration (VOT) seconds


def compile_phonemes(tokens, semitone_base=5.0):
    """tokens: list of phoneme strings / '.' / '|'. Returns dict of automation arrays."""
    segs = []  # (dur, dict of targets)

    def find_next_vowel(i):
        for j in range(i, len(tokens)):
            if tokens[j] in P and P[tokens[j]]['t'] in 'VD':
                return P[tokens[j]]
        return None

    def seg(dur, tongue=None, lip=None, c1=None, nasal=0, tense=TENSE_V, accent=0.0, voice=1):
        segs.append(dict(dur=dur, tongue=tongue or NEUTRAL_TONGUE, lip=lip,
                         c1=c1, nasal=nasal, tense=tense, accent=accent, voice=voice))

    seg(0.10, tense=TENSE_OFF, voice=0)  # lead-in (unvoiced: intensity ramps in at the first phoneme)
    accent = 0.0
    for i, tok in enumerate(tokens):
        if tok == '.':
            accent = 1.0
            continue
        if tok == '|':
            if segs and segs[-1]['tense'] > TENSE_OFF:
                seg(0.06, tense=0.30)          # legato dip between voiced words
            else:
                seg(0.06, tense=TENSE_OFF, voice=0)  # true gap after voiceless material
            accent = 1.0
            continue
        p = P[tok]
        t = p['t']
        nv = find_next_vowel(i + 1) or {'tongue': NEUTRAL_TONGUE, 'lip': None}
        if t == 'V':
            seg(p['dur'] * (1.25 if accent else 1.0), p['tongue'], p.get('lip'),
                c1=p.get('cons'), tense=TENSE_V, accent=accent)
        elif t == 'D':
            seg(p['dur'] * 0.55, p['tongue'], p.get('lip'), tense=TENSE_V, accent=accent)
            seg(p['dur'] * 0.45, p['tongue2'], p.get('lip2'), tense=TENSE_V)
        elif t == 'S':
            tense = TENSE_VOICED_C if p['voiced'] else TENSE_OFF
            seg(p['dur'], nv['tongue'], nv.get('lip'), c1=p['cons'], tense=tense,
                voice=1 if p['voiced'] else 0)
            if not p['voiced']:
                # release + VOT: keep a loose constriction at the place so the
                # aspiration is place-coloured ([ph] vs [th] vs [kh])
                seg(REL_ASP, nv['tongue'], nv.get('lip'), c1=(p['cons'][0], 0.38), tense=TENSE_OFF)
            elif i + 1 >= len(tokens) or tokens[i + 1] in ('|',):
                # word/utterance-final voiced stop: audible release
                seg(0.03, nv['tongue'], nv.get('lip'), tense=TENSE_VOICED_C)
        elif t == 'F':
            if 'closure' in p:  # affricate: stop closure first
                ci, cd, cdur = p['closure']
                seg(cdur, nv['tongue'], p.get('lip'), c1=(ci, cd),
                    tense=TENSE_VOICED_C if p['voiced'] else TENSE_OFF)
            tense = TENSE_VOICED_C if p['voiced'] else TENSE_OFF
            seg(p['dur'], nv['tongue'], p.get('lip', nv.get('lip')), c1=p['cons'], tense=tense)
        elif t == 'N':
            nxt = next((tk for tk in tokens[i + 1:] if tk not in ('.',)), None)
            stop_next = nxt in P and P.get(nxt, {}).get('t') == 'S'
            if stop_next:  # [nk]/[mp]: velum starts closing mid-nasal
                seg(p['dur'] * 0.55, nv['tongue'], nv.get('lip'), c1=p['cons'], nasal=1, tense=TENSE_V)
                seg(p['dur'] * 0.45, nv['tongue'], nv.get('lip'), c1=p['cons'], nasal=0, tense=TENSE_V)
            else:
                seg(p['dur'], nv['tongue'], nv.get('lip'), c1=p['cons'], nasal=1, tense=TENSE_V)
        elif t == 'A':
            seg(p['dur'], p['tongue'], p.get('lip'), c1=p.get('cons'), tense=TENSE_V, accent=accent)
        elif t == 'H':
            seg(p['dur'], nv['tongue'], nv.get('lip'), tense=TENSE_OFF)
        accent = 0.0
    seg(0.15, tense=TENSE_OFF, voice=0)  # tail

    # phrase-final lengthening: stretch the last voiced open segment before each
    # unvoiced gap (word boundary or tail) so final vowels are not eaten by the
    # transition into them plus the intensity release
    for k in range(1, len(segs)):
        if segs[k]['voice'] == 0 and segs[k - 1]['voice'] == 1:
            for j in range(k - 1, -1, -1):
                if segs[j]['tense'] > TENSE_OFF and segs[j]['c1'] is None:
                    segs[j]['dur'] *= 1.5
                    break
                if segs[j]['voice'] == 0:
                    break

    # ---- lay out per-sample arrays ----
    total = sum(s['dur'] for s in segs)
    N = int(total * SR)
    A = {k: np.zeros(N) for k in
         ['tongue_index', 'tongue_diameter', 'c1_index', 'c1_diameter', 'c1_active',
          'c2_index', 'c2_diameter', 'c2_active', 'nasal', 'tenseness', 'pitch', 'voice']}
    pos = 0
    t_on = None
    for si, s in enumerate(segs):
        n = int(s['dur'] * SR)
        sl = slice(pos, min(pos + n, N))
        A['tongue_index'][sl] = s['tongue'][0]
        A['tongue_diameter'][sl] = s['tongue'][1]
        if s['c1'] is not None:
            A['c1_index'][sl], A['c1_diameter'][sl], A['c1_active'][sl] = s['c1'][0], s['c1'][1], 1
        else:  # keep last place while releasing (tract slews open at its own rate)
            A['c1_index'][sl] = A['c1_index'][pos - 1] if pos else ALVEOLAR
        if s['lip'] is not None:
            A['c2_index'][sl], A['c2_diameter'][sl], A['c2_active'][sl] = LIPS + 0.5, s['lip'], 1
        else:
            A['c2_index'][sl] = LIPS + 0.5
        A['nasal'][sl] = s['nasal']
        A['tenseness'][sl] = s['tense']
        A['voice'][sl] = s['voice']
        if s['tense'] > TENSE_OFF and t_on is None:
            t_on = pos
        # pitch: declination + accent bump, per segment start
        frac = pos / N
        A['pitch'][sl] = semitone_base + 1.5 - 3.0 * frac + 1.2 * s['accent']
        pos += n
    # smooth pitch & tenseness a little (the engine smooths frequency itself, but
    # tenseness is read per glottal period)
    k = int(0.030 * SR)
    kernel = np.hanning(2 * k + 1); kernel /= kernel.sum()
    for key in ['pitch', 'tenseness']:
        A[key] = np.convolve(np.pad(A[key], k, mode='edge'), kernel, 'valid')[:N]
    return A


def render(A, out_path):
    eng = dd.RenderEngine(SR, 512)
    f = eng.make_faust_processor('f')
    f.faust_libraries_paths = fh.LIBS
    f.set_dsp_string('dm = library("demos.lib");\nprocess = dm.pink_trombone_demo;')
    assert f.compile(), f.code
    G = '/Pink_Trombone/'
    m = {'tongue_index': 'tract/tongue_index', 'tongue_diameter': 'tract/tongue_diameter',
         'c1_index': 'constriction/index', 'c1_diameter': 'constriction/diameter',
         'c1_active': 'constriction/active',
         'c2_index': 'constriction_2/index', 'c2_diameter': 'constriction_2/diameter',
         'c2_active': 'constriction_2/active',
         'nasal': 'tract/nasal__velum_open_', 'tenseness': 'voicebox/tenseness',
         'pitch': 'voicebox/pitch', 'voice': 'voicebox/always_voice'}
    for k, addr in m.items():
        f.set_automation(G + addr, A[k].astype(np.float32))
    eng.load_graph([(f, [])])
    eng.render(len(A['pitch']) / SR)
    y = f.get_audio()[0]
    import soundfile as sf
    sf.write(out_path, y, SR)
    return y


DEMOS = {
    'speak_hello_world': "HH AH . L OW | W ER L D",
    'speak_pink_trombone': "P IH NG K | T R AH M . B OW N",
    'speak_ah_ee_oo': "AA . IY . UW",
    'speak_she_sells': "SH IY | S EH L Z | S IY . SH EH L Z",
}

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == '--demo':
        outdir = os.path.join(HERE, 'listening')
        os.makedirs(outdir, exist_ok=True)
        for name, phon in DEMOS.items():
            y = render(compile_phonemes(phon.split()), os.path.join(outdir, name + '.wav'))
            print(name, 'peak', float(np.abs(y).max()))
    else:
        phon, out = sys.argv[1], sys.argv[2]
        base = float(sys.argv[3]) if len(sys.argv) > 3 else 5.0
        y = render(compile_phonemes(phon.split(), base), out)
        print('rendered', out, 'peak', float(np.abs(y).max()))
