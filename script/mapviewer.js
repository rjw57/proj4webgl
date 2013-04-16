(function() {
  var __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  define(['./script/proj4gl.js', 'dojo/on', 'dojo/Stateful', './script/webgl-utils.js'], function(Proj4Gl, _on, Stateful) {
    var MapViewer;
    MapViewer = (function(_super) {

      __extends(MapViewer, _super);

      function MapViewer(element, proj) {
        var gl;
        this.element = element;
        this.proj = proj;
        this.layers = [];
        this.redrawScheduled = false;
        gl = WebGLUtils.setupWebGL(this.element);
        if (!(gl != null)) {
          return;
        }
        gl.clearColor(0, 0, 0, 1);
        this.set('gl', gl);
        this.set('scale', 4e7 / this.element.clientWidth);
        this.set('center', {
          x: 0,
          y: 0
        });
      }

      MapViewer.prototype.addLayer = function(layer) {
        return this.layers.push(layer);
      };

      MapViewer.prototype.scheduleRedraw = function() {
        var _this = this;
        if (this.redrawScheduled) {
          return;
        }
        requestAnimFrame(function() {
          if (!_this.redrawScheduled) {
            return;
          }
          _this.redrawScheduled = false;
          return _this.drawScene();
        });
        return this.redrawScheduled = true;
      };

      MapViewer.prototype._scaleSetter = function(s) {
        this.scale = s;
        return this.scheduleRedraw();
      };

      MapViewer.prototype._centerSetter = function(c) {
        this.center = c;
        return this.scheduleRedraw();
      };

      MapViewer.prototype._projectionSetter = function(proj) {
        this.proj = proj;
        this.shaderProgram = null;
        return this.scheduleRedraw();
      };

      MapViewer.prototype.drawScene = function() {
        var layer, _i, _len, _ref, _results;
        this.gl.viewport(0, 0, this.gl.drawingBufferWidth, this.gl.drawingBufferHeight);
        this.gl.clear(this.gl.COLOR_BUFFER_BIT | this.gl.DEPTH_BUFFER_BIT);
        _ref = this.layers;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          layer = _ref[_i];
          _results.push(layer.drawLayer());
        }
        return _results;
      };

      MapViewer.prototype.elementToProjection = function(p) {
        return {
          x: (p.x - 0.5 * this.element.clientWidth) * this.scale - this.center.x,
          y: (0.5 * this.element.clientHeight - p.y) * this.scale - this.center.y
        };
      };

      MapViewer.prototype.projectionToElement = function(p) {
        return {
          x: 0.5 * this.element.clientWidth + (p.x + this.center.x) / this.scale,
          y: 0.5 * this.element.clientHeight - (p.y + this.center.y) / this.scale
        };
      };

      return MapViewer;

    })(Stateful);
    return MapViewer;
  });

}).call(this);
