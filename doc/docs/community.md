# Libraries from the community

A lot of libraries have been developed by the community. They can be used when developing DSP programs:

- when used in [Faust IDE](https://faustide.grame.fr), by adding them in the [project files](https://github.com/grame-cncm/faustide#project-files) section
- when used in a local Faust installation on macOS or Linux, by adding them in the `/usr/share/faust`, or `/usr/local/share/faust` folders

They are presented in the following sections. 

## [abclib library](https://github.com/alainbonardi/abclib/)

20 years of research, teaching and creation in mixed music using Faust language.

abclib library is released by the CICM / MUSIDANSE (Centre de Recherches Informatique et Création Musicale, Paris 8 University) and is the result of 20 years of research, teaching and creation in mixed music, expressed as a set of codes in Faust language. The main topics addressed are: spatial sound processing and synthesis using ambisonics, multi-channel sound processing, utility objects for mixed music.

## [Edge of Chaos](https://github.com/dariosanfilippo/edgeofchaos)

This repository contains libraries including some essential building blocks for the implementation of musical complex adaptive systems in Faust programming.

It includes a set of time-domain algorithms, some of which are original, for the processing of low-level and high-level information as well as the processing of sound using standard and non-conventional techniques. It also includes functions for the realisation of networks with different topologies, linear and nonlinear mapping strategies to render positive and negative feedback relationships, and different kinds of energy-preserving techniques for the stability of self-oscillating systems.

## [realfaust](https://github.com/dariosanfilippo/realfaust)

This library contains a set of functions representing domain-limited versions of all Faust primitives and math functions that can potentially generate INF or NaN values. The goal of the library is to be able to implement DSP networks that, structurally, are free from INF and NaN values. Hence, the resulting programs should be rock-solid during real-time performance and virtually immune to crashes regardless of how mercilessly a network is modulated or how unstable a recursive system is made.

## [bitDSP-faust](https://github.com/rottingsounds/bitDSP-faust)

BitDSP is a set of Faust library functions aimed to help explore and research artistic possibilities of bit-based algorithms. BitDSP currently includes implementations of bit-based functions ranging from simple bit operations over classic delta-sigma modulations to more experimental approaches like cellular automata, recursive Boolean networks, and linear feedback shift registers.

A detailed overview of the functionality is in the [paper](https://ifc20.sciencesconf.org/332745/document) "Creative use of bit-stream DSP in Faust" presented at [IFC 2020](https://ifc20.sciencesconf.org/).

## [SEAM library](https://github.com/s-e-a-m/faust-libraries)

Sustained Electro-Acoustic Music is a project inspired by [Alvise Vidolin and Nicola Bernardini](https://www.academia.edu/16348988/Sustainable_live_electro-acoustic_music). The SEAM libraries have been developed for this project.

## [Ambitools library](http://sekisushai.net/ambitools/)

 Ambitools is an implementation of several Ambisonic tools with the FAUST language. The code is designed to be scalable and flexible, offering tools working at various Ambisonic order and compiled for various architectures. The implementation of the spherical harmonics for an efficient computation is detailed. See the [Ambitools : Tools For Sound Field Synthesis With Higher Order Ambisonic - V1.0](https://hal.archives-ouvertes.fr/hal-03162948/document) paper. 
 
## [Faust Tap Library](https://github.com/nuchi/faust-tap-library/)
Tap a complicated expression to pull out specific outputs, without having to manually route those outputs, just like how named function parameters remove the need to manually route inputs.

## [MoreFilters library](https://codeberg.org/obsoleszenz/morefilters.lib)

A Faust library implementing following highpass/lowpass filters using `fi.svf`:

- Biquad
- Butterworth (2nd, 4th, 6th, 8th order)
- Bessel (2nd, 4th, 6th, 8th order)
- Linkwitz Riley (4th, 8th, 12th and 16th order)

## Awesome library
Feel free to contribute by [forking this project](https://docs.github.com/en/github/collaborating-with-pull-requests/working-with-forks) and [creating a pull request](https://docs.github.com/en/github/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request), or by mailing the library description [here](mailto:research@grame.fr).

# Additional DSP resources

Heres is a list of additional DSP resources.

## Granulation

### A list of projects related to granulation:

- Dario Sanfilippo [Live concatenative granular processing](https://github.com/dariosanfilippo/concatenative_granulation) project

- Mykle Hansen [Weather Organ](https://github.com/myklemykle/weather_organ) project

- Jean-Louis Paquelin [Granola](https://github.com/jlp6k/faust-things) monophonic granular live feed processor

- Mayank Sanganeria [granulator.dsp]( https://github.com/e7mac/faust-code/blob/master/granulator.dsp) project

- Henrik von Coler [material on granulation](http://ringbuffer.org/faust/synthesis_algorithms/granular-faust-example/)

###  Material in the [abclib library](https://github.com/alainbonardi/abclib/)

- basic granulator in Faust [based on a delay line](https://github.com/alainbonardi/abclib/blob/master/faustCodes/library/mm.lib), with the `granulator` function

-  [spatial granulation in ambisonics](https://github.com/alainbonardi/abclib/blob/master/faustCodes/library/abc.lib) in `abc_2d_fx_grain_ui` and `abc_2d_syn_grain_ui` functions

-  [multichannel granulation](https://github.com/alainbonardi/abclib/blob/master/faustCodes/library/abc.lib) in `abc_multigrain_ui` function
