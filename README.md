# Proj4WebGL - Accelerated Geographic Projection for the Web

Proj4WebGL is an experiment in implementing a [PROJ.4][proj4]-compatible
geographic projection system which can be used from within WebGL shaders in a
WebGL-compatible browser. It is designed to be used in combination with the
already existing [Proj4js] port of PROJ.4 to JavaScript.

Like Proj4js it supports automatically fetching projection information from
[spatialreference.org].

## Demo

See [this project's GitHub pages site][demo] for a demo.

## Compilation

This project requires [Python] 3, [HAML] and [CoffeeScript] to be installed on
your computer to re-generate the JavaScript and resource files. A Makefile is
provided.

Note that the ``jsresource.py`` script is the reason for the Python dependency.
It is a simple script to wrap the GLSL source files up into a single JSON file
for use by JavaScript.

## Documentation

For the moment, the Proj4WebGL API is in flux since it is a playground for my
own experimentation. At a high level:

* Initialise a Proj4js ``Proj4.Proj`` object as-per-normal.
* Pass the object to ``Proj4Gl.projectionShaderSource`` which will return a
  string containing GLSL source code to implement the projection.
* See ``coffee/mapviewer.coffee`` for an example.

## Implemented projections

As an experimental project, only a very small number of projections have been
implemented.

* ``aea`` (to lat/lng only, buggy)
* ``cea`` (to lat/lng only)
* ``eqc`` (to/from lat/lng)
* ``laea`` (to/from lat/lng)
* ``lcc`` (to/from lat/lng)
* ``merc`` (to/from lat/lng)
* ``stere`` (to/from lat/lng)
* ``tmerc`` (to/from lat/lng)

[proj4]: http://trac.osgeo.org/proj/
[proj4js]: http://trac.osgeo.org/proj4js/
[spatialreference.org]: http://spatialreference.org/
[demo]: http://rjw57.github.io/proj4webgl/
[python]: http://python.org/
[haml]: http://haml.info/
[coffeescript]: http://coffeescript.org/
