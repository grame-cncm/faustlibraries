# Audit des bibliothèques Faust — qualité du code, documentation et couverture DSP

**Dépôt analysé** : `/Users/letz/Developpements/faustlibraries` (HEAD `ccc6030e`)
**Date** : 2026-08-15
**Compilateur de référence** : FAUST 2.87.4

---

## 1. Périmètre et méthode

L'audit porte sur les **43 fichiers `.lib` suivis par git à la racine** (les
sous-dossiers `dx7/`, `modalmodels/`, `embedded/`, `old/`, `unsupported/` ainsi que
les fichiers de travail non suivis sont exclus), soit **52 976 lignes** et
**~1 350 définitions de haut niveau**.

Mesures effectuées :

- extraction des définitions de haut niveau et des blocs de documentation
  (`//---…`(pfx.)nom`---`), avec prise en charge des en-têtes multi-fonctions
  (`` `(fi.)tf1`, `(fi.)tf2` et `(fi.)tf3` ``) et des motifs génériques (`` `(de.)fdelay[N]` ``) ;
- vérification de parsing de chaque bibliothèque via `faust -I .` ;
- exécution effective d'un sous-ensemble du harnais `make check` ;
- recensement thématique par recherche lexicale, puis vérification manuelle de
  chaque absence signalée (pour écarter les faux positifs — par exemple `hann`
  qui remontait uniquement dans le mot « c**hann**el »).

---

## 2. Vue d'ensemble

### Ce qui est solide

Ces bibliothèques sont, dans l'ensemble, d'un niveau nettement supérieur à ce que
l'on trouve dans la plupart des écosystèmes DSP open source :

1. **Les 43 bibliothèques parsent proprement** avec Faust 2.87.4, sans le moindre
   avertissement.
2. **Convention de documentation homogène et outillée** : 1 028 blocs de
   documentation structurés (`#### Usage` / `Where:` / `#### Test` /
   `#### References`), transformés en site MkDocs par `doc/scripts/faustlib2md.awk`,
   déployé automatiquement par GitHub Actions.
3. **Exemples exécutables adossés à la documentation** : 1 001 exemples
   `xxx_test = …` sont intégrés aux commentaires des `.lib`, et **993 d'entre eux
   (99,2 %) ont un test compilé correspondant** dans `tests/*.dsp`. C'est un
   dispositif remarquable, et remarquablement bien tenu à jour.
4. **Espace de noms très propre** : sur ~1 350 symboles, seulement **4 collisions**
   entre bibliothèques (`line`, `bow`, `inverse`, `biquad`), toutes bénignes car
   isolées par les préfixes d'environnement.
