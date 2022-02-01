# Faust Libraries

This repository contains the source code and the documentation of the DSP libraries of the [Faust Programming Language](https://faust.grame.fr). 

Here is the [online documentation](https://faustlibraries.grame.fr) of the Faust libraries (which also serves as a proper README for this repository).

### Prerequisites
- you must have awk and [mkdocs](https://www.mkdocs.org/) installed.
- you must have the Faust source code installed. You can get it from [github](https://github.com/grame-cncm/faust).

###  WARNING: adding new files

Be sure to add new files in the `doc/docs`, and **not** in the `docs` which is the folder generated by the build process.

### Building the documentation

The build process is based on `make` located in the `doc` folder. Building the documentation site is based on [mkdocs](https://www.mkdocs.org/).
To install the required components type:

To generate all these files type:
~~~~~~~~~~~~~~~~
$ make install
~~~~~~~~~~~~~~~~

### Testing and generating

You can test the web site using the mkdoc embedded web server. This server also scan any change in the source directory and refresh the pages dynamically which is really convenient for the development process. To launch the server type:
~~~~~~~~~~~~~~~~
$ make serve
~~~~~~~~~~~~~~~~

When ready, you can generate the documentation web site. Type:
~~~~~~~~~~~~~~~~
$ make build
~~~~~~~~~~~~~~~~
The web site will be available from the `docs` folder at the root of the `faustlibraries` folder

More details on the build process:
~~~~~~~~~~~~~~~~
$ make help
~~~~~~~~~~~~~~~~

### Publishing 

The docs folder at rool level contains all files that will be published. To make the current version publicly available:
- add all the new files using `git add docs`
- commit using `git commit -am "message"` (so new files and deleted files will be commited, except docs/CNAME file) 
- and push the commit

### WARNING!!

- never delete the **docs/CNAME file** (which is mandatory for the final generated site to work)
- in case it has been removed, restore it using `git checkout docs/CNAME`
