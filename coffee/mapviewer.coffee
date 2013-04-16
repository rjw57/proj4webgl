define [
  './script/proj4gl.js', 'dojo/on', 'dojo/Stateful',
  './script/webgl-utils.js'
], (Proj4Gl, _on, Stateful) ->
  class MapViewer extends Stateful
    constructor: (@element, @projection) ->
      @layers = []
      @redrawScheduled = false

      # Create a WebGL context for this element
      gl = WebGLUtils.setupWebGL(@element)
      return if not gl?

      # set background colour to black
      gl.clearColor(0, 0, 0, 1)

      # set properties
      @set 'gl', gl
      @set 'scale', 4e7 / @element.clientWidth
      @set 'center', { x: 0, y: 0 }

    addLayer: (layer) -> @layers.push layer

    scheduleRedraw: () ->
      return if @redrawScheduled
      requestAnimFrame () =>
        return if not @redrawScheduled
        @redrawScheduled = false
        @drawScene()
      @redrawScheduled = true

    _scaleSetter: (s) ->
      @scale = s
      @scheduleRedraw()

    _centerSetter: (c) ->
      @center = c
      @scheduleRedraw()

    _projectionSetter: (@projection) ->
      @scheduleRedraw()

    # actually draw the scene
    drawScene: () ->
      @gl.viewport 0, 0, @gl.drawingBufferWidth, @gl.drawingBufferHeight
      @gl.clear @gl.COLOR_BUFFER_BIT | @gl.DEPTH_BUFFER_BIT

      for layer in @layers
        layer.drawLayer()

    # convert element relative co-ordinates to projection co-ordinates
    elementToProjection: (p) -> {
      x: (p.x - 0.5*@element.clientWidth) * @scale - @center.x
      y: (0.5*@element.clientHeight - p.y) * @scale - @center.y
    }

    # convert projection co-ordinates to element relative co-ordinates
    projectionToElement: (p) -> {
      x: 0.5*@element.clientWidth + (p.x + @center.x) / @scale
      y: 0.5*@element.clientHeight - (p.y + @center.y) / @scale
    }

  return MapViewer
# vim:sw=2:sts=2:et

