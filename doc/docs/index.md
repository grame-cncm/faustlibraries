# Faust Libraries

The Faust libraries implement hundreds of DSP functions for audio processing and synthesis. They are organized by types in a set of `.lib` files (e.g., `envelopes.lib`, `filters.lib`, etc.). Librairies use [semantic versioning](https://semver.org), so may evolve in a manner where newer versions break compatibility with older ones. The recommended way to solve this issue is to keep *self-contained versions of the DSP code*  (that is the DSP program with all needed libraries) as explained in [Goals of the Mathdoc](https://faustdoc.grame.fr/manual/mathdoc/#goals-of-the-mathdoc). 

This website serves as the main documentation of the [Faust libraries](https://github.com/grame-cncm/faustlibraries). The main Faust website can be found at the following URL:

<center>
<a href="https://faust.grame.fr" style="font-size:16pt; font-weight:bold;">https://faust.grame.fr</a>
</center> 

## Using the Faust Libraries

The easiest and most standard way to use the Faust libraries is to import `stdfaust.lib` in your Faust code:

```
import("stdfaust.lib");
```

This will give you access to all the Faust libraries through a series of environments:

* `sf`: `all.lib`
* `aa`: `aanl.lib`
* `an`: `analyzers.lib`
* `ba`: `basics.lib`
* `co`: `compressors.lib`
* `de`: `delays.lib`
* `dm`: `demos.lib`
* `dx`: `dx7.lib`
* `en`: `envelopes.lib`
* `fd`: `fds.lib`
* `fi`: `filters.lib`
* `ho`: `hoa.lib`
* `it`: `interpolators.lib`
* `ma`: `maths.lib`
* `mi`: `mi.lib`
* `ef`: `misceffects.lib`
* `os`: `oscillators.lib`
* `no`: `noises.lib`
* `pf`: `phaflangers.lib`
* `pm`: `physmodels.lib`
* `qu`: `quantizers.lib`
* `rm`: `reducemaps.lib`
* `re`: `reverbs.lib`
* `ro`: `routes.lib`
* `si`: `signals.lib`
* `so`: `soundfiles.lib`
* `sp`: `spats.lib`
* `sy`: `synths.lib`
* `ve`: `vaeffects.lib`
* `vl`: `version.lib`
* `wa`: `webaudio.lib`
* `wd`: `wdmodels.lib`

Environments can then be used as follows in your Faust code:

```
import("stdfaust.lib");
process = os.osc(440);
```

In this case, we're calling the `osc` function from `oscillators.lib`.

You can also access all the functions of all the libraries directly using the `sf` environment:

```
import("stdfaust.lib");
process = sf.osc(440);
```

Alternatively, environments can be created by hand:

```
os = library("oscillators.lib");
process = os.osc(440);
```

Finally, libraries can be simply imported in the Faust code (not recommended):

```
import("oscillators.lib");
process = osc(440);
```

## Organization of This Documentation

The `Overview` tab in the upper menu provides additional information about the general organization of the libraries, licensing/copyright, and guidelines on how to contribute to the Faust libraries. 

The `Libraries` tab contain the actual documentation of the Faust libraries.
