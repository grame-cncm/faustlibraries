# General Organization

Only the libraries that are considered to be "standard" are documented:

* `aanl.lib`
* `analyzers.lib`
* `basics.lib`
* `compressors.lib`
* `delays.lib`
* `demos.lib`
* `dx7.lib`
* `envelopes.lib`
* `fds.lib`
* `filters.lib`
* `hoa.lib`
* `interpolators.lib`
* `maths.lib`
* `mi.lib`
* `misceffects.lib`
* `oscillators.lib`
* `noises.lib`
* `phaflangers.lib`
* `physmodels.lib`
* `reducemaps.lib`
* `reverbs.lib`
* `routes.lib`
* `signals.lib`
* `soundfiles.lib`
* `spats.lib`
* `synths.lib`
* `tonestacks.lib` (not documented but example in `/examples/misc`)
* `tubes.lib` (not documented but example in `/examples/misc`)
* `vaeffects.lib`
* `version.lib`
* `wdmodels.lib`
* `webaudio.lib`

Other deprecated libraries such as `music.lib`, etc. are present but are not documented to not confuse new users.

The documentation of each library can be found in `/documentation/library.html` or in `/documentation/library.pdf`. 

### Versioning

A global `version` number for the standard libraries is defined in `version.lib`. 
It follows the semantic versioning structure: MAJOR, MINOR, PATCH. The MAJOR number is increased when we make incompatible changes. The MINOR number is increased when we add functionality in a backwards compatible manner, and the PATCH number when we make backwards compatible bug fixes. By looking at the generated code or the diagram of `process = vl.version;` one can see the current version of the libraries.

### Examples

The Faust distribution `/examples` directory contains a lot of DSP examples. They are organized by types in different folders. The `/examples/old` folder contains examples that are fully deprecated, probably because they were integrated to the libraries and fully rewritten (see `freeverb.dsp` for example). 

Examples using deprecated libraries were integrated to the general tree, but a warning comment was added at their beginning to point readers to the right library and function.