5. **Domaines de spécialité exceptionnels** : la modélisation physique
   (`physmodels.lib` 5 116 l., `mi.lib`, `fds.lib`, `wdmodels.lib` 3 331 l.), les
   filtres analogiques virtuels (`vaeffects.lib`, 30 topologies : Moog, diode,
   Korg35, Sallen-Key, Oberheim…), les non-linéarités anti-repliées (`aanl.lib`,
   ADAA d'ordre 1 et 2) et les réverbérations (15 algorithmes) n'ont pas
   d'équivalent ailleurs.
6. **Traçabilité juridique par symbole** : 416 symboles portent un
   `declare <nom> license "…"`, ce qui alimente `make doc-index-commercial`.

### Tableau de couverture documentaire

Couverture = définitions de haut niveau ayant un bloc de documentation
(alias `library(...)` exclus).

| Bibliothèque | Lignes | Défs | Blocs doc | Non doc. | Couv. |
|---|---:|---:|---:|---:|---:|
| `wdmodels.lib` | 3 331 | 47 | 48 | 0 | **100 %** |
| `fds.lib` / `mi.lib` / `quantizers.lib` | — | 17/15/15 | 17/15/15 | 0 | **100 %** |
| `linearalgebra.lib` / `spats.lib` / `hysteresis.lib` / `synths.lib` | — | 7/7/5/9 | idem | 0 | **100 %** |
| `aanl.lib` | 1 215 | 41 | 40 | 1 | 98 % |
| `hoa.lib` | 1 364 | 30 | 29 | 1 | 97 % |
| `filters.lib` | 4 829 | 126 | 116 | 5 | 96 % |
| `motion.lib` | 855 | 22 | 22 | 1 | 95 % |
| `demos.lib` | 2 906 | 48 | 44 | 3 | 94 % |
| `maths.lib` | 1 576 | 57 | 54 | 4 | 93 % |
| `envelopes.lib` | 822 | 15 | 14 | 1 | 93 % |
| `physmodels.lib` | 5 116 | 160 | 150 | 12 | 92 % |
| `basics.lib` | 3 742 | 98 | 90 | 9 | 91 % |
| `vaeffects.lib` | 2 179 | 34 | 32 | 3 | 91 % |
| `signals.lib` | 837 | 22 | 20 | 2 | 91 % |
| `compressors.lib` | 1 543 | 29 | 27 | 3 | 90 % |
| `oscillators.lib` | 2 715 | 83 | 78 | 9 | 89 % |
| `webaudio.lib` | 451 | 9 | 8 | 1 | 89 % |
| `reverbs.lib` | 1 291 | 14 | 15 | 2 | 86 % |
| `noises.lib` | 642 | 23 | 17 | 5 | 78 % |
| `misceffects.lib` | 1 330 | 34 | 25 | 9 | 74 % |
| `interpolators.lib` | 1 110 | 30 | 22 | 9 | 70 % |
| **`delays.lib`** | 565 | 28 | 8 | 12 | **57 %** |
| **`analyzers.lib`** | 1 339 | 57 | 29 | 28 | **51 %** |
| **`reducemaps.lib`** | 254 | 10 | 5 | 5 | **50 %** |
| **`debug.lib`** | 1 213 | 68 | 33 | 35 | **49 %** |
| **`soundfiles.lib`** | 270 | 9 | 3 | 6 | **33 %** |
| **`routes.lib`** | 545 | 38 | 10 | 28 | **26 %** |
| **`tubes.lib`** | 5 040 | 53 | 0 | 53 | **0 %** |
| **`instruments.lib`** | 264 | 17 | 0 | 17 | **0 %** |
| **`tonestacks.lib`** | 429 | 26 | 0 | 26 | **0 %** |
| **`maxmsp.lib`** | 237 | 13 | 0 | 13 | **0 %** |
| **`sf.lib`** | 54 | 28 | 0 | 28 | **0 %** |

---

## 3. Qualité de la documentation — défauts constatés

### 3.1 `analyzers.lib` : la moitié de l'API publique n'est pas documentée

C'est le déficit le plus dommageable, car il concerne des fonctions
authentiquement publiques et largement utilisées, pas des utilitaires internes :

```
spectral_level, mth_octave_spectral_level_default, mth_octave_analyzer_default,
mth_octave_analyzer3, mth_octave_analyzer5, mth_octave_analyzer6e,
octave_analyzer, third_octave_analyzer, half_octave_analyzer,
octave_filterbank, third_octave_filterbank, half_octave_filterbank,
peak_envelope, fftb, ifftb, rtocv, rtorv, rvtocv,
c_magsq, c_magdb, c_select_pos_freqs, c_bit_reverse_shuffle,
rfft_analyzer_c, rfft_analyzer_db, rfft_analyzer_magsq, rfft_spectral_level
```

Le sous-système FFT complet (`fftb`, `ifftb`, les conversions réel↔complexe
`rtocv`/`rtorv`/`rvtocv`, les analyseurs `rfft_*`) est ainsi **livré sans une
seule ligne d'explication**, alors que c'est précisément la partie que les
utilisateurs ne peuvent pas deviner : la représentation « N signaux parallèles
entrelacés (réel, imag) » n'est documentée nulle part.

### 3.2 Bibliothèques « standard » totalement absentes du site

`doc/docs/organization.md` déclare `tonestacks.lib` et `tubes.lib` comme faisant
partie des bibliothèques standard, en précisant qu'elles ne sont « pas documentées ».
Résultat : **`tubes.lib`, 5 040 lignes — la 2ᵉ plus grosse bibliothèque du dépôt —
n'a aucune documentation**, ni dans les sources, ni sur le site. Idem pour
`tonestacks.lib` (26 émulations de tone stacks d'amplis : Fender, Marshall, Vox,
Mesa, Soldano…), `instruments.lib` (17 primitives Faust-STK) et `maxmsp.lib`
(13 fonctions de compatibilité). Au total **9 bibliothèques n'ont pas de page**
dans `doc/docs/libs/`.

### 3.3 15 blocs de documentation ne contiennent **que** une section `#### Test`

Ces fonctions apparaissent dans le site généré sans description, sans usage et
sans paramètres — le lecteur voit un titre suivi d'un extrait de code :

```
filters.lib : lowpass0_highpass1, highpass_plus_lowpass, highpass_minus_lowpass,
              highpass_minus_lowpass_even, highpass_plus_lowpass_even, bandstop,
              low_shelf, low_shelf1, low_shelf1_l, lowshelf_other_freq,
              high_shelf, high_shelf1, high_shelf1_l, highshelf_other_freq,
              mth_octave_filterbank_default
```

Exemple intégral tel que publié pour `fi.lowpass0_highpass1` :

```faust
//-------------`(fi.)lowpass0_highpass1`--------------
//
// #### Test
// ```
// lowpass0_highpass1_test = src : fi.lowpass0_highpass1(0, 2, 1000);
// ```
//------------------------------
```

Le premier paramètre est un sélecteur passe-bas/passe-haut : impossible à deviner.
C'est une régression probable d'une passe automatisée d'ajout d'exemples.

### 3.4 28 blocs supplémentaires sans section `#### Usage`

Notamment les 9 fonctions inverses `aanl.lib` (`Rsqrt`, `Rlog`, `Rtan`, `Racos`,
`Rasin`, `Racosh`, `Rcosh`, `Rsinh`, `Ratanh`), `ba.bpf`, `ba.parallelOp`,
`de.fdelay[N]`, `fi.rev1`, `fi.rev2`, `fi.bandpass6e`, `fi.bandpass12e`,
`pf.phaser2_mono`, `pf.phaser2_stereo`, les 3 constantes de `platform.lib`.
Ce constat recoupe et étend `tests/parameter-doc-report.md` (qui n'en listait que 14).

### 3.5 `standardFunctions.md` est désynchronisé des sources

L'index « fonctions standard » est la porte d'entrée des débutants. Il est
maintenu à la main et a divergé :

- **129 fonctions** sont marquées `« X » is a standard Faust function` dans les sources ;
- **96** sont listées dans `doc/docs/standardFunctions.md` ;
- **42 sont marquées standard mais absentes de l'index**, dont toute la famille
  des compresseurs modernes (`co.FFcompressor_N_chan`, `co.FBcompressor_N_chan`,
  `co.FBFFcompressor_N_chan`, `co.RMS_FBFFcompressor_N_chan`,
  `co.RMS_FBcompressor_peak_limiter_N_chan`, `co.expander_N_chan`,
  `co.expanderSC_N_chan`, les 8 `*_compression_gain_*`), les 13 oscillateurs
  Casio phase-distortion (`os.CZsaw`, `os.CZsquare`, `os.CZpulse`…), les
  primitives complexes (`si.cbus`, `si.cmul`, `si.cconj`), `so.loop*`, `ho.rEncoder3D` ;
- **9 sont listées dans l'index sans être marquées dans les sources**
  (`fi.fir`, `fi.tf2`, `fi.allpass_fcomb`, `fi.fb_fcomb`, `ba.impulsify`,
  `ba.sec2samp`, `os.oscs`, `an.mth_octave_analyzer[N]`, `sy.popFilterPerc`).

Cette liste devrait être **générée** depuis les marqueurs source, pas maintenue en parallèle.

### 3.6 Métadonnées de licence non normalisées

Seuls **416 symboles sur ~1 350 (31 %)** portent une licence explicite, et les
chaînes utilisées ne sont pas normalisées — **16 orthographes pour ~8 licences réelles** :

| Licence réelle | Orthographes trouvées | Symboles |
|---|---|---|
| MIT | `MIT License` (49), `MIT` (52), `MIT license` (7) | 108 |
| STK-4.3 | `MIT-style STK-4.3 license` (213), `STK-4.3` (49) | 262 |
| GPLv3 | `GPLv3` (18), `GPL-3.0` (9), `GPLv3 license` (5) | 32 |
| AGPL | `AGPL-3.0-only` (1), `AGPL-3.0` (1) | 2 |
| LGPL | `LGPL` (2), `LGPLv2.1` (6), `LGPL v3.0 license` (2) | 10 |

Or `scripts/build_faust_doc_index.py --license-policy commercial-compatible`
classe par **appariement de chaînes**. Une variante orthographique non prévue
bascule un symbole du bon côté ou du mauvais côté du filtre commercial —
c'est-à-dire exactement le cas d'usage où une erreur a des conséquences
juridiques. Les 69 % de symboles sans licence explicite héritent implicitement de
l'en-tête de fichier, mais `filters.lib` avertit lui-même : *« Each function in
this library has its own license »*. L'héritage implicite n'y est donc pas sûr.

Les identifiants **SPDX** (`MIT`, `GPL-3.0-only`, `LGPL-2.1-or-later`) devraient
être imposés, avec validation en CI.

---

## 4. Qualité du code — défauts constatés

### 4.1 Conventions de nommage : partage à parts égales, incohérent y compris à l'intérieur d'un fichier

Sur les symboles de plus de 2 caractères : **367 en `snake_case`, 382 en `camelCase`**.
Ce n'est pas une transition en cours mais un état stable, et **17 bibliothèques
mélangent les deux en interne** :

| Bibliothèque | snake_case | camelCase |
|---|---:|---:|
| `physmodels.lib` | 10 | **127** |
| `filters.lib` | **50** | 9 |
| `demos.lib` | **45** | 2 |
| `analyzers.lib` | **42** | 4 |
| `basics.lib` | 8 | **33** |
| `oscillators.lib` | **26** | 16 |
| `wdmodels.lib` | 5 | **19** |
| `vaeffects.lib` | 3 | **17** |
| `interpolators.lib` | **16** | 3 |
| `misceffects.lib` | 9 | **14** |

Conséquence concrète : dans `basics.lib`, l'utilisateur doit retenir que c'est
`ba.sec2samp` mais `ba.sAndH`, `ba.countdown` mais `ba.downSample`. Dans
`vaeffects.lib`, `ve.moog_vcf` cohabite avec `ve.moogLadder`.

Faust ne permettant pas de renommer sans casser la compatibilité, la correction
réaliste est : (a) figer la convention par bibliothèque dans un guide de
contribution, (b) ajouter des alias documentés « deprecated » pour converger.

### 4.2 Code déprécié conservé sans échéance ni avertissement machine

Trois bibliothèques contiennent une section « Deprecated Functions » héritée de
`music.lib`, avec des tailles de délai codées en dur en échantillons — **et donc
faussement nommées** :

```faust
// delays.lib
delay1s(d)  = delay(65536,d);     // 65536 échantillons = 1,49 s à 44,1 kHz, 1,37 s à 48 kHz
delay43s(d) = delay(2097152,d);
```

Les noms `delay1s` … `delay43s` suggèrent une durée en secondes ; ce sont en
réalité des puissances de deux fixes, dont la durée réelle dépend de `ma.SR`.
Idem pour `basics.lib` (`time1s`…`time43s`, `millisec`) et
`misceffects.lib` (`echo1s`…`echo43s`). Ces 18 fonctions sont non documentées,
sans `declare … deprecated`, et restent exportées.

`compressors.lib` gère mieux le problème avec sa section « Original versions »,
qui explique le maintien pour compatibilité **et** pour disposer d'une variante
sous licence permissive.

### 4.3 `ba.downSample` : nom trompeur

```faust
downSample(freq) = sAndH(hold) with { hold = time%int(ma.SR/freq) == 0; };
```

C'est un **échantillonneur-bloqueur** sans filtre anti-repliement : il produit
volontairement du repliement (effet « lo-fi »), il ne réduit pas la fréquence
d'échantillonnage. La documentation ne le signale pas, et l'index le présente
comme « Down sample a signal ». Un utilisateur cherchant une décimation correcte
y sera envoyé à tort — d'autant qu'aucune vraie décimation n'existe dans le dépôt
(cf. §6.2).

### 4.4 Dette résiduelle

- 64 marqueurs `TODO`/`FIXME`/`XXX`/`HACK` répartis sur 15 bibliothèques
  (`physmodels.lib` 10, `demos.lib` 8, `filters.lib` 7).
- Coquille publiée dans la documentation : `filters.lib:189` — *« `dcblocker` is
  **as** standard Faust function »* (au lieu de « is a »).
- `debug.lib` (v0.3.1) expose 34 symboles `probe_*_impl` qui sont manifestement
  des détails d'implémentation, dans un espace de noms plat où rien ne les
  distingue de l'API publique.
- `routes.lib` : 28 symboles non documentés, soit l'intégralité de la machinerie
  du tri bitonique (`bitonicSorterNetwork`, `comparatorDirectionsIdx`…), dont
  `bitonicSort` et `bitonicSortIdx` qui sont, eux, l'API réellement destinée aux
  utilisateurs.

---

## 5. Infrastructure de test : le défaut le plus grave

Le dépôt possède un harnais de non-régression complet — **1 110 tests, ~50
fichiers, couvrant chaque bibliothèque** — et un `Makefile` avec `make reference`
/ `make check` / `make bench`. C'est un investissement considérable.

**Il ne peut structurellement détecter aucune régression.**

### 5.1 `floatdiff.py` renvoie toujours 0

```python
    if not diff_found:
        print(f"No differences within tolerance {tol}")
    else:
        print("Differences found.")     # ← aucun sys.exit(1)
```

`compare_files()` retourne `None` et `__main__` se termine normalement : le code
de sortie est **0 même quand des différences sont trouvées**.

### 5.2 Le `Makefile` avale le second niveau de détection

```make
	if ! $(FLOATDIFF) $(REFERENCE_DIR)/$*.ref $@ $(FLOAT_TOL); then \
		echo "[fail] output for $* differs from reference"; \
	fi                                   # ← pas de exit 1
```

Même si `floatdiff.py` était corrigé, la recette imprimerait `[fail]` et
retournerait 0. Et un échec de compilation est explicitement neutralisé :

```make
	if ! $(CXX) $(CXXFLAGS) …; then echo "[skip] build failed for $*"; exit 0; fi
```

### 5.3 Vérification empirique

```
$ make tests/output/samp2sec_test.out tests/output/dcblocker_test.out tests/output/zcr_test.out
…
Line 48000: file length mismatch
Differences found.
MAKE EXIT=0
```

```
samp2sec_test  floatdiff_exit=0  ref_lines=10000  out_lines=48000
dcblocker_test floatdiff_exit=0  ref_lines=10000  out_lines=48000
zcr_test       floatdiff_exit=0  ref_lines=10000  out_lines=48000
```

Trois tests échouent sur 48 000 lignes chacun ; `make` renvoie 0.

### 5.4 Les références « or » ne sont ni versionnées ni reproductibles

- `tests/reference/` contient 1 110 fichiers sur le disque et **0 fichier suivi
  par git**. Un clone neuf ne peut donc pas exécuter `make check` : tout doit être
  régénéré depuis le code courant, ce qui rend la référence tautologique.
- `make clean` fait `rm -rf $(REFERENCE_DIR)` : la seule copie des données de
  référence est détruite par la cible de nettoyage.
- Les références locales font 10 000 lignes alors que `NUM_SAMPLES ?= 48000` :
  elles ont été produites avec d'autres paramètres et sont périmées. Rien ne l'a
  signalé, précisément à cause de 5.1/5.2.

### 5.5 La CI ne teste rien

`.github/workflows/` ne contient qu'un seul workflow, `docs.yml`, qui construit et
déploie MkDocs. **Aucun job ne compile les bibliothèques ni n'exécute les tests.**
Une régression DSP peut être fusionnée sans aucun signal.

> **C'est le point à corriger en premier.** Le coût est faible (un `sys.exit(1)`,
> un `exit 1`, un workflow CI, et le versionnement des références produites avec
> des paramètres figés) et il conditionne la fiabilité de tout le reste.

---

## 6. Thématiques DSP importantes mal ou non couvertes

Chaque absence ci-dessous a été vérifiée manuellement dans les sources.

### P0 — Lacunes critiques

#### 6.1 Fenêtrage et traitement spectral par trames (STFT)

**Absent : Hann, Hamming, Blackman, Blackman-Harris, Kaiser, Tukey, Bartlett,
Nuttall, flat-top.** Aucune fonction de fenêtre dans les 43 bibliothèques.

`analyzers.lib` fournit une FFT (`an.fft(N)`, `an.ifft(N)`, `an.goertzel`), mais :

- elle opère sur **N signaux parallèles entièrement déroulés**, pas sur des trames ;
- il n'existe **ni découpage en trames, ni fenêtrage, ni recouvrement,
  ni overlap-add/overlap-save, ni gestion du hop size** ;
- cette représentation n'est documentée nulle part (cf. §3.1).

Conséquence : **le traitement spectral n'est pas praticable en Faust standard**.
Vocodeur de phase, débruitage spectral, gel spectral, morphing, cross-synthèse,
convolution rapide — tout en dépend. C'est la lacune la plus structurante du
dépôt.

*Note d'articulation avec `faust-rs` : le travail P3/P4 sur les domaines
d'horloge et `fft_framed(N)` (`porting/ondemand-vec-fad-interleave-synthesis-2026-07-07-fr.md`)
adresse précisément cette lacune côté compilateur. Une famille `an.window*`
serait un complément naturel, et utile indépendamment.*

#### 6.2 Sur-échantillonnage et traitement multi-débit

**Absent : `upsample`, `downsample` anti-replié, décimateurs, interpolateurs
polyphase, wrapper `oversample(N, f)`.**

C'est d'autant plus notable que l'en-tête de `aanl.lib` recommande explicitement
la pratique :

> *« effective if combined with low-factor oversampling »*

…sans fournir le moyen de la mettre en œuvre. La seule occurrence dans le code
est un commentaire de `vaeffects.lib` notant que le ChowCentaur original utilise
un sur-échantillonnage ×2 — que l'implémentation Faust n'a pas.

Tout traitement non linéaire de qualité (saturation, distorsion, écrêtage,
waveshaping, filtres à lampes) en dépend. `ba.downSample` ne répond pas au besoin
(cf. §4.3).

#### 6.3 Convolution rapide / partitionnée

`fi.conv(kv)` et `fi.convN(N,kv)` sont des **FIR en forme directe**, en O(N)
opérations par échantillon :

```faust
convN(N,kv) = sum(i,N, @(i)*ba.take(i+1,kv));
```

Pour une réponse impulsionnelle de salle typique (1 à 3 s, soit 48 000–144 000
coefficients), c'est inutilisable en temps réel. **Il n'existe ni convolution par
blocs, ni convolution partitionnée à latence nulle (Gardner), ni overlap-save.**

Conséquences : **pas de réverbération à convolution, pas d'émulation de baffle
par IR, pas de rendu binaural par HRIR** — trois usages parmi les plus demandés
en audio applicatif. Le dépôt propose 15 réverbérations algorithmiques, ce qui
rend le contraste d'autant plus visible.

#### 6.4 Conversion de fréquence d'échantillonnage

**Absent.** `interpolators.lib` (1 110 lignes : Lagrange, splines Catmull-Rom,
B-splines, interpolation cubique/cosinus) mentionne le rééchantillonnage dans son
en-tête mais n'expose aucun convertisseur : ni SRC à ratio arbitraire, ni filtre
polyphase, ni interpolation sinc fenêtrée. `ba.downSample` est un
échantillonneur-bloqueur. La lecture de fichier à vitesse variable
(`so.loop_speed`) ne fait aucun filtrage anti-repliement.

### P1 — Lacunes importantes

#### 6.5 Mesure de sonie normalisée

**Absent : LUFS, EBU R128 / ITU-R BS.1770, pondération K, gating absolu et
relatif (−70 LUFS / −10 LU), LRA, true-peak inter-échantillon (ISP, sur-échantillonné ×4).**

`compressors.lib` est l'une des bibliothèques les plus abouties (1 543 lignes,
compresseurs feed-forward/feedback, expandeurs, limiteurs à lookahead), et
`an.amp_follower_*` fournit des détecteurs RMS et crête. Mais rien ne permet de
mesurer la sonie **selon la norme** — or c'est une obligation réglementaire pour
toute diffusion broadcast ou streaming. Le contraste entre la maturité du
traitement dynamique et l'absence totale de mesure normalisée est frappant.

