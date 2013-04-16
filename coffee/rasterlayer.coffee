define [
  './script/proj4gl.js',
  'dojo/Stateful',
  './script/webgl-utils.js'
], (Proj4Gl, Stateful) ->
  createAndCompileShader = (gl, type, source) ->
    shader = gl.createShader type
    gl.shaderSource shader, source
    gl.compileShader shader

    if not gl.getShaderParameter(shader, gl.COMPILE_STATUS)
      console.error 'Error compiling shader:'
      console.error source
      console.error gl.getShaderInfoLog(shader)

    return shader

  class RasterLayer extends Stateful
    constructor: (@map, @textureUrls, @description) ->
      @shaderProgram = null
      @texture = null
      @visible = true

      @map.watch 'gl', (n, o, gl) => @_glChanged()
      @map.watch 'projection', (n, o, proj) => @_projectionChanged()
      @_glChanged() # calls _projectionChanged

    _visibleSetter: (@visible)->
      @map.scheduleRedraw()

    _glChanged: () ->
      return if not @map.gl?
      gl = @map.gl

      maxTextureSize = gl.getParameter(gl.MAX_TEXTURE_SIZE)
      console.log 'maximum texture size', maxTextureSize
      textureSize = 0
      textureUrl = null
      for texture in @textureUrls
        sz = texture[0]
        url = texture[1]
        if sz > textureSize and sz <= maxTextureSize
          textureSize = sz
          textureUrl = url

      return if not textureUrl?
      console.log 'using texture url', textureUrl

      # create and load the image texture
      @texture = gl.createTexture()
      @texture.image = new Image()
      @texture.image.onload = () => @_textureLoaded()
      @texture.image.src = textureUrl
      @texture.loaded = false

      # create the vertex and texture co-ordinate buffer for a full-screen quad
      # the first 3 co-ordinates are the position of vertex, the last two are the texture co-ord
      @vertexBuffer = gl.createBuffer()
      gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuffer
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
        -1, -1, 0,    -0.5, -0.5,
         1, -1, 0,     0.5, -0.5,
         1,  1, 0,     0.5,  0.5,
        -1,  1, 0,    -0.5,  0.5,
      ]), gl.STATIC_DRAW)

      # record the strides, sizes and offsets of the various components for later use
      @vertexBuffer.stride = 5 * 4
      @vertexBuffer.textureOffset = 3 * 4
      @vertexBuffer.textureSize = 2
      @vertexBuffer.positionOffset = 0 * 4
      @vertexBuffer.positionSize = 3

      # an index buffer for drawing two triangles (as a fan) covering the quad
      @indexBuffer = gl.createBuffer()
      gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @indexBuffer
      gl.bufferData gl.ELEMENT_ARRAY_BUFFER, new Uint16Array([
        0, 1, 2, 3
      ]), gl.STATIC_DRAW
      @indexBuffer.numItems = 4 # vertices

      @_projectionChanged()

    _projectionChanged: () ->
      @shaderProgram = null
      return if not @map.projection? or not @map.gl?
      proj = @map.projection
      gl = @map.gl

      # get the shader source for the projection
      projSource = Proj4Gl.projectionShaderSource proj.projName

      # the viewport translation is done in the vertex shader
      vertexShader = createAndCompileShader gl, gl.VERTEX_SHADER, """
        attribute vec2 aTextureCoord;
        attribute vec3 aVertexPosition;
        varying vec2 vTextureCoord;

        uniform vec2 uViewportSize; // in pixels
        uniform float uScale; // the size of one pixel in projection co-ords
        uniform vec2 uViewportProjectionCenter; // the center of the viewport in projection co-ords

        void main(void) {
          vec3 pos = aVertexPosition;
          gl_Position = vec4(pos, 1.0);

          // convert texture coord in range [-0.5, 0.5) to viewport pixel coord
          vec2 pixelCoord = aTextureCoord * uViewportSize;

          // convert to projection coordinates
          vTextureCoord = pixelCoord * uScale - uViewportProjectionCenter;
        }
      """

      fragmentShader = createAndCompileShader gl, gl.FRAGMENT_SHADER, """
        precision mediump float;

        // define the projection and projection parameters structure
        #{ projSource.source }

        varying vec2 vTextureCoord;
        uniform sampler2D uSampler;
        uniform #{ projSource.paramsStruct.name } uProjParams;

        void main(void) {
          vec2 lonlat = #{ projSource.backwardsFunction }(vTextureCoord, uProjParams);
          lonlat /= vec2(2.0 * 3.14159, 3.14159);
          lonlat += vec2(0.5, 0.5);
          gl_FragColor = texture2D(uSampler, lonlat);
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
        textureCoord: gl.getAttribLocation(@shaderProgram, 'aTextureCoord')
      }

      @shaderProgram.uniforms = {
        sampler: gl.getUniformLocation(@shaderProgram, 'uSampler')
        viewportSize: gl.getUniformLocation(@shaderProgram, 'uViewportSize')
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

    # actually draw the scene
    drawLayer: () ->
      return if not @visible or not @map.gl? or not @map.projection or not @shaderProgram? or not @texture?.loaded
      gl = @map.gl
      proj = @map.projection

      # enable use of an attribute array for each of the attributes
      gl.useProgram @shaderProgram
      gl.enableVertexAttribArray v for _, v of @shaderProgram.attributes

      # set up the vertex buffer
      gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuffer
      gl.vertexAttribPointer @shaderProgram.attributes.vertexPosition,
        @vertexBuffer.positionSize, gl.FLOAT, false,
        @vertexBuffer.stride, @vertexBuffer.positionOffset
      gl.vertexAttribPointer @shaderProgram.attributes.textureCoord,
        @vertexBuffer.textureSize, gl.FLOAT, false,
        @vertexBuffer.stride, @vertexBuffer.textureOffset

      # set up the index buffer
      gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @indexBuffer

      # set program uniform values
      gl.useProgram @shaderProgram

      gl.activeTexture gl.TEXTURE0
      gl.bindTexture gl.TEXTURE_2D, @texture
      gl.uniform1i @shaderProgram.uniforms.sampler, 0 # tex unit 0

      gl.uniform2f @shaderProgram.uniforms.viewportSize, @map.element.clientWidth, @map.element.clientHeight
      gl.uniform1f @shaderProgram.uniforms.scale, @map.scale
      gl.uniform2f @shaderProgram.uniforms.viewportProjectionCenter, @map.center.x, @map.center.y

      for k, v of @shaderProgram.uniforms.projParams
        continue if not proj[k]?
        if v.type == 'int'
          gl.uniform1i v.loc, proj[k]
        else if v.type == 'float'
          gl.uniform1f v.loc, proj[k]
        else
          console.error 'unknown parameter type for ' + k.toString()

      # draw the quad
      gl.drawElements gl.TRIANGLE_FAN, @indexBuffer.numItems, gl.UNSIGNED_SHORT, 0

    # set up the map texture
    _textureLoaded: () ->
      gl = @map.gl
      throw 'map GL context unavailable' if not gl?

      gl.bindTexture gl.TEXTURE_2D, @texture
      gl.pixelStorei gl.UNPACK_FLIP_Y_WEBGL, true
      gl.texImage2D gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, @texture.image
      gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST
      gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST
      # set wrap mode appropriate for latlon images
      gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT
      gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE
      gl.bindTexture gl.TEXTURE_2D, null

      @texture.loaded = true
      @map.scheduleRedraw()

  return RasterLayer
# vim:sw=2:sts=2:et

