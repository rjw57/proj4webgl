define [
  'dojo/request/xhr', './script/proj4gl.js',
  'dojo/Stateful',
  './script/webgl-utils.js'
], (xhr, Proj4Gl, Stateful) ->
  createAndCompileShader = (gl, type, source) ->
    shader = gl.createShader type
    gl.shaderSource shader, source
    gl.compileShader shader

    if not gl.getShaderParameter(shader, gl.COMPILE_STATUS)
      console.error 'Error compiling shader:'
      console.error source
      console.error gl.getShaderInfoLog(shader)

    return shader

  class VectorLayer extends Stateful
    constructor: (@map, @featuresUrl, @description) ->
      @shaderProgram = null
      @featuresLoaded = false
      @visible = true

      @set 'lineColor', {r: 1, g: 0, b: 0}
      @set 'lineWidth', 1

      @map.watch 'gl', (n, o, gl) => @_glChanged()
      @map.watch 'projection', (n, o, proj) => @_projectionChanged()
      @_glChanged() # calls _projectionChanged

    _glChanged: () ->
      @featuresLoaded = false
      @shaderProgram = null
      return if not @map.gl?

      # start loading features
      @featuresLoaded = false
      xhr(@featuresUrl, handleAs: 'json').then (data) => @_featuresLoaded(data)

      @_projectionChanged()

    _lineColorSetter: (@lineColor) ->
      @map.scheduleRedraw()

    _lineWidthSetter: (@lineWidth) ->
      @map.scheduleRedraw()

    _visibleSetter: (@visible)->
      @map.scheduleRedraw()

    _featuresLoaded: (data) ->
      gl = @map.gl
      throw 'Map GL context not available when setting up features' if not gl?

      # the idea of this method is to convert the loaded features into a series of lines
      # which should be drawn. lineCoords is an array of Long, Lat positions of
      # the feature. lineIndices is a set of indices into this array with two
      # entries for each line to be drawn
      lineCoords = []
      lineIndices = []

      if not data.type? or not data.features? or data.type != 'FeatureCollection'
        throw 'Loaded features were not a FeatureCollection'

      for feature in data.features
        if not feature.type? or feature.type != 'Feature'
          console.error 'Invalid feature', feature
          throw 'Feature is invalid'

        # we only care about linestrings
        continue if feature.geometry.type != 'LineString'

        # this will be the index of the first co-ordinate we push
        startIndex = lineCoords.length / 2

        # append the co-ordinates of the line string
        coords = feature.geometry.coordinates
        deg2rad = (2.0 * 3.14159) / 360.0
        for coord in coords
          lineCoords.push coord[0] * deg2rad
          lineCoords.push coord[1] * deg2rad

        # append each line segment NB: range is exclusive of end
        for idx in [1...coords.length]
          lineIndices.push startIndex + idx - 1
          lineIndices.push startIndex + idx

      console.log 'max line index', lineIndices[lineIndices.length-1]

      # create the vertex buffer
      @vertexBuffer = gl.createBuffer()
      gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuffer
      gl.bufferData gl.ARRAY_BUFFER, new Float32Array(lineCoords), gl.STATIC_DRAW
      @vertexBuffer.stride = 2 * 4
      @vertexBuffer.positionOffset = 0 * 4
      @vertexBuffer.positionSize = 2 # co-ords

      # create the index buffer
      @indexBuffer = gl.createBuffer()
      gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @indexBuffer
      gl.bufferData gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(lineIndices), gl.STATIC_DRAW
      @indexBuffer.numItems = lineIndices.length # vertices

      @map.scheduleRedraw()

    _projectionChanged: () ->
      projection = @map.projection
      @shaderProgram = null
      return if not projection? or not @map.gl?
      gl = @map.gl

      # get the shader source for the projection
      projSource = Proj4Gl.projectionShaderSource projection.projName

      # the viewport translation *and* projection is done in the vertex shader
      vertexShader = createAndCompileShader gl, gl.VERTEX_SHADER, """
        attribute vec2 aVertexPosition;

        // define the projection and projection parameters structure
        #{ projSource.source }

        uniform vec2 uViewportSize; // in pixels
        uniform float uScale; // the size of one pixel in projection co-ords
        uniform vec2 uViewportProjectionCenter; // the center of the viewport in projection co-ords
        uniform #{ projSource.paramsStruct.name } uProjParams;

        void main(void) {
          vec2 lnglat = aVertexPosition;
          vec2 xy = #{ projSource.forwardsFunction }(lnglat, uProjParams);

          // convert projection to viewport space
          vec2 screen = 2.0 * vec2(xy + uViewportProjectionCenter) / (uScale * uViewportSize);

          gl_Position = vec4(screen, 0.0, 1.0);
        }
      """

      fragmentShader = createAndCompileShader gl, gl.FRAGMENT_SHADER, """
        precision mediump float;

        uniform vec3 uLineColor;
        void main(void) {
          gl_FragColor = vec4(uLineColor,1);
        }
      """

      # create and link the shader program
      @shaderProgram = gl.createProgram()
      gl.attachShader @shaderProgram, vertexShader
      gl.attachShader @shaderProgram, fragmentShader
      gl.linkProgram @shaderProgram

      if not gl.getProgramParameter(@shaderProgram, gl.LINK_STATUS)
        throw 'Could not initialise shaders'

      # set some fields on the shader to record the location of attributes
      @shaderProgram.attributes = {
        vertexPosition: gl.getAttribLocation(@shaderProgram, 'aVertexPosition')
      }

      @shaderProgram.uniforms = {
        viewportSize: gl.getUniformLocation(@shaderProgram, 'uViewportSize')
        lineColor: gl.getUniformLocation(@shaderProgram, 'uLineColor')
        scale: gl.getUniformLocation(@shaderProgram, 'uScale')
        viewportProjectionCenter:
          gl.getUniformLocation(@shaderProgram, 'uViewportProjectionCenter')
        projParams: { }
      }

      # get the projection parameters
      for paramDef in projSource.paramsStruct.params
        @shaderProgram.uniforms.projParams[paramDef[0]] = {
          loc: gl.getUniformLocation(@shaderProgram, 'uProjParams.' + paramDef[0])
          type: paramDef[1]
        }
        if not @shaderProgram.uniforms.projParams[paramDef[0]].loc
          console.log 'parameter ' + paramDef[0] + ' appears unused'

      # mark the features as being loaded
      @featuresLoaded = true

    # actually draw the scene
    drawLayer: () ->
      return if not @visible or not @shaderProgram? or not @featuresLoaded or not @vertexBuffer?
      gl = @map.gl
      projection = @map.projection

      # enable use of an attribute array for each of the attributes
      gl.useProgram @shaderProgram
      gl.enableVertexAttribArray v for _, v of @shaderProgram.attributes

      # set up the vertex buffer
      gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuffer
      gl.vertexAttribPointer @shaderProgram.attributes.vertexPosition,
        @vertexBuffer.positionSize, gl.FLOAT, false,
        @vertexBuffer.stride, @vertexBuffer.positionOffset

      # set up the index buffer
      gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @indexBuffer

      # set program uniform values
      gl.useProgram @shaderProgram

      gl.lineWidth @lineWidth
      gl.uniform3f @shaderProgram.uniforms.lineColor, @lineColor.r, @lineColor.g, @lineColor.b

      gl.uniform2f @shaderProgram.uniforms.viewportSize, @map.element.clientWidth, @map.element.clientHeight
      gl.uniform1f @shaderProgram.uniforms.scale, @map.scale
      gl.uniform2f @shaderProgram.uniforms.viewportProjectionCenter, @map.center.x, @map.center.y

      for k, v of @shaderProgram.uniforms.projParams
        continue if not projection[k]?
        if v.type == 'int'
          gl.uniform1i v.loc, projection[k]
        else if v.type == 'float'
          gl.uniform1f v.loc, projection[k]
        else
          console.error 'unknown parameter type for ' + k.toString()

      gl.drawElements gl.LINES, @indexBuffer.numItems, gl.UNSIGNED_SHORT, 0

  return VectorLayer
# vim:sw=2:sts=2:et

