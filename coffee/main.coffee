# AMD definition for main
define [
    'dojo/dom', 'dojo/on', 'dojo/Evented', 'dojo/dom-geometry',
    './mapviewer',
    './script/proj4js-combined.js',
    'dojo/domReady',
  ], (dom, _on, Evented, domGeom, MapViewer) ->
    Proj4js.defs['SR-ORG:6864'] = '+proj=merc
      +lon_0=0 +k=1 +x_0=0 +y_0=0 +a=6378137 +b=6378137
      +towgs84=0,0,0,0,0,0,0 +units=m +no_defs'

    projDef = 'EPSG:27700'
    projDef = 'EPSG:3031'
    projDef = 'EPSG:2163'
    projDef = 'SR-ORG:6864'

    projSelect = dom.byId('projection')
    mapCanvas = dom.byId('mapCanvas')
    mapCanvas.width = mapCanvas.clientWidth
    mapCanvas.height = mapCanvas.clientHeight
    _on window, 'resize', () ->
      mapCanvas.width = mapCanvas.clientWidth
      mapCanvas.height = mapCanvas.clientHeight
      mv.scheduleRedraw()

    mv = new MapViewer mapCanvas, '../world.jpg'

    projSelectChanged = (elem) ->
      opt = elem.options[elem.selectedIndex]
      new Proj4js.Proj opt.value, (proj) ->
        mv.setProjection proj

    _on projSelect, 'change', (ev) -> projSelectChanged(ev.target)
    projSelectChanged projSelect

    _on dom.byId('zoomIn'), 'click', (ev) -> mv.setScale mv.scale / 1.1
    _on dom.byId('zoomOut'), 'click', (ev) -> mv.setScale mv.scale * 1.1

    # A class implementing a dragging behaviour
    class Dragging extends Evented
      constructor: (elem) ->
        @isDragging = false
        @mouseMoveListener = null
        @mouseUpListener = null
        @downLocation = null

        _on elem, 'mousedown', (ev) =>
          @isDragging = true
          @downLocation = { x: ev.clientX, y: ev.clientY }
          @emit 'dragstart', target: elem, controller: this
          @mouseMoveListener = _on document, 'mousemove', (ev) =>
            return if not @isDragging
            @emit 'dragmove', target: elem, controller: this, \
              deltaX: ev.clientX - @downLocation.x, deltaY: ev.clientY - @downLocation.y
          @mouseUpListener = _on document, 'mouseup', (ev) =>
            @isDragging = false
            @mouseMoveListener.remove()
            @mouseMoveListener = null
            @mouseUpListener.remove()
            @mouseUpListener = null
            @emit 'dragstop', target: elem, controller: this

    oldCenter = null
    dragging = new Dragging mapCanvas
    dragging.on 'dragstart', (ev) -> oldCenter = mv.center
    dragging.on 'dragmove', (ev) ->
      mv.setCenter x: oldCenter.x + ev.deltaX * mv.scale, y: oldCenter.y - ev.deltaY * mv.scale

    _on mapCanvas, 'mousewheel', (ev) ->
      # where is the event in the element
      elemBox = domGeom.position ev.target, false
      canvasX = ev.clientX - elemBox.x
      canvasY = ev.clientY - elemBox.y

      # and in projection co-ordinates
      zoomCenter = mv.elementToProjection x: canvasX, y: canvasY

      if ev.wheelDelta < 0
        mv.setScale mv.scale * 1.1
      else if ev.wheelDelta > 0
        mv.setScale mv.scale / 1.1

      # now where is the zoom center?
      newZoomCenter = mv.elementToProjection x: canvasX, y: canvasY

      # translate the map to move the zoom centre back where it was
      mv.setCenter x: mv.center.x + newZoomCenter.x - zoomCenter.x, y: mv.center.y + newZoomCenter.y - zoomCenter.y

      ev.preventDefault()

# vim:sw=2:sts=2:et
