(function() {
  var __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  define(['./script/proj4gl.js', 'dojo/Stateful', './script/webgl-utils.js'], function(Proj4Gl, Stateful) {
    var RasterLayer, createAndCompileShader;
    createAndCompileShader = function(gl, type, source) {
      var shader;
      shader = gl.createShader(type);
      gl.shaderSource(shader, source);
      gl.compileShader(shader);
      if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        console.error('Error compiling shader:');
        console.error(source);
        console.error(gl.getShaderInfoLog(shader));
      }
      return shader;
    };
    RasterLayer = (function(_super) {

      __extends(RasterLayer, _super);

      function RasterLayer(map, textureUrls, description) {
        var _this = this;
        this.map = map;
        this.textureUrls = textureUrls;
        this.description = description;
        this.shaderProgram = null;
        this.texture = null;
        this.visible = true;
        this.map.watch('gl', function(n, o, gl) {
          return _this._glChanged();
        });
        this.map.watch('projection', function(n, o, proj) {
          return _this._projectionChanged();
        });
        this._glChanged();
      }

      RasterLayer.prototype._visibleSetter = function(visible) {
        this.visible = visible;
        return this.map.scheduleRedraw();
      };

      RasterLayer.prototype._glChanged = function() {
        var gl, maxTextureSize, sz, texture, textureSize, textureUrl, url, _i, _len, _ref,
          _this = this;
        if (!(this.map.gl != null)) {
          return;
        }
        gl = this.map.gl;
        maxTextureSize = gl.getParameter(gl.MAX_TEXTURE_SIZE);
        console.log('maximum texture size', maxTextureSize);
        textureSize = 0;
        textureUrl = null;
        _ref = this.textureUrls;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          texture = _ref[_i];
          sz = texture[0];
          url = texture[1];
          if (sz > textureSize && sz <= maxTextureSize) {
            textureSize = sz;
            textureUrl = url;
          }
        }
        if (!(textureUrl != null)) {
          return;
        }
        console.log('using texture url', textureUrl);
        this.texture = gl.createTexture();
        this.texture.image = new Image();
        this.texture.image.onload = function() {
          return _this._textureLoaded();
        };
        this.texture.image.src = textureUrl;
        this.texture.loaded = false;
        this.vertexBuffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, this.vertexBuffer);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 0, -0.5, -0.5, 1, -1, 0, 0.5, -0.5, 1, 1, 0, 0.5, 0.5, -1, 1, 0, -0.5, 0.5]), gl.STATIC_DRAW);
        this.vertexBuffer.stride = 5 * 4;
        this.vertexBuffer.textureOffset = 3 * 4;
        this.vertexBuffer.textureSize = 2;
        this.vertexBuffer.positionOffset = 0 * 4;
        this.vertexBuffer.positionSize = 3;
        this.indexBuffer = gl.createBuffer();
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.indexBuffer);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint16Array([0, 1, 2, 3]), gl.STATIC_DRAW);
        this.indexBuffer.numItems = 4;
        return this._projectionChanged();
      };

      RasterLayer.prototype._projectionChanged = function() {
        var fragmentShader, gl, paramDef, proj, projSource, vertexShader, _i, _len, _ref, _results;
        this.shaderProgram = null;
        if (!(this.map.projection != null) || !(this.map.gl != null)) {
          return;
        }
        proj = this.map.projection;
        gl = this.map.gl;
        projSource = Proj4Gl.projectionShaderSource(proj.projName);
        vertexShader = createAndCompileShader(gl, gl.VERTEX_SHADER, "attribute vec2 aTextureCoord;\nattribute vec3 aVertexPosition;\nvarying vec2 vTextureCoord;\n\nuniform vec2 uViewportSize; // in pixels\nuniform float uScale; // the size of one pixel in projection co-ords\nuniform vec2 uViewportProjectionCenter; // the center of the viewport in projection co-ords\n\nvoid main(void) {\n  vec3 pos = aVertexPosition;\n  gl_Position = vec4(pos, 1.0);\n\n  // convert texture coord in range [-0.5, 0.5) to viewport pixel coord\n  vec2 pixelCoord = aTextureCoord * uViewportSize;\n\n  // convert to projection coordinates\n  vTextureCoord = pixelCoord * uScale - uViewportProjectionCenter;\n}");
        fragmentShader = createAndCompileShader(gl, gl.FRAGMENT_SHADER, "precision mediump float;\n\n// define the projection and projection parameters structure\n" + projSource.source + "\n\nvarying vec2 vTextureCoord;\nuniform sampler2D uSampler;\nuniform " + projSource.paramsStruct.name + " uProjParams;\n\nvoid main(void) {\n  vec2 lonlat = " + projSource.backwardsFunction + "(vTextureCoord, uProjParams);\n  lonlat /= vec2(2.0 * 3.14159, 3.14159);\n  lonlat += vec2(0.5, 0.5);\n  gl_FragColor = texture2D(uSampler, lonlat);\n}");
        this.shaderProgram = gl.createProgram();
        gl.attachShader(this.shaderProgram, vertexShader);
        gl.attachShader(this.shaderProgram, fragmentShader);
        gl.linkProgram(this.shaderProgram);
        if (!gl.getProgramParameter(this.shaderProgram, gl.LINK_STATUS)) {
          throw 'Could not initialise shaders';
        }
        this.shaderProgram.attributes = {
          vertexPosition: gl.getAttribLocation(this.shaderProgram, 'aVertexPosition'),
          textureCoord: gl.getAttribLocation(this.shaderProgram, 'aTextureCoord')
        };
        this.shaderProgram.uniforms = {
          sampler: gl.getUniformLocation(this.shaderProgram, 'uSampler'),
          viewportSize: gl.getUniformLocation(this.shaderProgram, 'uViewportSize'),
          scale: gl.getUniformLocation(this.shaderProgram, 'uScale'),
          viewportProjectionCenter: gl.getUniformLocation(this.shaderProgram, 'uViewportProjectionCenter'),
          projParams: {}
        };
        _ref = projSource.paramsStruct.params;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          paramDef = _ref[_i];
          _results.push(this.shaderProgram.uniforms.projParams[paramDef[0]] = {
            loc: gl.getUniformLocation(this.shaderProgram, 'uProjParams.' + paramDef[0]),
            type: paramDef[1]
          });
        }
        return _results;
      };

      RasterLayer.prototype.drawLayer = function() {
        var gl, k, proj, v, _, _ref, _ref1, _ref2;
        if (!this.visible || !(this.map.gl != null) || !this.map.projection || !(this.shaderProgram != null) || !((_ref = this.texture) != null ? _ref.loaded : void 0)) {
          return;
        }
        gl = this.map.gl;
        proj = this.map.projection;
        gl.useProgram(this.shaderProgram);
        _ref1 = this.shaderProgram.attributes;
        for (_ in _ref1) {
          v = _ref1[_];
          gl.enableVertexAttribArray(v);
        }
        gl.bindBuffer(gl.ARRAY_BUFFER, this.vertexBuffer);
        gl.vertexAttribPointer(this.shaderProgram.attributes.vertexPosition, this.vertexBuffer.positionSize, gl.FLOAT, false, this.vertexBuffer.stride, this.vertexBuffer.positionOffset);
        gl.vertexAttribPointer(this.shaderProgram.attributes.textureCoord, this.vertexBuffer.textureSize, gl.FLOAT, false, this.vertexBuffer.stride, this.vertexBuffer.textureOffset);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.indexBuffer);
        gl.useProgram(this.shaderProgram);
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, this.texture);
        gl.uniform1i(this.shaderProgram.uniforms.sampler, 0);
        gl.uniform2f(this.shaderProgram.uniforms.viewportSize, this.map.element.clientWidth, this.map.element.clientHeight);
        gl.uniform1f(this.shaderProgram.uniforms.scale, this.map.scale);
        gl.uniform2f(this.shaderProgram.uniforms.viewportProjectionCenter, this.map.center.x, this.map.center.y);
        _ref2 = this.shaderProgram.uniforms.projParams;
        for (k in _ref2) {
          v = _ref2[k];
          if (!(proj[k] != null)) {
            continue;
          }
          if (v.type === 'int') {
            gl.uniform1i(v.loc, proj[k]);
          } else if (v.type === 'float') {
            gl.uniform1f(v.loc, proj[k]);
          } else {
            console.error('unknown parameter type for ' + k.toString());
          }
        }
        return gl.drawElements(gl.TRIANGLE_FAN, this.indexBuffer.numItems, gl.UNSIGNED_SHORT, 0);
      };

      RasterLayer.prototype._textureLoaded = function() {
        var gl;
        gl = this.map.gl;
        if (!(gl != null)) {
          throw 'map GL context unavailable';
        }
        gl.bindTexture(gl.TEXTURE_2D, this.texture);
        gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, this.texture.image);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.bindTexture(gl.TEXTURE_2D, null);
        this.texture.loaded = true;
        return this.map.scheduleRedraw();
      };

      return RasterLayer;

    })(Stateful);
    return RasterLayer;
  });

}).call(this);