Contrairement à ce qu'on pourrait croire, **cette lacune n'est pas bloquée par
l'absence de sur-échantillonnage** (6.2) : l'interpolateur ×4 normalisé se ramène
à 4 phases FIR évaluées en parallèle, ce qui est strictement monorate. Voir §7.3.

#### 6.6 Dither et mise en forme du bruit

**Absent : dither TPDF/RPDF, mise en forme du bruit (noise shaping) plate ou
pondérée psychoacoustiquement, requantification.**

`noises.lib` fournit 23 générateurs (blanc, rose, brownien, velvet, gaussien,
multi-bruit) mais aucun dispositif de réduction de résolution. `ba.bitcrusher`
existe comme effet créatif, pas comme requantification correcte. Toute chaîne se
terminant en 16 bits en a besoin.

#### 6.7 Transposition et étirement temporel de qualité

La seule primitive est `ef.transpose(w, x, s, sig)` : deux lignes de retard à
fondu enchaîné. C'est l'algorithme historique — artefacts de peigne, effet de
« flutter » sur les transpositions marquées.

**Absents : vocodeur de phase, PSOLA/TD-PSOLA, verrouillage de phase
(identity/scaled phase locking), étirement temporel indépendant de la hauteur,
formant preservation.** `ef.doppler_shift` répond à un besoin différent.
`ve.vocoder` est un vocodeur à banc de filtres (effet), pas un vocodeur de phase.

#### 6.8 Détection de hauteur robuste

`an.pitchTracker(N, tau)` repose sur le **taux de passages par zéro** filtré
passe-bas — sensible au bruit, aux harmoniques dominantes et inutilisable sur
signal polyphonique ou riche.

**Absents : autocorrélation, YIN, différence moyenne d'amplitude (AMDF), MPM
(McLeod), estimation par produit spectral harmonique, suivi de f0 avec
confiance.** Nécessaire pour l'accordage, la correction de hauteur, la synthèse
pilotée par la voix, l'extraction de MIDI.

#### 6.9 Descripteurs pour l'analyse (MIR) et détection d'attaques

Le centroïde spectral n'existe que dans `debug.lib` (`probe_spectral_centroid_impl`,
non documenté, orienté débogage), et la détection d'attaques idem
(`probe_onset_impl`).

**Absents de l'API publique : flux spectral, roll-off, flatness (mesure de
Wiener), spread, skewness, kurtosis, MFCC, chroma, fonction de détection
d'attaques (HFC, complex domain, spectral difference), détection de tempo.**

Ces descripteurs conditionnent l'audio adaptatif, la segmentation, et la
classification embarquée.

#### 6.10 Rendu binaural / HRTF

**Absent.** `hoa.lib` (1 364 lignes) couvre l'ambisonie jusqu'à l'ordre 3 en 3D
avec encodeurs, décodeurs, rotations et optimisations (in-phase, max-rE), et
`spats.lib` fournit panner à puissance constante, WFS, SPCAP et
`ho.circularScaledVBAP` (VBAP circulaire 2D uniquement).

Mais il n'existe **aucun décodage binaural** : ni convolution HRIR, ni décodeur
ambisonique virtuel vers casque, ni modèle de tête sphérique, ni ITD/ILD
paramétrique. C'est aujourd'hui le mode d'écoute dominant du contenu spatialisé.

À la différence de la réverbération à convolution, **cette lacune ne dépend pas
de 6.3** : les HRIR font 128 à 256 coefficients, longueur à laquelle une
convolution FIR directe est parfaitement viable en monorate. Voir §7.3.

Le VBAP 3D (triplets de haut-parleurs) et le DBAP sont également absents.

#### 6.11 Filtrage adaptatif

`filters.lib` contient un filtre de **Kalman** (`fi.kalman`, `fi.kalmanEnv`).
**Absents : LMS, NLMS, moindres carrés récursifs (RLS), LMS en fréquence,
annulation d'écho acoustique, égalisation adaptative, réducteur de larsen
adaptatif.** `an.pitchTracker` et `an.adaptive*` font de l'analyse adaptative,
pas du filtrage adaptatif.

*Note : `faust-rs` couvre ce terrain via `rad`/`fad` et `optimizers.lib`
(LMS/FxLMS, notch adaptatif). Ces primitives ne sont pas disponibles dans Faust
amont, donc la lacune reste réelle pour les bibliothèques standard.*

#### 6.12 Conception de filtres FIR

`filters.lib` est très riche en IIR conçus analytiquement (Butterworth,
elliptiques Cauer, Linkwitz-Riley, égaliseurs paramétriques, bancs de filtres
en Mᵉ d'octave). Côté FIR : uniquement `fi.fir(bv)` qui **applique** des
coefficients fournis.

**Absents : conception par fenêtrage, Parks-McClellan/Remez, moindres carrés,
FIR à phase linéaire, transformée de Hilbert FIR, différenciateurs, filtres
demi-bande** (ces derniers étant la brique du sur-échantillonnage, cf. 6.2).
`fi.highpass_plus_lowpass` et consorts couvrent la reconstruction parfaite en
IIR uniquement.

**`fi.hilbert` n'existe pas non plus** : la documentation de `fi.pospass`
(`filters.lib:2931-2936`) en donne pourtant la définition complète dans un bloc
de code, mais le symbole n'est défini nulle part (`grep -rn '^hilbert' *.lib` ne
renvoie rien). Une ligne à écrire, déjà rédigée — cf. §7.2.

### P2 — Lacunes souhaitables

#### 6.13 Utilitaires de contrôle et séquencement

- **Limiteur de pente (slew rate)** : n'existe que comme sonde de débogage
  (`probe_slew_impl`), pas comme fonction publique.
- **Portamento / glide** : uniquement dans `demos.lib`, non réutilisable.
- **Séquenceur pas-à-pas, arpégiateur, horloge musicale** : totalement absents.
  `ba.beat`, `ba.tempo`, `ba.pulse` fournissent les briques temporelles, mais
  rien au-dessus.
- **Générateur d'enveloppe multi-segments arbitraire** : `envelopes.lib` propose
  ADSR/AR/ASR/exponentielles ; pas d'enveloppe à points de rupture pilotée par liste.

#### 6.14 Systèmes d'accord et microtonalité

`quantizers.lib` (v1.1.2) contient **15 gammes codées en dur** (ionien, dorien,
phrygien, lydien, mixolydien, éolien, locrien, pentatoniques, dodécaphonique,
diminué…), toutes en tempérament égal à 12 tons.

**Absents : N-EDO générique, intonation juste, tempéraments historiques
(Pythagore, mésotonique, Werckmeister), import de fichiers Scala `.scl`/`.kbm`,
fréquence de référence configurable, cents arbitraires.** Sujet demandé de façon
récurrente par la communauté de composition.

Signalons également la présence à la racine de `old-quantizers.lib` et
`new-quantizers.lib` (non suivis par git) à côté de `quantizers.lib` : la
transition semble inachevée.

#### 6.15 Lecture d'échantillons

`soundfiles.lib` (270 lignes) n'expose que **3 fonctions documentées** :
`so.loop`, `so.loop_speed`, `so.loop_speed_level`.

**Absents : synthèse granulaire, lecture multi-échantillons avec zones de
vélocité et key-mapping, points de bouclage avec fondu, lecture inverse,
« scrubbing », étirement temporel de fichier.** Le mot « granular » n'apparaît
que dans un commentaire d'`interpolators.lib`. C'est très en deçà du niveau
général du dépôt.

#### 6.16 Restauration et traitement correctif

**Absents : dé-esseur, débruitage spectral / porte spectrale, déclicage,
décracklage, restauration de bande passante (exciter psychoacoustique),
correction de composante continue avec compensation de phase, suppression de
ronflement secteur (notch harmonique adaptatif).** `fi.dcblocker` couvre le seul
cas de la composante continue.

#### 6.17 Traitement mid/side

`ef.stereo_width` (shuffling de Blumlein) existe et est bien documenté. Mais il
n'y a **pas de paire encodage/décodage M/S explicite** permettant d'insérer un
traitement arbitraire dans le domaine M/S — pattern de base en mastering
(compression M/S, EQ M/S, élargissement dépendant de la fréquence).

### Synthèse des lacunes

La dernière colonne indique la faisabilité en Faust monorate, détaillée au §7 :
**A** = directement écrivable, **B** = écrivable via un algorithme monorate
spécifique, **C** = nécessite l'extension multi-débit.

