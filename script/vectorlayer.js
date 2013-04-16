(function() {
  var __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  define(['dojo/request/xhr', './script/proj4gl.js', 'dojo/Stateful', './script/webgl-utils.js'], function(xhr, Proj4Gl, Stateful) {
    var VectorLayer, createAndCompileShader;
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
    VectorLayer = (function(_super) {

      __extends(VectorLayer, _super);

      function VectorLayer(map, featuresUrl, description) {
        var _this = this;
        this.map = map;
        this.featuresUrl = featuresUrl;
        this.description = description;
        this.gl = null;
        this.shaderProgram = null;
        this.featuresLoaded = false;
        this.visible = true;
        this.set('lineColor', {
          r: 1,
          g: 0,
          b: 0
        });
        this.set('lineWidth', 1);
        this.map.watch('gl', function(n, o, gl) {
          return _this.setGl(gl);
        });
        this.map.watch('projection', function(n, o, proj) {
          return _this.setProjection(proj);
        });
        this.setGl(this.map.gl);
      }

      VectorLayer.prototype.setGl = function(gl) {
        var _this = this;
        this.gl = gl;
        if (!(this.gl != null)) {
          return;
        }
        this.featuresLoaded = false;
        xhr(this.featuresUrl, {
          handleAs: 'json'
        }).then(function(data) {
          return _this._featuresLoaded(data);
        });
        return this.setProjection(this.map.projection);
      };

      VectorLayer.prototype._lineColorSetter = function(lineColor) {
        this.lineColor = lineColor;
        return this.map.scheduleRedraw();
      };

      VectorLayer.prototype._lineWidthSetter = function(lineWidth) {
        this.lineWidth = lineWidth;
        return this.map.scheduleRedraw();
      };

      VectorLayer.prototype._visibleSetter = function(visible) {
        this.visible = visible;
        return this.map.scheduleRedraw();
      };

      VectorLayer.prototype._featuresLoaded = function(data) {
        var coord, coords, deg2rad, feature, idx, lineCoords, lineIndices, startIndex, _i, _j, _k, _len, _len1, _ref, _ref1;
        lineCoords = [];
        lineIndices = [];
        if (!(data.type != null) || !(data.features != null) || data.type !== 'FeatureCollection') {
          throw 'Loaded features were not a FeatureCollection';
        }
        _ref = data.features;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          feature = _ref[_i];
          if (!(feature.type != null) || feature.type !== 'Feature') {
            console.error('Invalid feature', feature);
            throw 'Feature is invalid';
          }
          if (feature.geometry.type !== 'LineString') {
            continue;
          }
          startIndex = lineCoords.length / 2;
          coords = feature.geometry.coordinates;
          deg2rad = (2.0 * 3.14159) / 360.0;
          for (_j = 0, _len1 = coords.length; _j < _len1; _j++) {
            coord = coords[_j];
            lineCoords.push(coord[0] * deg2rad);
            lineCoords.push(coord[1] * deg2rad);
          }
          for (idx = _k = 1, _ref1 = coords.length; 1 <= _ref1 ? _k < _ref1 : _k > _ref1; idx = 1 <= _ref1 ? ++_k : --_k) {
            lineIndices.push(startIndex + idx - 1);
            lineIndices.push(startIndex + idx);
          }
        }
        console.log('max line index', lineIndices[lineIndices.length - 1]);
        this.vertexBuffer = this.gl.createBuffer();
        this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.vertexBuffer);
        this.gl.bufferData(this.gl.ARRAY_BUFFER, new Float32Array(lineCoords), this.gl.STATIC_DRAW);
        this.vertexBuffer.stride = 2 * 4;
        this.vertexBuffer.positionOffset = 0 * 4;
        this.vertexBuffer.positionSize = 2;
        this.indexBuffer = this.gl.createBuffer();
        this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, this.indexBuffer);
        this.gl.bufferData(this.gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(lineIndices), this.gl.STATIC_DRAW);
        this.indexBuffer.numItems = lineIndices.length;
        return this.map.scheduleRedraw();
      };

      VectorLayer.prototype.setProjection = function(proj) {
        var fragmentShader, paramDef, projSource, v, vertexShader, _, _i, _len, _ref, _ref1;
        this.proj = proj;
        this.shaderProgram = null;
        if (!(this.proj != null)) {
          return;
        }
        projSource = Proj4Gl.projectionShaderSource(this.proj.projName);
        vertexShader = createAndCompileShader(this.gl, this.gl.VERTEX_SHADER, "attribute vec2 aVertexPosition;\n\n// define the projection and projection parameters structure\n" + projSource.source + "\n\nuniform vec2 uViewportSize; // in pixels\nuniform float uScale; // the size of one pixel in projection co-ords\nuniform vec2 uViewportProjectionCenter; // the center of the viewport in projection co-ords\nuniform " + projSource.paramsStruct.name + " uProjParams;\n\nvoid main(void) {\n  vec2 lnglat = aVertexPosition;\n  vec2 xy = " + projSource.forwardsFunction + "(lnglat, uProjParams);\n\n  // convert projection to viewport space\n  vec2 screen = 2.0 * vec2(xy + uViewportProjectionCenter) / (uScale * uViewportSize);\n\n  gl_Position = vec4(screen, 0.0, 1.0);\n}");
        fragmentShader = createAndCompileShader(this.gl, this.gl.FRAGMENT_SHADER, "precision mediump float;\n\nuniform vec3 uLineColor;\nvoid main(void) {\n  gl_FragColor = vec4(uLineColor,1);\n}");
        this.shaderProgram = this.gl.createProgram();
        this.gl.attachShader(this.shaderProgram, vertexShader);
        this.gl.attachShader(this.shaderProgram, fragmentShader);
        this.gl.linkProgram(this.shaderProgram);
        if (!this.gl.getProgramParameter(this.shaderProgram, this.gl.LINK_STATUS)) {
          throw 'Could not initialise shaders';
        }
        this.shaderProgram.attributes = {
          vertexPosition: this.gl.getAttribLocation(this.shaderProgram, 'aVertexPosition')
        };
        this.shaderProgram.uniforms = {
          viewportSize: this.gl.getUniformLocation(this.shaderProgram, 'uViewportSize'),
          lineColor: this.gl.getUniformLocation(this.shaderProgram, 'uLineColor'),
          scale: this.gl.getUniformLocation(this.shaderProgram, 'uScale'),
          viewportProjectionCenter: this.gl.getUniformLocation(this.shaderProgram, 'uViewportProjectionCenter'),
          projParams: {}
        };
        _ref = projSource.paramsStruct.params;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          paramDef = _ref[_i];
          this.shaderProgram.uniforms.projParams[paramDef[0]] = {
            loc: this.gl.getUniformLocation(this.shaderProgram, 'uProjParams.' + paramDef[0]),
            type: paramDef[1]
          };
          if (!this.shaderProgram.uniforms.projParams[paramDef[0]].loc) {
            console.log('parameter ' + paramDef[0] + ' appears unused');
          }
        }
        this.gl.useProgram(this.shaderProgram);
        _ref1 = this.shaderProgram.attributes;
        for (_ in _ref1) {
          v = _ref1[_];
          this.gl.enableVertexAttribArray(v);
        }
        return this.featuresLoaded = true;
      };

      VectorLayer.prototype.drawLayer = function() {
        var k, v, _ref;
        if (!this.visible || !(this.shaderProgram != null) || !this.featuresLoaded || !(this.vertexBuffer != null)) {
          return;
        }
        this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.vertexBuffer);
        this.gl.vertexAttribPointer(this.shaderProgram.attributes.vertexPosition, this.vertexBuffer.positionSize, this.gl.FLOAT, false, this.vertexBuffer.stride, this.vertexBuffer.positionOffset);
        this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, this.indexBuffer);
        this.gl.useProgram(this.shaderProgram);
        this.gl.lineWidth(this.lineWidth);
        this.gl.uniform3f(this.shaderProgram.uniforms.lineColor, this.lineColor.r, this.lineColor.g, this.lineColor.b);
        this.gl.uniform2f(this.shaderProgram.uniforms.viewportSize, this.map.element.clientWidth, this.map.element.clientHeight);
        this.gl.uniform1f(this.shaderProgram.uniforms.scale, this.map.scale);
        this.gl.uniform2f(this.shaderProgram.uniforms.viewportProjectionCenter, this.map.center.x, this.map.center.y);
        _ref = this.shaderProgram.uniforms.projParams;
        for (k in _ref) {
          v = _ref[k];
          if (!(this.proj[k] != null)) {
            continue;
          }
          if (v.type === 'int') {
            this.gl.uniform1i(v.loc, this.proj[k]);
          } else if (v.type === 'float') {
            this.gl.uniform1f(v.loc, this.proj[k]);
          } else {
            console.error('unknown parameter type for ' + k.toString());
          }
        }
        return this.gl.drawElements(this.gl.LINES, this.indexBuffer.numItems, this.gl.UNSIGNED_SHORT, 0);
      };

      return VectorLayer;

    })(Stateful);
    return VectorLayer;
  });

}).call(this);
