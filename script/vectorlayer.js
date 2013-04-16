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
          return _this._glChanged();
        });
        this.map.watch('projection', function(n, o, proj) {
          return _this._projectionChanged();
        });
        this._glChanged();
      }

      VectorLayer.prototype._glChanged = function() {
        var _this = this;
        this.featuresLoaded = false;
        this.shaderProgram = null;
        if (!(this.map.gl != null)) {
          return;
        }
        this.featuresLoaded = false;
        xhr(this.featuresUrl, {
          handleAs: 'json'
        }).then(function(data) {
          return _this._featuresLoaded(data);
        });
        return this._projectionChanged();
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
        var coord, coords, deg2rad, feature, gl, idx, lineCoords, lineIndices, startIndex, _i, _j, _k, _len, _len1, _ref, _ref1;
        gl = this.map.gl;
        if (!(gl != null)) {
          throw 'Map GL context not available when setting up features';
        }
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
        this.vertexBuffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, this.vertexBuffer);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(lineCoords), gl.STATIC_DRAW);
        this.vertexBuffer.stride = 2 * 4;
        this.vertexBuffer.positionOffset = 0 * 4;
        this.vertexBuffer.positionSize = 2;
        this.indexBuffer = gl.createBuffer();
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.indexBuffer);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(lineIndices), gl.STATIC_DRAW);
        this.indexBuffer.numItems = lineIndices.length;
        return this.map.scheduleRedraw();
      };

      VectorLayer.prototype._projectionChanged = function() {
        var fragmentShader, gl, paramDef, projSource, projection, vertexShader, _i, _len, _ref;
        projection = this.map.projection;
        this.shaderProgram = null;
        if (!(projection != null) || !(this.map.gl != null)) {
          return;
        }
        gl = this.map.gl;
        projSource = Proj4Gl.projectionShaderSource(projection.projName);
        vertexShader = createAndCompileShader(gl, gl.VERTEX_SHADER, "attribute vec2 aVertexPosition;\n\n// define the projection and projection parameters structure\n" + projSource.source + "\n\nuniform vec2 uViewportSize; // in pixels\nuniform float uScale; // the size of one pixel in projection co-ords\nuniform vec2 uViewportProjectionCenter; // the center of the viewport in projection co-ords\nuniform " + projSource.paramsStruct.name + " uProjParams;\n\nvoid main(void) {\n  vec2 lnglat = aVertexPosition;\n  vec2 xy = " + projSource.forwardsFunction + "(lnglat, uProjParams);\n\n  // convert projection to viewport space\n  vec2 screen = 2.0 * vec2(xy + uViewportProjectionCenter) / (uScale * uViewportSize);\n\n  gl_Position = vec4(screen, 0.0, 1.0);\n}");
        fragmentShader = createAndCompileShader(gl, gl.FRAGMENT_SHADER, "precision mediump float;\n\nuniform vec3 uLineColor;\nvoid main(void) {\n  gl_FragColor = vec4(uLineColor,1);\n}");
        this.shaderProgram = gl.createProgram();
        gl.attachShader(this.shaderProgram, vertexShader);
        gl.attachShader(this.shaderProgram, fragmentShader);
        gl.linkProgram(this.shaderProgram);
        if (!gl.getProgramParameter(this.shaderProgram, gl.LINK_STATUS)) {
          throw 'Could not initialise shaders';
        }
        this.shaderProgram.attributes = {
          vertexPosition: gl.getAttribLocation(this.shaderProgram, 'aVertexPosition')
        };
        this.shaderProgram.uniforms = {
          viewportSize: gl.getUniformLocation(this.shaderProgram, 'uViewportSize'),
          lineColor: gl.getUniformLocation(this.shaderProgram, 'uLineColor'),
          scale: gl.getUniformLocation(this.shaderProgram, 'uScale'),
          viewportProjectionCenter: gl.getUniformLocation(this.shaderProgram, 'uViewportProjectionCenter'),
          projParams: {}
        };
        _ref = projSource.paramsStruct.params;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          paramDef = _ref[_i];
          this.shaderProgram.uniforms.projParams[paramDef[0]] = {
            loc: gl.getUniformLocation(this.shaderProgram, 'uProjParams.' + paramDef[0]),
            type: paramDef[1]
          };
          if (!this.shaderProgram.uniforms.projParams[paramDef[0]].loc) {
            console.log('parameter ' + paramDef[0] + ' appears unused');
          }
        }
        return this.featuresLoaded = true;
      };

      VectorLayer.prototype.drawLayer = function() {
        var gl, k, projection, v, _, _ref, _ref1;
        if (!this.visible || !(this.shaderProgram != null) || !this.featuresLoaded || !(this.vertexBuffer != null)) {
          return;
        }
        gl = this.map.gl;
        projection = this.map.projection;
        gl.useProgram(this.shaderProgram);
        _ref = this.shaderProgram.attributes;
        for (_ in _ref) {
          v = _ref[_];
          gl.enableVertexAttribArray(v);
        }
        gl.bindBuffer(gl.ARRAY_BUFFER, this.vertexBuffer);
        gl.vertexAttribPointer(this.shaderProgram.attributes.vertexPosition, this.vertexBuffer.positionSize, gl.FLOAT, false, this.vertexBuffer.stride, this.vertexBuffer.positionOffset);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.indexBuffer);
        gl.useProgram(this.shaderProgram);
        gl.lineWidth(this.lineWidth);
        gl.uniform3f(this.shaderProgram.uniforms.lineColor, this.lineColor.r, this.lineColor.g, this.lineColor.b);
        gl.uniform2f(this.shaderProgram.uniforms.viewportSize, this.map.element.clientWidth, this.map.element.clientHeight);
        gl.uniform1f(this.shaderProgram.uniforms.scale, this.map.scale);
        gl.uniform2f(this.shaderProgram.uniforms.viewportProjectionCenter, this.map.center.x, this.map.center.y);
        _ref1 = this.shaderProgram.uniforms.projParams;
        for (k in _ref1) {
          v = _ref1[k];
          if (!(projection[k] != null)) {
            continue;
          }
          if (v.type === 'int') {
            gl.uniform1i(v.loc, projection[k]);
          } else if (v.type === 'float') {
            gl.uniform1f(v.loc, projection[k]);
          } else {
            console.error('unknown parameter type for ' + k.toString());
          }
        }
        return gl.drawElements(gl.LINES, this.indexBuffer.numItems, gl.UNSIGNED_SHORT, 0);
      };

      return VectorLayer;

    })(Stateful);
    return VectorLayer;
  });

}).call(this);