| # | Thématique | Priorité | État | Bloque | Mono |
|---|---|---|---|---|---|
| 6.1 | Fenêtres | **P0** | Absent | Traitement spectral, grains, FIR | **A** |
| 6.1 | Analyse spectrale glissante (SDFT) | **P0** | `goertzel` seul | — | **B** |
| 6.1 | STFT par trames | **P0** | Absent | Vocodeur de phase | **C** |
| 6.2 | Sur-échantillonnage / multi-débit | **P0** | Absent | Non-linéarités de qualité | **C** |
| 6.3 | Convolution partitionnée | **P0** | O(N) direct | Réverb à convolution, IR baffle | **C** |
| 6.3 | Convolution par bruit velvet | **P0** | Absent | — | **B** |
| 6.4 | Conversion de fréq. d'échantillonnage | **P0** | Absent | — | **C** |
| 6.4 | Lecture à vitesse variable anti-repliée | **P0** | Repliement | Échantillonneur propre | **B** |
| 6.5 | LUFS / EBU R128 / true-peak | P1 | Absent | Conformité broadcast | **B** |
| 6.6 | Dither / noise shaping | P1 | Absent | Sortie 16 bits correcte | **A** |
| 6.7 | Transposition granulaire améliorée | P1 | 2 taps | — | **B** |
| 6.7 | Vocodeur de phase / time-stretch | P1 | Absent | Étirement indépendant | **C** |
| 6.8 | Détection de hauteur | P1 | ZCR seulement | Accordage, correction | **B** |
| 6.9 | Descripteurs MIR / onsets | P1 | Dans `debug.lib` | Audio adaptatif | **B** |
| 6.10 | Binaural / HRTF | P1 | Absent | Écoute au casque | **B** |
| 6.11 | Filtrage adaptatif (LMS/NLMS) | P1 | Kalman seul | Annulation d'écho | **B** |
| 6.12 | Conception FIR par fenêtrage | P1 | Application seule | Filtres demi-bande | **A** |
| 6.12 | Parks-McClellan / Remez | P1 | Absent | — | **C** |
| — | `fi.hilbert` | P1 | Documenté, non défini | Décalage fréquentiel | **A** |
| 6.13 | Séquencement / contrôle | P2 | Partiel | — | **A** |
| 6.14 | Accords / microtonalité | P2 | 15 gammes 12-TET | Composition microtonale | **A** |
| 6.15 | Lecture d'échantillons / granulaire | P2 | 3 fonctions | Instruments à échantillons | **B** |
| 6.16 | Restauration | P2 | `dcblocker` seul | — | **A**/**B** |
| 6.17 | Encodage/décodage M/S | P2 | `stereo_width` seul | Mastering M/S | **A** |

---

## 7. Ce qui est raisonnablement écrivable en Faust monorate

Toutes les lacunes du §6 ne se valent pas : certaines sont bloquées par le modèle
d'exécution du langage, d'autres ne le sont pas du tout et attendent simplement
que quelqu'un les écrive. Cette section trie les 17 thématiques selon ce critère.

### 7.1 Critère retenu

« Monorate » = un échantillon d'entrée produit un échantillon de sortie par cycle,
sans traitement par blocs ni changement de fréquence d'horloge. Sont donc
disponibles :

- la récursion `~` (état à un échantillon de retard, boucles de rétroaction) ;
- `rdtable` / `rwtable` / `waveform` / `soundfile` (mémoire indexable, y compris
  en écriture — `rwtable` n'est aujourd'hui utilisé que dans `basics.lib` et
  `interpolators.lib`) ;
- le dépliage à la compilation (`par`, `seq`, `sum`, `prod`) et le repli de
  constantes, qui permettent de précalculer des coefficients arbitrairement
  complexes sans coût à l'exécution ;
- `ba.tabulate` / `ba.tabulateNd` pour tabuler toute fonction pure.

Sont indisponibles : le découpage en trames et le hop, tout changement de rythme,
et toute itération à la compilation dont le nombre de tours dépend des données.

**Le point important** : pour plusieurs des lacunes du §6, la version « manuel de
DSP » est par blocs, mais **il existe une formulation monorate équivalente ou
suffisante** qu'il faut aller chercher délibérément. C'est le cas du true-peak,
des descripteurs spectraux, du binaural et de l'analyse spectrale glissante.

### 7.2 Catégorie A — directement écrivable, effort faible

Rien ne s'y oppose ; c'est de l'arithmétique pure ou une récursion à un
échantillon. Ce sont les gains les plus rentables du dépôt.

| Lacune | Formulation monorate | Remarque |
|---|---|---|
| **6.1a Fenêtres** | `w(N,i)` = somme de cosinus d'un indice normalisé | Hann, Hamming, Blackman, Blackman-Harris, Bartlett, Nuttall, flat-top, Tukey : arithmétique pure. Utilisable en forme indexée (remplissage de table) **et** en forme signal pilotée par un phaseur (grains, fondus). |
| **6.6 Dither + noise shaping** | TPDF = somme de deux `no.noise` indépendants ; mise en forme = boucle d'erreur à un échantillon de retard | Cas d'école de la récursion Faust. Les courbes psychoacoustiques (Lipshitz, Shibata…) sont des jeux de coefficients constants. |
| **6.13 Contrôle / séquencement** | Limiteur de pente, portamento, séquenceur pas-à-pas, arpégiateur, enveloppes à points de rupture | Purement monorate. Les briques temporelles (`ba.beat`, `ba.tempo`, `ba.pulse`) existent déjà. |
| **6.17 Encodage/décodage M/S** | `(l+r)/2, (l-r)/2` et son inverse | Une ligne chacun. |
| **6.16a Dé-esseur** | Chaîne latérale passe-bande + compresseur existant | Toutes les pièces sont déjà dans `compressors.lib` et `filters.lib`. |
| **6.14 Accords / microtonalité** | Tables constantes + arithmétique | N-EDO, intonation juste, tempéraments historiques. Seul l'import de fichiers Scala `.scl` sort du langage. |
| **6.12a Conception FIR par fenêtrage** | `h[n] = ideal[n] × w[n]`, entièrement replié à la compilation | Dépend de 6.1a. Aucun coût à l'exécution. |

**Cas particulier — `fi.hilbert` n'existe pas.** La documentation de `fi.pospass`
(`filters.lib:2931-2936`) donne la définition, en toutes lettres, dans un bloc de
code :

```faust
// An approximation to the Hilbert transform is given by the
// imaginary output signal:
//
// ```
// hilbert(N) = pospass(N) : !,*(2);
// ```
```

…mais `hilbert` n'est **défini nulle part** dans le dépôt (`grep -rn '^hilbert' *.lib`
ne renvoie rien). Une transformée de Hilbert débloque le décalage fréquentiel par
modulation en bande latérale unique, la détection d'enveloppe analytique et le
suivi de phase instantanée. C'est une ligne à écrire, déjà rédigée.

**Réserve sur la fenêtre de Kaiser.** Elle requiert la fonction de Bessel
**modifiée** I₀. `maths.lib` fournit `ma.J0`, `ma.J1`, `ma.Jn` — mais ce sont les
Bessel du **premier type** (J), pas les modifiées (I), et ce sont des `ffunction`
liées à `j0()` de `<math.h>`, donc indisponibles sur les backends sans libm
(WASM notamment). I₀ doit donc être écrite en développement en série ; pour un β
constant, elle se replie intégralement à la compilation, sans coût à l'exécution.

### 7.3 Catégorie B — écrivable, mais impose un algorithme monorate différent

Ici la version par blocs est hors de portée, mais une formulation monorate donne
un résultat équivalent ou suffisant. C'est la catégorie qui demande une décision
de conception, pas seulement du travail de rédaction.

#### 6.5 LUFS / EBU R128 — largement faisable, y compris le true-peak

- **Pondération K** : deux biquads (shelf + passe-haut), directement
  `fi.high_shelf` / `fi.tf2s`. Trivial.
- **Momentané (400 ms) et court terme (3 s)** : moyenne quadratique glissante,
  récursion monorate. Trivial.
- **Intégré avec gating** : les blocs de 400 ms à 75 % de recouvrement se
  réalisent comme **4 intégrateurs rectangulaires décalés en phase, en
  parallèle** — monorate.
- **True-peak (ISP)** : c'est le point contre-intuitif. La norme ITU-R BS.1770
  spécifie un interpolateur polyphase ×4 précis ; **il n'est pas nécessaire de
  tourner à 4× pour l'appliquer** — il suffit d'évaluer les **4 phases FIR en
  parallèle** à chaque échantillon d'entrée et d'en prendre le maximum. C'est
  strictement monorate. Le §6.2 conclut à tort que le true-peak est bloqué par
  l'absence de sur-échantillonnage : il ne l'est pas.
- **LRA** : nécessite des percentiles sur tout le programme → histogramme à
  classes fixes en `rwtable`, monorate mais plus lourd.

**C'est le meilleur candidat du dépôt** : forte valeur (conformité broadcast),
faisabilité quasi intégrale, et forte complémentarité avec `compressors.lib` déjà
mature.

#### 6.9 Descripteurs MIR — via les bancs de filtres existants, pas via la FFT

Centroïde, étalement, flux, roll-off, flatness se calculent aussi bien à partir
des **énergies de bandes** que d'un spectre FFT. Or `an.mth_octave_spectral_level`
et les bancs `an.*_octave_analyzer` fournissent déjà ces énergies, en monorate.
La détection d'attaques suit (flux de bandes + seuil adaptatif). Même les **MFCC**
sont accessibles : banc de filtres mel monorate suivi d'une DCT sur ~40 bandes,
c'est-à-dire un produit matriciel à coefficients constants, déplié à la
compilation. Approche coûteuse mais entièrement monorate — et qui **réutilise ce
qui existe déjà** plutôt que d'attendre la STFT.

#### 6.10 Binaural / HRTF — le verdict du §6.3 est trop pessimiste ici

Les HRIR sont **courtes** : 128 à 256 coefficients par oreille. Une convolution
FIR directe coûte donc ~2×256 MAC par échantillon — parfaitement raisonnable en
monorate, sans aucun besoin de convolution partitionnée. S'ajoutent :

- la voie paramétrique (ITD par retard fractionnaire + ILD par filtre en plateau),
  triviale en monorate ;
- le décodage ambisonique vers binaural par haut-parleurs virtuels + HRIR, qui
  se branche directement sur `hoa.lib`.

Autrement dit, l'absence de convolution rapide bloque la réverbération à
convolution et les IR de baffle (§6.3), **mais pas le binaural**.

#### 6.11 LMS / NLMS — aucune différentiation automatique nécessaire

Pour un FIR linéaire, le gradient est exactement le vecteur d'entrée retardé :
`w[k] += μ·e·x[n−k]`. Ce sont N récursions parallèles à un échantillon de retard —
le motif monorate le plus canonique qui soit. NLMS ajoute une normalisation par
la puissance courante (somme glissante récursive). Entièrement faisable **sans
`rad`/`fad`** : le travail de `faust-rs` sur l'AD est utile pour les cas non
linéaires, mais LMS/NLMS/FxLMS n'en ont pas besoin. RLS demande une mise à jour
matricielle, plus lourde, mais `linearalgebra.lib` fournit les primitives.

#### Autres éléments de catégorie B

| Lacune | Formulation monorate retenue |
|---|---|
| **6.1b Analyse spectrale** | **DFT glissante (SDFT)** : mise à jour récursive à O(1) par bin et par échantillon, spectre disponible à chaque échantillon, sans trames. `an.goertzel` en est déjà le cas mono-bin. Exige la variante à stabilité garantie (SDFT modulée) pour éviter la dérive d'accumulation de la version naïve. C'est **la** réponse monorate à l'analyse spectrale. |
| **6.3b Réverbération à convolution** | Convolution par **bruit velvet** (FIR épars) pour le champ tardif — monorate et peu coûteuse. `no.velvet_noise` existe déjà (non documentée, `noises.lib:539`). Ne remplace pas une IR mesurée, mais couvre l'usage principal. |
| **6.4b Lecture à vitesse variable** | Noyau sinc fenêtré dont la largeur de bande suit le ratio de lecture : un échantillon de sortie par cycle, lecture de table à position fractionnaire. Corrige le repliement de `so.loop_speed` sans conversion de rythme. |
| **6.7b Transposition** | Transpositeur granulaire à 3–4 taps recouvrants fenêtrés (au lieu des 2 taps de `ef.transpose`). Nettement meilleur, monorate, dépend de 6.1a. |
| **6.8b Détection de hauteur** | PLL et filtre à encoche adaptatif (ANF) sont les estimateurs monorate naturels. Autocorrélation et AMDF restent exprimables avec des sommes glissantes récursives, à O(L) par échantillon — lourd pour les f0 graves (L ≈ 1000) mais réel. |
| **6.15 Granulaire / échantillonneur** | Lecteurs de table recouvrants à phaseurs indépendants + fenêtres. C'est l'un des motifs monorate les plus idiomatiques de Faust. Dépend de 6.1a. |
| **6.16b Débruitage** | Expandeur multibande sur banc de filtres, au lieu d'une porte spectrale FFT. |

### 7.4 Catégorie C — hors de portée du monorate

| Lacune | Raison |
|---|---|
| **6.2 Sur-échantillonnage / multi-débit** | Par définition. À noter : `aanl.lib` (ADAA) et les oscillateurs anti-repliés existent précisément **comme substituts monorate**. Le calcul des coefficients de filtres demi-bande, lui, est monorate — c'est le changement de rythme qui ne l'est pas. |
| **6.1c STFT par trames** | Découpage, hop et overlap-add supposent un rythme de trame. |
| **6.3a Convolution partitionnée** | Suppose une FFT par blocs. Reste bloquant pour les IR de salle longues (48 000–144 000 coefficients) et les IR de baffle. |
| **6.4a Conversion de fréquence d'échantillonnage** | Rythme de sortie ≠ rythme d'entrée. |
| **6.7a Vocodeur de phase, étirement temporel** | Suppose la STFT (6.1c). |
| **6.12b Parks-McClellan / Remez** | Algorithme d'échange itératif à contrôle de flot dépendant des données : non exprimable dans le repli de constantes de Faust. |

Ces six points sont ceux — et les seuls — qui justifient l'extension multi-débit.
Ils recoupent exactement le périmètre du travail sur les domaines d'horloge et
`fft_framed` de `faust-rs`
(`porting/ondemand-vec-fad-interleave-synthesis-2026-07-07-fr.md`).

### 7.5 Conséquence sur les priorités

Le §6 classait par importance DSP. En croisant avec la faisabilité, l'ordre
d'attaque devient :

1. **Fenêtres (6.1a)** — effort minimal, débloque 6.7b, 6.12a, 6.15 et rend
   enfin exploitable la FFT existante.
2. **`fi.hilbert`** — une ligne, déjà écrite dans la documentation.
3. **Dither / noise shaping (6.6)** et **M/S (6.17)** — effort minimal, valeur
   immédiate.
4. **LUFS / R128 + true-peak (6.5)** — le meilleur rapport valeur/faisabilité du
   dépôt, et non bloqué contrairement à ce que laissait entendre le §6.
5. **LMS / NLMS (6.11)** et **descripteurs MIR par banc de filtres (6.9)** —
   faisables aujourd'hui, réutilisent l'existant.
6. **Binaural paramétrique + HRIR par FIR direct (6.10)** — faisable sans
   convolution rapide.
7. **Granulaire (6.15)** et **transpositeur amélioré (6.7b)** — après les fenêtres.
8. **DFT glissante (6.1b)** — la vraie réponse monorate à l'analyse spectrale, à
   mener en parallèle de l'extension multi-débit plutôt qu'en attendant celle-ci.

Seuls les six points de la catégorie C doivent attendre le multi-débit. **Onze
des dix-sept lacunes sont écrivables dès aujourd'hui**, dont les quatre premières
en quelques heures chacune.

---

## 8. Recommandations, par ordre de rentabilité

### Immédiat — rétablir la capacité de détection (coût : quelques heures)

1. Ajouter `sys.exit(1 if diff_found else 0)` dans `scripts/floatdiff.py`.
2. Ajouter `exit 1` dans la branche `[fail]` du `Makefile`, et supprimer le
   `exit 0` qui masque les échecs de compilation.
3. Retirer `$(REFERENCE_DIR)` de la cible `clean` (ou introduire un
   `distclean` distinct).
4. Versionner `tests/reference/`, régénéré avec `NUM_SAMPLES`/`SAMPLE_RATE`/
   `FAUST_OPT` figés et documentés dans le fichier.
5. Ajouter un workflow CI qui exécute `make check` sur chaque PR.

*Sans ces cinq points, toutes les autres améliorations reposent sur une base non vérifiable.*

### Court terme — documentation (coût : quelques jours)

6. Documenter le sous-système FFT d'`analyzers.lib` (§3.1), en priorité la
   convention de représentation complexe.
7. Compléter les 15 blocs réduits à un `#### Test` et les 28 blocs sans `#### Usage` (§3.3, §3.4).
8. **Générer** `standardFunctions.md` depuis les marqueurs source, et ajouter une
   vérification CI (§3.5).
9. Normaliser les licences en identifiants SPDX + validation CI ; étendre la
   couverture au-delà de 31 % ou documenter explicitement la règle d'héritage (§3.6).
10. Ajouter des pages pour `tubes.lib` et `tonestacks.lib`, ou les déclarer
    explicitement hors périmètre standard dans `organization.md` (§3.2).
11. Marquer les 18 fonctions dépréciées `delay1s`/`time1s`/`echo1s`… et
    documenter que leurs noms désignent des puissances de deux, pas des
    secondes (§4.2). Corriger la documentation de `ba.downSample` (§4.3).

### Moyen terme — combler les lacunes écrivables dès aujourd'hui

Ordre issu du croisement importance × faisabilité monorate (§7.5). **Aucun de ces
points n'attend l'extension multi-débit.**

12. `an.window*` : famille de fenêtres (Hann, Hamming, Blackman, Blackman-Harris,
    Bartlett, Nuttall, flat-top, Tukey ; Kaiser via une série pour I₀, `ma.J0`
    n'étant ni la bonne fonction ni portable). Autonome, arithmétique pure,
    débloque 6.7b, 6.12a, 6.15 et rend enfin exploitable la FFT existante.
13. Définir `fi.hilbert` — une ligne, déjà rédigée dans la documentation de
    `fi.pospass` (§6.12).
14. `dither` + mise en forme du bruit, et la paire encodage/décodage M/S.
    Effort minimal, valeur immédiate.
15. Sonie normalisée : pondération K, LUFS momentané / court terme / intégré avec
    gating, et **true-peak par 4 phases FIR parallèles** — le tout monorate.
    Meilleur rapport valeur/faisabilité du dépôt (§7.3).
16. LMS / NLMS (récursions parallèles sur les poids, sans AD), puis descripteurs
    MIR calculés sur les bancs de filtres existants plutôt que sur une FFT.
17. Binaural : voie paramétrique (ITD/ILD) et HRIR par FIR direct — les HRIR sont
    assez courtes pour ne pas dépendre de la convolution partitionnée (§7.3).
18. Granulaire et transpositeur à taps recouvrants fenêtrés, une fois 12 en place.

### Moyen/long terme — ce qui exige réellement le multi-débit

Six points seulement (catégorie C du §7.4) :

19. Filtres demi-bande + `oversample(N, f)` / `upsample` / `downsample`
    anti-replié — conditionne la qualité de `aanl.lib`, `vaeffects.lib`, `tubes.lib`.
20. Cadre STFT (trames, recouvrement, overlap-add) — à articuler avec le travail
    `fft_framed` de `faust-rs` (P3/P4). En attendant, une **DFT glissante** à
    stabilité garantie fournit une analyse spectrale monorate utilisable (§7.3).
21. Convolution partitionnée, une fois 20 disponible ; débloque réverb à
    convolution et IR de baffle — mais pas le binaural, qui n'en dépend pas.
22. Conversion de fréquence d'échantillonnage, vocodeur de phase et étirement
    temporel. Parks-McClellan reste hors de portée du langage indépendamment
    du multi-débit.

### Structurel

23. Un `CONTRIBUTING.md` fixant : convention de nommage par bibliothèque, format
    de bloc de documentation obligatoire (description + `#### Usage` + `Where:` +
    `#### Test`), identifiant SPDX obligatoire, et exigence d'un test de
    non-régression pour toute nouvelle fonction.
24. Un vérificateur de documentation exécuté en CI, en étendant
    `scripts/audit2.py` (déjà fourni), rejetant tout nouveau symbole non
    documenté ou tout bloc réduit à une section `#### Test`.
25. Convention de préfixe (`_nom`) ou sous-environnement pour les symboles
    internes — `debug.lib` (34 `probe_*_impl`) et `routes.lib` (28 symboles de
    tri bitonique) montrent le besoin.

---

## 9. Ces bibliothèques peuvent-elles devenir un corpus de référence ?

La question mérite d'être posée explicitement, car la réponse modifie le
classement de plusieurs constats ci-dessus : les bibliothèques Faust peuvent-elles
occuper, pour le DSP audio, la place que mathlib occupe pour les mathématiques ?

### 9.1 Là où l'analogie tient

Faust possède ce qu'aucun autre écosystème DSP n'a : **une véritable sémantique
dénotationnelle**. Un programme Faust *est* une fonction sur des signaux ℤ→ℝ, et
les cinq opérateurs de composition forment une algèbre. Ce n'est pas une
métaphore — c'est ce qui rend le compilateur possible, et c'est le même type de
socle que celui de mathlib. SciPy, JUCE et le code du livre DAFx sont des
collections de fonctions dans un langage généraliste ; il n'y a rien sur quoi
raisonner.

Deux autres propriétés « mathlib-esques » sont réellement présentes : un dépôt
unique vérifié par un outil unique (§2 — les 43 bibliothèques parsent sous un
seul compilateur), et une source unique qui se projette vers C++, LLVM, WASM et
Rust. La source *est* l'artefact.

Et pour un sous-domaine, c'est déjà partiellement vrai : `filters.lib` encode
largement les livres en ligne de Julius Smith. Quand quelqu'un demande « le »
Butterworth ou « la » réverbération zita, la réponse est déjà, en pratique, ici.

### 9.2 Là où l'analogie casse structurellement

**Il n'y a pas de noyau.** mathlib affirme « cette preuve est correcte », et un
petit noyau le tranche. Qu'affirment ces bibliothèques ? Que `fi.lowpass(3, 1000)`
*est* un passe-bas Butterworth d'ordre 3 à 1 kHz — et **rien ne vérifie cette
affirmation**. Le typage contrôle l'arité et les rythmes, pas la sémantique DSP.
Le nom est une promesse tenue par la seule vigilance humaine.

Le §5 a montré que même la vérification faible — la non-régression numérique —
est inopérante. Une bibliothèque de référence dont les tests réussissent toujours
n'est pas une référence.

Et même réparée, cette vérification resterait **tautologique** : les fichiers
`.ref` sont engendrés depuis le code même qu'ils sont censés valider. Le noyau de
Lean, lui, est *indépendant* du théorème qu'il vérifie. C'est toute la différence.

**La déduplication est un contresens ici.** mathlib se bat pour *la* bonne
définition et refactorise globalement. Un corpus DSP doit faire l'inverse : les
30 topologies VA de `vaeffects.lib` et les 15 réverbérations ne sont pas de la
redondance à éliminer, elles *sont* le contenu. Elles arbitrent différemment entre
CPU, latence, artefacts et caractère. « Meilleur » n'y est pas un théorème.

**Le flottant.** mathlib travaille sur ℝ exactement. Ici, la même source donne des
résultats bit-différents selon le backend et les options — le §5.4 a trouvé des
références produites à un `NUM_SAMPLES` différent qui passaient silencieusement,
une classe de dérive que ℝ ne connaît tout simplement pas.

**L'acceptation perceptive.** Qu'une réverbération soit bonne relève en partie de
la psychoacoustique. Aucun noyau ne le tranche.

### 9.3 La forme atteignable

Pas « mathlib du DSP » au sens fort, mais quelque chose de réel que rien
n'occupe aujourd'hui : **le corpus de référence exécutable, composable,
multi-cible, à propriétés vérifiées mécaniquement**.

La brique manquante n'est pas la preuve, c'est la **spécification**. Les 1 028
blocs de documentation disent en prose ce que font les fonctions ; aucun n'énonce
une propriété vérifiable. Devenir une référence suppose d'écrire, à côté de
`fi.lowpass`, quelque chose comme : −3 dB en fc à ±0,1 dB près, pente
6N dB/octave, tous les pôles dans le cercle unité — et de faire échouer la CI
quand c'est faux. Un oracle **analytique**, dérivé de la théorie, pas du code.

C'est exactement la discipline producteur / vérificateur indépendant / mutations
rejetantes : l'indépendance du vérificateur est le rôle du noyau, transposé au DSP.

**Où Lean s'applique réellement.** Non pas à prouver qu'une réverbération sonne
bien, mais aux énoncés qui *sont* des théorèmes sur l'algèbre des signaux :
stabilité d'une structure sous contrainte sur les coefficients, **équivalence de
deux expressions de diagramme** (qui validerait d'un coup les réécritures du
compilateur et les refactorisations de bibliothèque), convergence de l'ADAA
d'ordre 1 vers la non-linéarité idéale, identités des guides d'ondes. Le travail
Lean de `faust-rs` vise le compilateur ; la même sémantique porterait les énoncés
au niveau des bibliothèques.

### 9.4 Ce que cela change au classement des constats

C'est la partie opérationnellement utile. Lus comme une revue de qualité
ordinaire, trois constats relèvent du rangement. Sous l'ambition du corpus de
référence, ils deviennent **bloquants** :

- **§4.1 conventions de nommage** (367 `snake_case` contre 382 `camelCase`,
  17 bibliothèques mixtes) et **§3.5 désynchronisation de
  `standardFunctions.md`**. La découvrabilité de mathlib repose sur des
  conventions de nommage assez strictes pour être mécaniquement dérivables de
  l'énoncé. Un corpus où l'on hésite entre `ba.sec2samp` et `ba.sAndH` ne peut pas
  être cité comme autorité.
- **§3.6 métadonnées de licence** (16 orthographes, 31 % de couverture). mathlib
  est uniformément sous Apache 2.0. Un corpus sur lequel l'industrie s'appuie ne
  peut pas porter une traçabilité juridique dans cet état.

À l'inverse, un constat s'atténue : la pluralité des algorithmes — et une part de
la duplication relevée au §4.2 — n'est pas un défaut sous cette lecture, à
condition que chaque variante documente l'arbitrage qu'elle opère.

### 9.5 Ordre des travaux

La séquence est contrainte et n'admet pas de permutation :

1. `make check` doit pouvoir échouer (§8, points 1 à 5). Tant que ce n'est pas le
   cas, tout le reste est décoratif.
2. Des oracles analytiques indépendants en remplacement des références
   auto-engendrées — une spécification par fonction, en commençant par le domaine
   où la théorie est la plus nette (`filters.lib`).
3. Des énoncés formels en Lean sur l'algèbre des signaux, pour les propriétés qui
   sont véritablement des théorèmes.

Lean est l'étape 3. Y commencer reviendrait à poser la toiture d'abord.

---

## 10. Tester les propriétés DSP avec Lean

Le §9.5 place les énoncés formels en troisième position, après un harnais capable
d'échouer et après des oracles analytiques indépendants. Cette section rend cette
troisième étape concrète : ce qui peut réellement être énoncé, à quel coût, et
comment cela se rattache à un fichier `.lib`.

Elle s'appuie sur la formalisation existante de `faust-rs`
(`docs/lean-usage-methodology-en.md` et les quatre fichiers
`porting/*-formal-spec.lean`), dont les règles de maison sont reprises telles
quelles : Lean 4.31 avec le seul `Std` embarqué, pas de `mathlib`, pas de `sorry`,
pas d'axiome au-delà des trois standard, jugement `Prop` + vérificateur `Bool` +
théorème les reliant, noms terminés par `B` renvoyant un `Bool`.

À noter : ces quatre spécifications s'arrêtent délibérément avant la sémantique des
signaux — `bda-typing-formal-spec.lean` précise que `Box` est *« an arity skeleton,
not a shadow AST »*. Les propriétés de bibliothèque sont donc un territoire
nouveau, pas une extension des fichiers existants.

### 10.1 Trois étages de propriétés

Le réflexe est de viser « prouver que `fi.lowpass` est un Butterworth », ce qui
demande analyse réelle, nombres complexes et transformée en z — donc mathlib, donc
rupture avec la règle Std-only. Mais beaucoup de propriétés DSP réellement utiles
ne sont pas analytiques.

**Étage 1 — structurel et arithmétique (Std seul, style de maison inchangé)**

- bornes d'indices des lignes à retard et des `rwtable` : `de.fdelay(maxdel, d)` ne
  lit jamais hors plage pour `d ∈ [0, maxdel]` ;
- correction des récurrences de coefficients (Butterworth, Chebyshev) comme
  arithmétique exacte ;
- identités structurelles entre expressions de diagramme — la même activité que
  `normalization-rewrites-formal-spec.lean`, appliquée aux identités de
  bibliothèque ;
- **critères de stabilité de forme finie** : Jury/Schur-Cohn, et
  `|coefficient de réflexion| < 1` pour les treillis, sont des tests arithmétiques
  finis, pas des recherches de racines.

**Étage 2 — identités algébriques sur les fractions rationnelles**

Plusieurs propriétés *d'apparence* analytique sont en fait des identités
polynomiales. « Allpass » s'écrit `H(z)·H(1/z) = 1`. « Reconstruction parfaite »
s'écrit `H_lp(z) + H_hp(z) = z⁻ᵏ`. La complémentarité en puissance de même.
Énoncées ainsi, elles quittent l'analyse pour de l'algèbre décidable.

**Étage 3 — analytique (mathlib obligatoire)**

Réponse en fréquence en dB, « −3 dB en fc », convergence de l'ADAA. À traiter comme
un flux séparé et optionnel : mathlib coûte en temps de build et en churn de
version, et la ressource rare est la capacité de revue.

### 10.2 Un pilote vérifié par le noyau : `fi.tf2s` préserve la stabilité

`fi.tf2s` est la transformation bilinéaire d'une section analogique, et l'essentiel
de `filters.lib` repose dessus :

```faust
c   = 1/tan(w1*0.5/ma.SR);
d   = a0 + a1 * c + csq;
a1d = 2 * (a0 - csq)/d;
a2d = (a0 - a1*c + csq)/d;
```

Le `tan` semble disqualifiant. Il ne l'est pas : **`c` n'intervient dans l'argument
de stabilité que par son signe.** Sous Nyquist, `c > 0`, et c'est tout ce dont la
preuve a besoin — la fonction transcendante n'est donc jamais modélisée, et
l'énoncé devient de l'arithmétique rationnelle exacte. Garder la section sur un
dénominateur commun élimine toute division :

```lean
structure Section where
  n1 : Rat
  n2 : Rat
  d  : Rat

/-- Critère de Jury / Schur-Cohn à l'ordre 2, dénominateurs éliminés. -/
def JuryStable (s : Section) : Prop :=
  0 < s.d ∧ 0 < s.d + s.n2 ∧ 0 < s.d - s.n2 ∧
  0 < s.d + s.n2 - s.n1 ∧ 0 < s.d + s.n2 + s.n1

/-- Le calcul de dénominateur de `fi.tf2s` ; `c` est opaque, seul `0 < c` sert. -/
def tf2sDen (a0 a1 c : Rat) : Section :=
  { n1 := 2 * (a0 - c * c)
    n2 := a0 - a1 * c + c * c
    d  := a0 + a1 * c + c * c }

theorem tf2s_preserves_stability (a0 a1 c : Rat)
    (ha0 : 0 < a0) (ha1 : 0 < a1) (hc : 0 < c) :
    JuryStable (tf2sDen a0 a1 c) := by
  have hP : 0 < a1 * c := Rat.mul_pos ha1 hc
  have hQ : 0 < c * c := Rat.mul_pos hc hc
  refine ⟨?_, ?_, ?_, ?_, ?_⟩ <;> simp only [tf2sDen] <;> grind
```

`0 < a0` et `0 < a1` sont exactement les conditions de Hurwitz du prototype
analogique `s² + a1·s + a0`. Le théorème se lit donc : **la transformation
bilinéaire envoie une section analogique du second ordre stable sur une section
numérique Jury-stable, à toute fréquence d'échantillonnage et pour toute coupure
sous Nyquist** — un seul théorème couvrant tous les filtres de la bibliothèque
construits sur `tf2s`.

La preuve fonctionne parce que les cinq buts, une fois les produits `a1·c` et `c·c`
abstraits, sont *linéaires* en ces atomes. Ils se réduisent à des formes closes :
`d + n2 = 2a0 + 2c²`, `d − n2 = 2a1c`, `d + n2 − n1 = 4c²`, `d + n2 + n1 = 4a0`.

Le fichier complet est `tf2s-stability-formal-spec.lean`, à côté de ce rapport. Il a
été vérifié avec Lean 4.31 et le `Std` embarqué : **sortie 0 en 3,9 s, aucun
`sorry`, axiomes limités à `propext`, `Classical.choice`, `Quot.sound`** — le même
budget que les spécifications `faust-rs` existantes.

```bash
lean tf2s-stability-formal-spec.lean
```

Deux constats pratiques pour qui écrira la suivante :

- l'API d'ordre de `Std` sur `Rat` est mince — `Rat.mul_pos` existe, `Rat.add_pos`
  non — mais **`grind` ferme les buts rationnels linéaires**, ce qui dispense d'un
  `linarith` de niveau mathlib. C'est ce qui rend l'étage 1 abordable.
- `decide` ne réduit pas à travers les instances de décidabilité de `Rat` (il bloque
  sur `Rat.instDecidableLt`). Énoncer et prouver du côté `Prop`, et atteindre le
  vérificateur `Bool` par le théorème de correction plutôt que par évaluation.

L'équivalence classique « critère de Jury ⟺ racines dans le disque unité » reste
une **obligation nommée** — précisément l'emplacement d'*obligation ledger* que la
méthodologie prévoit déjà — prouvable plus tard si le flux mathlib s'ouvre.

### 10.3 Relier Lean au `.lib`

Lean ne connaît rien de `filters.lib`. Trois architectures :

| | Approche | Coût | Faiblesse |
|---|---|---|---|
| **A** | Modéliser à la main en Lean ; le vérificateur exécutable est l'oracle de référence contre lequel le code Faust est testé sur fixtures | Faible ; *c'est* le patron producteur/vérificateur existant | Le modèle manuel peut dériver du `.lib` |
| **B** | Importer le graphe de signaux compilé dans Lean ; les propriétés portent sur le graphe réellement produit | Plus élevé | Aucune structurellement — la dérive disparaît |
| **C** | Écrire le DSP en Lean et en extraire du Faust | — | Irréaliste sur un corpus existant de 53 000 lignes |

B est l'analogue du « S0 importer » de la feuille de route, et **`faust-rs` dispose
d'un avantage que Faust amont n'a pas** : il produit déjà des dumps FIR structurels.
A pour le pilote, B comme cible.

### 10.4 Ce que Lean ne remplace pas

Distinction à tenir fermement, sans quoi l'exercice devient une illusion :

- Lean prouve que **la formule spécifiée** possède la propriété visée ;
- le test numérique prouve que **le `.lib` calcule cette formule**.

Aucun des deux ne suffit seul. C'est pourquoi l'ordre du §9.5 tient : Lean sans
harnais capable d'échouer produirait des théorèmes vrais sur du code que personne ne
vérifie.

### 10.5 Un prototype fonctionnel de la voie d'import

Le §10.3 présentait l'architecture B — importer le graphe de signaux compilé —
comme la cible plutôt que le point de départ. Elle s'avère atteignable dès
maintenant :

```
.dsp  →  faust-rs --dump-sig  →  parseur  →  terme Lean Sig  →  theorem … := by decide
```

**Aucune modification de `faust-rs` n'a été nécessaire.** L'option `--dump-sig`
existe déjà et produit une S-expression propre (`SIGBINOP(op=add (+), …)`,
`int(n)`, `float_bits(0x…)`, `DEBRUIJNREC`, `DEBRUIJNREF`), ce qui était la
principale inconnue.

Le prototype se compose de :

| Fichier | Rôle |
|---|---|
| `signal-import-formal-spec.lean` | Prélude écrit et relu à la main : l'inductif `Sig`, l'extracteur de récursion linéaire, le critère de Jury, les obligations consignées |
| `scripts/sig2lean.py` | Parseur du dump et émetteur Lean ; exécute Lean une fois pour lire chaque verdict, puis émet un théorème `by decide` qui le fixe |
| `tests/lean-examples/` | Cinq entrées `.dsp` et le `certified.lean` engendré |

Résultats, tous verdicts corrects :

| DSP | `a₁`, `a₂` extraits | Verdict |
|---|---|---|
| `+ ~ *(0.7)` | −0,7, 0 | stable |
| `fi.tf2(…, −1.2, 0.5)` | −1,2, 1/2 | stable |
| `fi.tf2(…, −0.5, −0.8)` | −1/2, −0,8 | instable |
| `+ ~ *(1.5)` | −3/2, 0 | instable |
| `+ ~ (*(0.9) : ma.tanh)` | — | refusé : non linéaire |

Les cinq théorèmes se vérifient en 4,2 s et **ne dépendent que de `propext`**.

#### Ce que la construction a révélé

- **La récursion n'est pas à la racine.** La première conception supposait un
  graphe exporté de la forme `SIGPROJ(0, SIGREC(…))`. Or `fi.tf2` — la première
  vraie fonction de bibliothèque essayée — place le `SIGREC` *sous* le numérateur,
  en `b₀w[n] + b₁w[n-1] + b₂w[n-2]`. Le certificateur doit **chercher** la
  récursion, pas présumer sa position. Un prototype éprouvé seulement sur des
  expressions jouets aurait paru correct.
- **`Rat` est inutilisable dans un vérificateur décidable.** Ni `decide`, ni
  `grind`, ni `rfl` ne réduisent à travers `Rat.instDecidableLt` dans Std 4.31.
  Les coefficients sont donc portés en paires d'entiers — et comme tout double
  IEEE-754 vaut exactement `m/2ᵏ`, l'import est **exact**, pas approché.
- **`deriving DecidableEq` ne s'applique pas à l'inductif imbriqué**
  (`opaqueN … (kids : List Sig)`), donc les récursions trouvées ne peuvent pas
  être dédupliquées structurellement. Comparer leurs *analyses* est moins coûteux,
  et se trouve être plus fort : un verdict n'est accepté que si toutes les
  récursions du graphe concordent.
- **La totalité achète une correction unilatérale.** Tout tag non modélisé devient
  `opaqueN`, que l'analyse ne peut jamais lire comme terme linéaire. Ajouter un
  tag ne peut qu'élargir ce qui est accepté, jamais faire accepter du faux.

#### Ce qu'il n'est pas

Le prototype réalise l'*import* de l'architecture B mais conserve la faiblesse
d'adéquation de l'architecture A : `feedbackOf` est affirmé, non prouvé, renvoyer
les coefficients de rétroaction de la récursion qu'on lui a donnée. Le prouver
demande une dénotation `Sig → (ℕ → ℝ)`, donc mathlib, donc l'étage 3 (§10.1).
En attendant, la garantie est unilatérale : l'extracteur renvoie `none` sur tout
ce qu'il ne reconnaît pas exactement, de sorte qu'un verdict positif ne provient
jamais d'un graphe mal lu.

Il ne traite par ailleurs que les récursions à une sortie d'ordre ≤ 2, et certifie
les **rationnels exacts** dénotés par les coefficients exportés — pas le
comportement du filtre exécuté en virgule flottante (§9.2).

### 10.6 Une seconde analyse sur le même import : les bornes d'indices

La stabilité est une propriété parmi d'autres ; la voie d'import en vaut
plusieurs. La seconde analyse sur le même graphe demande si les lectures de table
et les prises de retard sont adressées dans les bornes.

#### Une hypothèse qui n'a pas survécu au contact

Elle partait d'un bug attendu : un slider déclaré `0..100` indexant une table de
16 entrées. Ce DSP compile sans avertissement, et le graphe de signaux était un
`SIGRDTBL(SIGWRTBL(int(16), …), SIGINTCAST(SIGHSLIDER(int(0))))` nu. Mais le C++
engendré est :

```cpp
float fSlow0 = ftbl0mydspSIG0[std::min<int>(((int)(((float)(fHslider0)))), 15)];
```

Le backend insère le clamp à partir de l'analyse d'intervalles du compilateur,
qui exploite la plage déclarée du slider. **Il n'y a pas de bug.**

#### Ce que coûtait la métadonnée manquante, et ce que sa correction change

La première version de cette analyse devait rapporter *non prouvé* tout index
issu d'un contrôle, parce que la plage nécessaire n'était pas dans le dump : un
nœud de signal ne porte qu'un `ControlId`, et `SIGHSLIDER(int(0))` ne dit rien de
`0..100`. C'était une lacune de l'exportateur, non une limite de la méthode, et
elle est depuis comblée dans `faust-rs` : `--dump-sig` résout désormais la plage
déclarée des sliders, entrées numériques et bargraphs.

Les bornes disponibles, l'analyse cesse de s'abstenir — et change de sens. Ce
n'est pas « ce programme est-il sûr » : le backend le garantit. C'est

> cet index reste-t-il dans les bornes **tel qu'il est écrit**, ou sa sûreté
> repose-t-elle sur un clamp inséré par le compilateur ?

D'où un verdict à trois valeurs. `CLAMP REQUIRED` n'est pas un rapport de défaut ;
il nomme une dépendance réelle envers le backend. L'analyse devient ainsi un
**oracle indépendant de l'insertion de bornes du compilateur** : un site qu'elle
déclare dans les bornes mais que le backend clampe quand même est une
optimisation manquée, et la réciproque serait un vrai défaut.

#### Résultats

| DSP | Plage de l'index | Verdict |
|---|---|---|
| `de.fdelay(1024, hslider(…))` | `[0, 1025]` | `NON-NEGATIVE` |
| `rdtable(16, 1.0, min(15, max(0, …)))` | `[0, 15]` | `IN RANGE` |
| `rdtable(16, 1.0, min(100, max(0, …)))` | `[0, 100]` | `CLAMP REQUIRED` |
| `rdtable(16, 1.0, int(hslider("i",0,0,100,1)))` | `[0, 100]` | `CLAMP REQUIRED` |
| `os.osc(440)` | `[?, ?]` | `not proven` |
| `fi.tf2(…)` | `[1, 1] … [2, 2]` | `NON-NEGATIVE` |

La troisième ligne mérite d'être relevée : la source *écrit* bien un clamp,
`min(100, max(0, …))`, et il est trop large pour borner une table de 16 entrées.
Le verdict le dit — un clamp explicite qui ne fait pas son office est un défaut de
code que le compilateur répare silencieusement.

Les verdicts de table et de prise de retard sont délibérément formulés
différemment. Une lecture de table est confrontée à une taille que le graphe
porte ; une prise de retard n'y a pas de taille déclarée — le compilateur déduit
la longueur de la ligne de cet index même — de sorte que la seule affirmation
disponible est la non-négativité.

Les vingt théorèmes des deux analyses se vérifient en 4 s environ, ne dépendant
que de `propext`.

#### Trois constats Lean

- **`partial def` est invisible au noyau.** La fonction de bornes descend dans les
  enfants d'une liste `opaqueN`, ce que Lean n'accepte pas comme structurellement
  décroissant sur un inductif imbriqué ; elle avait donc été écrite `partial`.
  `#eval` fonctionnait alors, mais pas `decide`. La récursion sur un compteur de
  carburant explicite corrige cela ; l'épuisement rend la plage inconnue, réponse
  sûre.
- **Une plage exige deux côtés indépendamment optionnels.** Avec
  `Option (Int × Int)`, `max 0 x` — côté bas borné, côté haut inconnu — n'est pas
  exprimable, et un clamp correct était rapporté hors bornes.
- **La troncature doit élargir des deux côtés.** Les bornes de contrôle sont des
  rationnels, donc la plage l'est aussi, et `SIGINTCAST` doit la ramener aux
  entiers. Arrondir les deux extrémités par le bas est incorrect pour les valeurs
  négatives, où la troncature remonte : `trunc(-2,5) = -2` échappe à
  `[⌊-2,9⌋, ⌊-2,1⌋] = [-3, -3]`. Le choix sûr est `[⌊lo⌋, ⌈hi⌉]`.

#### Où elle s'arrête

`os.osc` est bornée en réalité par un `%` sur un compteur dont l'invariant est
`0 ≤ c < 65536`, mais cet invariant vit dans une récursion où l'analyse n'entre
pas : le prouver demande un point fixe, pas une traversée. C'est désormais la
*seule* abstention restante parmi les exemples — la lacune de métadonnée est
comblée, la lacune d'analyse ne l'est pas.

---

## Annexe — reproduire les mesures

```bash
cd /Users/letz/Developpements/faustlibraries

# Vérifier que toutes les bibliothèques parsent
for f in *.lib; do b=${f%.lib}; printf 'process = 0; l = library("%s");\n' "$f" > /tmp/lt.dsp; \
  faust -I . /tmp/lt.dsp -o /dev/null || echo "ÉCHEC: $f"; done

# Reproduire le défaut du harnais de test
make tests/output/dcblocker_test.out; echo "EXIT=$?"
./scripts/floatdiff.py tests/reference/dcblocker_test.ref tests/output/dcblocker_test.out 1e-5 > /dev/null; echo "floatdiff EXIT=$?"

# Confirmer l'absence de fonctions de fenêtrage
grep -rE '^\s*(hann|hamming|blackman|kaiser|tukey|bartlett|nuttall)[a-zA-Z0-9_]*\s*[(=]' *.lib

# fi.hilbert : documenté dans fi.pospass mais jamais défini
sed -n '2931,2936p' filters.lib   # la définition, en commentaire
grep -rn '^hilbert' *.lib          # aucun résultat

# ma.J0 est une ffunction sur j0() : Bessel du 1er type, pas la modifiée I0
grep -n 'ffunction' maths.lib | grep -i 'j0\|j1\|jn'
```

### Le pilote Lean

```bash
lean tf2s-stability-formal-spec.lean   # Lean 4.31, Std embarqué ; sortie 0, ~4 s
```

Le fichier se termine par trois auto-vérifications `#print axioms` : la sortie
attendue ne nomme que `propext`, `Classical.choice` et `Quot.sound`. Tout `sorryAx`
ou `Lean.ofReduceBool` dans cette sortie signifie que le fichier ne respecte plus
la règle de maison.

### Couverture documentaire

Le tableau du §2 et les listes des §3.1, §3.3 et §3.4 sont reproduits par
`scripts/audit2.py`, exécutable depuis n'importe quel répertoire :

```bash
scripts/audit2.py                    # tableau + les 15 blocs réduits à un #### Test
scripts/audit2.py /tmp/audit.json    # avec export JSON détaillé
```

Il tient compte des conventions réellement employées : en-têtes multi-fonctions
(`` `(fi.)tf1`, `(fi.)tf2` et `(fi.)tf3` ``), motifs génériques
(`` `(de.)fdelay[N]` ``) et exclusion des alias `library()` — sans quoi chaque
import (`ba`, `fi`, `ma`…) est compté comme un symbole non documenté.

`scripts/audit.py` est la première version naïve, conservée à titre de
comparaison : l'écart entre les deux sorties mesure ce que les conventions de
marquage coûtent à un analyseur qui les ignore (par exemple `filters.lib` à 79 %
au lieu de 96 %, `delays.lib` à 16 % au lieu de 57 %).

### Mesures non scriptées

Les trois autres mesures du rapport — conventions de nommage (§4.1),
normalisation des licences (§3.6) et cohérence de `standardFunctions.md` (§3.5) —
ont été obtenues par des scripts jetables non conservés. Elles restent
reproductibles à partir des définitions données dans les sections correspondantes ;
les intégrer à `audit2.py` en ferait un vérificateur de documentation utilisable
en CI (cf. recommandation 24).


---

## Addendum du 2026-08-26 — état d'avancement du plan

Toutes les recommandations de la section 8 réalisables en monorate sont
faites, sur la branche `claude`, chaque point vérifié par le circuit complet
(validation numérique contre des références indépendantes, `make reference`
incrémental, `make -k check` intégral, puis `make checkdoc` une fois créé).

### Phase 0 — immédiat : FAIT (sauf CI, différée volontairement)

Points 1-3 et la moitié locale du point 4 : `e60c77c2`. `floatdiff.py` sort en
erreur sur divergence, le Makefile propage les échecs de build et de
comparaison (`.DELETE_ON_ERROR` compris), `clean` préserve `tests/reference/`
(un `distclean` séparé la supprime), et `make reference` trace ses paramètres
dans `tests/reference/PARAMS`. Les 1 110 références ont été régénérées
(1,2 Go, locales — trop volumineuses pour être versionnées telles quelles) et
le `make -k check` intégral passe. Le point 5 (CI) est différé sur décision
explicite : rien sur GitHub pour l'instant.

### Phase 1 — documentation (6-11) : FAIT

* **6** `cb7c7fbd` — sous-système FFT d'`analyzers.lib` documenté, convention
  de représentation complexe en tête ; couverture 51 % → 100 %.
* **7** `f8cac689` — les 15 blocs « Test seul » de `filters.lib` et les blocs
  sans `#### Usage` complétés ; en-têtes `_even` intervertis, en-tête
  `bandstop` dupliqué, arités `_odd` et trois `declare` malformés corrigés au
  passage. La partie `aanl.lib` a été annulée sur demande (`7380f340`).
* **8** `27f3a807` — `standardFunctions.md` désormais **généré** depuis les
  marqueurs source (`scripts/build_standard_functions.py`, mode `--check`) ;
  les 42 fonctions manquantes ajoutées, l'entrée morte `sy.popFilterPerc`
  retirée, les 9 fonctions non marquées résolues côté source.
* **9** `12381dad` — 373 déclarations de licence normalisées en identifiants
  SPDX canoniques (`scripts/normalize_licenses.py`, mode `--check`) ; les 16
  orthographes ramenées à 11 identifiants, dont `LicenseRef-STK-4.3`.
* **10** `5e3ed239` — `tonestacks.lib` documentée à 100 % (25 modèles
  identifiés), `tubes.lib` à 36 % (tout sauf les tables), pages du site
  ajoutées, `organization.md` mis à jour.
* **11** `5766d524` — les 18 fonctions dépréciées portent
  `declare ... deprecated` et l'avertissement puissances-de-deux ;
  documentation de `ba.downSample` réécrite (échantillonneur-bloqueur, pas
  une décimation).

### Phase 2 — lacunes monorate (12-18) : FAIT

* **12** `828e630d` — famille `an.window_*` (Hann → Kaiser via série I0 de
  40 termes, constructeur `window_cosN`), validée à 1e-6.
* **13** `f9529beb` — `fi.hilbert` défini, précision documentée sur mesures.
* **14** `9f671593` — `ef.ms_enc`/`ef.ms_dec` (identité à 1e-16),
  `ef.dither` TPDF et `ef.dither_shaped` (NTF `(1-z^-1)^K` ; un bug de signe
  trouvé et corrigé par la mesure : +23 dB de bascule à l'ordre 2).
* **15** `46b70db5` — `an.loudness_momentary/shortterm/integrated` (points de
  conformité BS.1770 à 0,006 dB) et `an.true_peak` (polyphase 4x12, poids
  Kaiser à la compilation, +0,08 dB sur pic inter-échantillon).
* **16** `9e02888d` — `fi.lms`/`fi.nlms` (identification convergée à
  -271 dB) ; `an.spectral_centroid/spread/flux` sur les bancs d'octaves,
  ordre des bandes établi et documenté.
* **17** `7bb62808` — `sp.binauralModel` (Brown-Duda : ITD mesuré 33
  échantillons pour 31,5 prédits, ILD 16,7 dB pour 16,2) et `sp.binauralFir`.
* **18** `61ba486d` — `ef.transpose_windowed` (taps Hann recouvrants) et
  `ef.granular` (identité à ratio 1, octave exacte à ratio 2, phasing
  granulaire documenté).

Au total : 31 fonctions publiques et 28 tests de régression ajoutés.

### Structurel (23-25) : FAIT

* **24** `005f353c` — `make checkdoc` : verrou anti-régression agrégeant
  couverture (baseline versionnée `tests/doc-baseline.json`), blocs
  incomplets, `standardFunctions.md` et licences. Sa première exécution a
  attrapé deux régressions réelles.
* **23** `05a795bd` — politiques manquantes ajoutées à `contributing.md` :
  nommage (style dominant du fichier), SPDX obligatoire, test exigé,
  convention `_nom`.
* **25** `191eae68` + `43bf58d0` — convention `_nom` outillée (exclue de la
  couverture) et migration effectuée : 34 internes de `debug.lib` et 25 de
  `routes.lib` renommés, alias dépréciés conservés une version ; les
  en-têtes de `bitonicSort`/`bitonicSortIdx` réparés (backticks manquants),
  `db.DEBUG` documenté.

### Phase 3 (19-22) : EN ATTENTE

Suspendue à l'extension multi-débit (travail clock-domains de `faust-rs`),
conformément au §7.4.

### Chantier ouvert : diagrammes SVG au-delà d'`aanl.lib`

Le prototype (`scripts/plot_lib.py` + `doc/scripts/inject_plots.py`,
injection par convention de nommage, 38 figures) est étendu selon le plan
suivant. Critère : une figure se justifie quand elle montre une propriété
invisible en prose — réponse en fréquence, courbe temporelle, courbe
statique, spectre. Chaque type de figure embarque une assertion de propriété
(le passe-bas doit être à -3 dB en fc...), dans l'esprit d'oracle analytique
du §9.

* **Phase A** (~60 figures) : `filters.lib` (ordres superposés, courbe K,
  crossovers avec leur somme), `an.window_*` (forme + lobes), `envelopes.lib`,
  `noises.lib` (pentes théoriques en repère), `compressors.lib`
  (caractéristiques statiques), `ef.dither_shaped` (NTF mesurée).
* **Phase B** (~55 figures) : `oscillators.lib` (anti-repliement),
  `vaeffects`, `webaudio`, `tonestacks` (une courbe d'EQ par ampli),
  `tubes` (transferts d'étages), `phaflangers`, `de.fdelay[N]`.
* **Phase C** (optionnelle) : réverbes (EDC), `sp.binauralModel`
  (ITD/ILD polaires), quantizers.

Hors périmètre : basics, routes, signals, maths, physmodels, synths, demos,
debug, soundfiles, mi, fds, wdmodels. Coût accepté : ~3,5 Mo d'images au
total au format actuel (texte en `<text>`, décimation).
