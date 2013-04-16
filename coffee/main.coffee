# AMD definition for main
define [
    'dojo/dom', 'dojo/on', 'dojo/Evented', 'dojo/dom-geometry',
    'dojo/dom-construct', 'dojo/dom-attr',
    './script/mapviewer.js', './script/rasterlayer.js',
    './script/vectorlayer.js',
    './script/proj4js-compressed.js',
    'dojo/domReady',
  ], (
    dom, _on, Evented, domGeom,
    domConstruct, domAttr,
    MapViewer, RasterLayer, VectorLayer
  ) ->
    Proj4js.defs['SR-ORG:6864'] = '+proj=merc
      +lon_0=0 +k=1 +x_0=0 +y_0=0 +a=6378137 +b=6378137
      +towgs84=0,0,0,0,0,0,0 +units=m +no_defs'

    Proj4js.defs["SR-ORG:22"] = "+proj=cea
      +lon_0=0 +lat_ts=45 +x_0=0 +y_0=0 +ellps=WGS84
      +units=m +no_defs"

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

    mv = new MapViewer mapCanvas
    
    baseLayer = new RasterLayer mv, 'world.jpg', 'Topography and bathymetry'
    mv.addLayer baseLayer
    
    boundaryLayer = new VectorLayer mv, 'ne_110m_admin_0_boundary_lines_land.json', 'Boundaries'
    boundaryLayer.set 'lineWidth', 1
    boundaryLayer.set 'lineColor', r: 1, g: 0, b: 0
    mv.addLayer boundaryLayer

    coastLayer = new VectorLayer mv, 'ne_110m_coastline.json', 'Coastline'
    coastLayer.set 'lineWidth', 2
    coastLayer.set 'lineColor', r: 0, g: 0.5, b: 1
    mv.addLayer coastLayer

    # setup layer toggles
    layerToggles = dom.byId('layerToggles')
    idx = 1
    for layer in mv.layers
      id = 'layerToggle' + idx.toString()
      li = domConstruct.create 'li', null, layerToggles, 'last'

      # checkbox
      input = domConstruct.create 'input', { type: 'checkbox', id: id }, li, 'last'
      if layer.visible
        domAttr.set input, 'checked', 1
      _on input, 'change', ((layer) -> (ev) ->
        layer.set 'visible', domAttr.get(ev.target, 'checked')
      )(layer)

      # label for checkbox
      label = domConstruct.create 'label', { for: id }, li, 'last'
      domConstruct.place document.createTextNode(layer.description), label, 'last'
      idx++

    projSelectChanged = (elem) ->
      opt = elem.options[elem.selectedIndex]
      new Proj4js.Proj opt.value, (proj) ->
        mv.set 'projection', proj

    _on projSelect, 'change', (ev) -> projSelectChanged(ev.target)
    projSelectChanged projSelect

    _on dom.byId('zoomIn'), 'click', (ev) -> mv.set 'scale', mv.scale / 1.1
    _on dom.byId('zoomOut'), 'click', (ev) -> mv.set 'scale', mv.scale * 1.1

    # A class implementing a dragging behaviour
    class Dragging extends Evented
      constructor: (elem) ->
        @isDragging = false
        @mouseMoveListener = null
        @mouseUpListener = null
        @downLocation = null

        _on elem, 'mousedown', (ev) =>
          return if ev.button != 0 or @isDragging
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
      mv.set 'center', x: oldCenter.x + ev.deltaX * mv.scale, y: oldCenter.y - ev.deltaY * mv.scale

    scaleAround = (ev, scale) ->
      # where is the event in the element
      elemBox = domGeom.position ev.target, false
      x = ev.clientX - elemBox.x
      y = ev.clientY - elemBox.y

      # and in projection co-ordinates
      zoomCenter = mv.elementToProjection x: x, y: y

      mv.set 'scale', scale

      # now where is the zoom center?
      newZoomCenter = mv.elementToProjection x: x, y: y

      # translate the map to move the zoom center back where it was
      mv.set 'center', x: mv.center.x + newZoomCenter.x - zoomCenter.x, y: mv.center.y + newZoomCenter.y - zoomCenter.y

    _on mapCanvas, 'mousewheel', (ev) ->
      if ev.wheelDelta < 0
        scaleAround ev, mv.scale * 1.1
      else if ev.wheelDelta > 0
        scaleAround ev, mv.scale / 1.1
      ev.preventDefault()

    # for firefox
    _on mapCanvas, 'wheel', (ev) ->
      if ev.deltaY > 0
        scaleAround ev, mv.scale * 1.1
      else if ev.deltaY < 0
        scaleAround ev, mv.scale / 1.1
      ev.preventDefault()

# vim:sw=2:sts=2:et
