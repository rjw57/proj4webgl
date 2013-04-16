(function() {
  var __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  define(['dojo/dom', 'dojo/on', 'dojo/Evented', 'dojo/dom-geometry', './script/mapviewer.js', './script/rasterlayer.js', './script/vectorlayer.js', './script/proj4js-combined.js', 'dojo/domReady'], function(dom, _on, Evented, domGeom, MapViewer, RasterLayer, VectorLayer) {
    var Dragging, baseLayer, boundaryLayer, coastLayer, dragging, mapCanvas, mv, oldCenter, projDef, projSelect, projSelectChanged, scaleAround;
    Proj4js.defs['SR-ORG:6864'] = '+proj=merc\
      +lon_0=0 +k=1 +x_0=0 +y_0=0 +a=6378137 +b=6378137\
      +towgs84=0,0,0,0,0,0,0 +units=m +no_defs';
    projDef = 'EPSG:27700';
    projDef = 'EPSG:3031';
    projDef = 'EPSG:2163';
    projDef = 'SR-ORG:6864';
    projSelect = dom.byId('projection');
    mapCanvas = dom.byId('mapCanvas');
    mapCanvas.width = mapCanvas.clientWidth;
    mapCanvas.height = mapCanvas.clientHeight;
    _on(window, 'resize', function() {
      mapCanvas.width = mapCanvas.clientWidth;
      mapCanvas.height = mapCanvas.clientHeight;
      return mv.scheduleRedraw();
    });
    mv = new MapViewer(mapCanvas);
    baseLayer = new RasterLayer(mv, 'world.jpg');
    mv.addLayer(baseLayer);
    boundaryLayer = new VectorLayer(mv, 'ne_110m_admin_0_boundary_lines_land.json');
    mv.addLayer(boundaryLayer);
    coastLayer = new VectorLayer(mv, 'ne_110m_coastline.json');
    mv.addLayer(coastLayer);
    projSelectChanged = function(elem) {
      var opt;
      opt = elem.options[elem.selectedIndex];
      return new Proj4js.Proj(opt.value, function(proj) {
        return mv.set('projection', proj);
      });
    };
    _on(projSelect, 'change', function(ev) {
      return projSelectChanged(ev.target);
    });
    projSelectChanged(projSelect);
    _on(dom.byId('zoomIn'), 'click', function(ev) {
      return mv.set('scale', mv.scale / 1.1);
    });
    _on(dom.byId('zoomOut'), 'click', function(ev) {
      return mv.set('scale', mv.scale * 1.1);
    });
    Dragging = (function(_super) {

      __extends(Dragging, _super);

      function Dragging(elem) {
        var _this = this;
        this.isDragging = false;
        this.mouseMoveListener = null;
        this.mouseUpListener = null;
        this.downLocation = null;
        _on(elem, 'mousedown', function(ev) {
          if (ev.button !== 0 || _this.isDragging) {
            return;
          }
          _this.isDragging = true;
          _this.downLocation = {
            x: ev.clientX,
            y: ev.clientY
          };
          _this.emit('dragstart', {
            target: elem,
            controller: _this
          });
          _this.mouseMoveListener = _on(document, 'mousemove', function(ev) {
            if (!_this.isDragging) {
              return;
            }
            return _this.emit('dragmove', {
              target: elem,
              controller: _this,
              deltaX: ev.clientX - _this.downLocation.x,
              deltaY: ev.clientY - _this.downLocation.y
            });
          });
          return _this.mouseUpListener = _on(document, 'mouseup', function(ev) {
            _this.isDragging = false;
            _this.mouseMoveListener.remove();
            _this.mouseMoveListener = null;
            _this.mouseUpListener.remove();
            _this.mouseUpListener = null;
            return _this.emit('dragstop', {
              target: elem,
              controller: _this
            });
          });
        });
      }

      return Dragging;

    })(Evented);
    oldCenter = null;
    dragging = new Dragging(mapCanvas);
    dragging.on('dragstart', function(ev) {
      return oldCenter = mv.center;
    });
    dragging.on('dragmove', function(ev) {
      return mv.set('center', {
        x: oldCenter.x + ev.deltaX * mv.scale,
        y: oldCenter.y - ev.deltaY * mv.scale
      });
    });
    scaleAround = function(ev, scale) {
      var elemBox, newZoomCenter, x, y, zoomCenter;
      elemBox = domGeom.position(ev.target, false);
      x = ev.clientX - elemBox.x;
      y = ev.clientY - elemBox.y;
      zoomCenter = mv.elementToProjection({
        x: x,
        y: y
      });
      mv.set('scale', scale);
      newZoomCenter = mv.elementToProjection({
        x: x,
        y: y
      });
      return mv.set('center', {
        x: mv.center.x + newZoomCenter.x - zoomCenter.x,
        y: mv.center.y + newZoomCenter.y - zoomCenter.y
      });
    };
    _on(mapCanvas, 'mousewheel', function(ev) {
      if (ev.wheelDelta < 0) {
        scaleAround(ev, mv.scale * 1.1);
      } else if (ev.wheelDelta > 0) {
        scaleAround(ev, mv.scale / 1.1);
      }
      return ev.preventDefault();
    });
    return _on(mapCanvas, 'wheel', function(ev) {
      if (ev.deltaY < 0) {
        scaleAround(ev, mv.scale * 1.1);
      } else if (ev.deltaY > 0) {
        scaleAround(ev, mv.scale / 1.1);
      }
      return ev.preventDefault();
    });
  });

}).call(this);
