# If we are in Node.js:
if process.env
  Settings = require('../settings/settings')
  {Polygon, Rectangle, Point, Geom} = require('../render/primitives')
  ArrayUtils = require('../util/arrayUtils')

class CircuitElement

  @ps1: new Point(0, 0)
  @ps2: new Point(0, 0)

  point1: new Point(50, 100)
  point2: new Point(50, 150)
  lead1: new Point(0, 100)
  lead2: new Point(0, 150)

  volts = [0, 0]
  current = 0
  curcount = 0

  noDiagonal: false
  selected: false


  constructor: (@x1, @y1, @x2, @y2, flags, st...) ->
    if isNaN(flags)
      @flags = @getDefaultFlags()
    else
      @flags = flags


    @allocNodes()
    @initBoundingBox()

  #initClass: ->
  #  @

  setCircuit: (circuit) ->
    @circuit = circuit

  allocNodes: ->
    @nodes = new Array(@getPostCount() + @getInternalNodeCount())
    @volts = new Array(@getPostCount() + @getInternalNodeCount())

    @nodes = ArrayUtils.zeroArray(@nodes)

  setPoints: ->
    @dx = @x2 - @x
    @dy = @y2 - @y
    @dn = Math.sqrt(@dx * @dx + @dy * @dy)
    @dpx1 = @dy / @dn
    @dpy1 = -@dx / @dn
    @dsign = (if (@dy is 0) then MathUtils.sign(@dx) else MathUtils.sign(@dy))
    @point1 = new Point(@x, @y)
    @point2 = new Point(@x2, @y2)

  setColor: (color) ->
    @color = color

  getDefaultFlags: ->
    0

  getDumpType: ->
    0

  # Todo: implement needed
  getDumpClass: ->
    "Needs implementation"

  toString: ->
    "Circuit Element"

  isSelected: ->
    selected

  initBoundingBox: ->
    @boundingBox = new Rectangle()

    @boundingBox.x1 = Math.min(@x1, @x2);
    @boundingBox.y = Math.min(@y, @y2);
    @boundingBox.width = Math.abs(@x2 - @x1) + 1;
    @boundingBox.height = Math.abs(@y2 - @y) + 1;

    CircuitElement.ps1 = new Point(0, 0)
    CircuitElement.ps2 = new Point(0, 0)

    #			shortFormat = new flash.globalization.NumberFormatter(LocaleID.DEFAULT);
    #			shortFormat.fractionalDigits = 1;
    #			showFormat = new flash.globalization.NumberFormatter(LocaleID.DEFAULT);
    #			showFormat.fractionalDigits = 2;
    #			showFormat.leadingZero = true;
    #			noCommaFormat = new flash.globalization.NumberFormatter(LocaleID.DEFAULT);
    #			noCommaFormat.fractionalDigits = 10;
    #			noCommaFormat.useGrouping = false;


  dump: ->
    getDumpType() + " " + @x1 + " " + @y + " " + @x2 + " " + @y2 + " " + @flags;

  reset: ->
    volts = 0 for volt in volts
    curcount = 0

  setCurrent: (x, current) ->
    @current = current

  getCurrent: ->
    @current

  # Steps forward one frame and performs calculation
  doStep: ->
    # to be extended by subclasses

  destroy: ->
    # TODO: Implement

  startIteration: ->
    # TODO: Implement

  getPostVoltage: (post_idx) ->
    @volts[post_idx]

  setNodeVoltage: (node_idx, voltage) ->
    @volts[node_idx] = voltage
    @calculateCurrent()

  calculateCurrent: ->
    # TODO: Implemented by subclasses

  calcLeads: (len) ->
    if @dn < len or len is 0
      @lead1 = @point1
      @lead2 = @point2
      return

    @lead1 = CircuitElementDrawUtils.interpPointPt(@point1, @point2, (@dn - len) / (2 * @dn));
    @lead2 = CircuitElementDrawUtils.interpPointPt(@point1, @point2, (@dn + len) / (2 * @dn));

  getDefaultFlags: ->
    0

  drag: (xx, yy) ->
    xx = Circuit.snapGrid(xx)
    yy = Circuit.snapGrid(yy)
    if @noDiagonal
      if Math.abs(@x1 - xx) < Math.abs(@y - yy)
        xx = @x1
      else
        yy = @y
    @x2 = xx
    @y2 = yy
    @setPoints()

  move: (dx, dy) ->
    @x1 += dx
    @y += dy
    @x2 += dx
    @y2 += dy
    @boundingBox.x1 += dx
    @boundingBox.y += dy
    @setPoints()

  allowMove: (dx, dy) ->
    nx = @x1 + dx
    ny = @y + dy
    nx2 = @x2 + dx
    ny2 = @y2 + dy

    i = 0
    while i < Circuit.elementList.length
      ce = Circuit.getElm(i)
      return false  if ce.x1 is nx and ce.y is ny and ce.x2 is nx2 and ce.y2 is ny2
      return false  if ce.x1 is nx2 and ce.y is ny2 and ce.x2 is nx and ce.y2 is ny
      ++i
    true

  movePoint: (n, dx, dy) ->
    if n is 0
      @x1 += dx
      @y += dy
    else
      @x2 += dx
      @y2 += dy
    @setPoints()

  stamp: ->
    # to be overridden by subclasses

  getVoltageSourceCount: ->
    0

  getInternalNodeCount: ->
    0

  setNode: (nodeIdx, newValue) ->
    @nodes[nodeIdx] = newValue

  setVoltageSource: (node, value) ->
    @voltSource = v

  getVoltageDiff: ->
    @volts[0] - @volts[1]

  nonlinear: ->
    false

  getPostCount: ->
    2

  getNode: (nodeIdx) ->
    @nodes[nodeIdx]

  getPost: (postIdx) ->
    if postIdx == 0
      return @point1
    else if postIdx == 1
      return @point2

    printStackTrace()

  getBoundingBox: ->
    @boundingBox

  setBbox: (x1, y1, x2, y2) ->
    if x1 > x2
      q = x1
      x1 = x2
      x2 = q
    if y1 > y2
      q = y1
      y1 = y2
      y2 = q
    @boundingBox.x1 = x1
    @boundingBox.y = y1
    @boundingBox.width = x2 - x1 + 1
    @boundingBox.height = y2 - y1 + 1

  setBboxPt: (p1, p2, w) ->
    @setBbox p1.x1, p1.y, p2.x1, p2.y
    dpx = (@dpx1 * w)
    dpy = (@dpy1 * w)
    @adjustBbox p1.x1 + dpx, p1.y + dpy, p1.x1 - dpx, p1.y - dpy

  adjustBbox: (x1, y1, x2, y2) ->
    if x1 > x2
      q = x1
      x1 = x2
      x2 = q
    if y1 > y2
      q = y1
      y1 = y2
      y2 = q
    x1 = Math.min(@boundingBox.x1, x1)
    y1 = Math.min(@boundingBox.y, y1)
    x2 = Math.max(@boundingBox.x1 + @boundingBox.width - 1, x2)
    y2 = Math.max(@boundingBox.y + @boundingBox.height - 1, y2)
    @boundingBox.x1 = x1
    @boundingBox.y = y1
    @boundingBox.width = x2 - x1
    @boundingBox.height = y2 - y1

  adjustBboxPt: (p1, p2) ->
    @adjustBbox p1.x1, p1.y, p2.x1, p2.y

  isCenteredText: ->
    false

  getInfo: (arr) ->
    # Extended by subclasses

    # Extended by subclasses
  getBasicInfo: (arr) ->
    arr[1] = "I = " + CircuitElement.getCurrentDText(@getCurrent())
    arr[2] = "Vd = " + CircuitElement.getVoltageDText(@getVoltageDiff())
    3

  getPower: ->
    @getVoltageDiff() * @current

  getScopeValue: (x) ->
    (if (x is 1) then @getPower() else @getVoltageDiff())

  @getScopeUnits: (x) ->
    (if (x is 1) then "W" else "V")

  # TODO: Implement
  getEditInfo: (n) ->
    null

  # TODO: Implement
  setEditValue: (n, ei) ->

  getConnection: (n1, n2) ->
    true

  hasGroundConnection: (n1) ->
    false

  isWire: ->
    false

  canViewInScope: ->
    @getPostCount() <= 2

  @comparePair: (x1, x2, y1, y2) ->
    (x1 is y1 and x2 is y2) or (x1 is y2 and x2 is y1)

  needsHighlight: ->
    Circuit.mouseElm is this or @selected

  isSelected: ->
    @selected

  setSelected: (selected) ->
    @selected = selected

  selectRect: (r) ->
    @selected = r.intersects(@boundingBox)

  needsShortcut: ->
    false

  toString: ->
    "Root Circuit Element"


  ### #######################################################################
  # RENDERING METHODS
  ### #######################################################################

  draw: ->
    # TODO: Rendering here

    draw2Leads: ->
    color = @setVoltageColor(@volts[0])
    @drawThickLinePt @point1, @lead1, color
    color = @setVoltageColor(@volts[1])
    @drawThickLinePt @lead2, @point2, color

  @updateDotCount: (cur, cc) ->
    cur = @current  if isNaN(cur)
    cc = @curcount  if isNaN(cc)
    return cc  if Circuit.stoppedCheck
    cadd = cur * CircuitElement.currentMult
    cadd %= 8
    @curcount = cadd + cc
    cc + cadd

  @doDots: ->
    @curcount = @updateDotCount()
    @drawDots @point1, @point2, @curcount  unless Circuit.dragElm is this

  # Todo: move to independent drawing class
  drawDots: (pa, pb, pos) ->
    # If the sim is stopped or has dots disabled
    return  if Circuit.stoppedCheck or pos is 0 or not Circuit.dotsCheckItem
    dx = pb.x1 - pa.x1
    dy = pb.y - pa.y
    dn = Math.sqrt(dx * dx + dy * dy)
    ds = 16
    pos %= ds
    pos += ds  if pos < 0
    di = pos

    while di < dn
      x0 = (pa.x1 + di * dx / dn)
      y0 = (pa.y + di * dy / dn)

      # Draws each dot:
      paper.beginPath()
      paper.strokeStyle = Color.color2HexString(Settings.DOTS_OUTLINE)
      paper.fillStyle = Color.color2HexString(Settings.DOTS_COLOR)
      paper.arc x0, y0, Settings.CURRENT_RADIUS, 0, 2 * Math.PI, true
      paper.stroke()
      paper.fill()
      paper.closePath()
      di += ds

  ###
  Todo: Not yet implemented
  ###
  drawCenteredText: (s, x, y, cx) ->

    # todo: test
    fm = undefined
    text = undefined
    w = 10 * s.length #fm.stringWidth(s);
    x -= w / 2  if cx
    ascent = -10 #fm.getAscent() / 2;
    descent = 5 #fm.getAscent() / 2;

    # TODO: CANVAS
    paper.fillStyle = Color.color2HexString(Settings.TEXT_COLOR)
    paper.fillText s, x, y + ascent

    #    text = paper.text(x, y + ascent, s).attr({
    #        cursor:"none",
    #        'font-weight':'bold',
    #        fill:Color.color2HexString(Settings.TEXT_COLOR)
    #    });
    @adjustBbox x, y - ascent, x + w, y + ascent + descent
    text


  ###
  # Todo: Not yet implemented
  ###
  drawValues: (s, hs) ->
    return  unless s?
    w = 100 #fm.stringWidth(s);
    ya = -10 #fm.getAscent() / 2;
    xc = undefined
    yc = undefined
    if this instanceof RailElm or this instanceof SweepElm
      xc = @x2
      yc = @y2
    else
      xc = (@x2 + @x1) / 2
      yc = (@y2 + @y) / 2
    dpx = Math.floor(@dpx1 * hs)
    dpy = Math.floor(@dpy1 * hs)
    offset = 20
    textLabel = undefined
    paper.fillStyle = Color.color2HexString(Settings.TEXT_COLOR)
    if dpx is 0
      # TODO: CANVAS
      paper.fillText s, xc - w / 2 + 3 * offset / 2, yc - Math.abs(dpy) - offset / 3
    else
      xx = xc + Math.abs(dpx) + offset
      xx = xc - (10 + Math.abs(dpx) + offset)  if this instanceof VoltageElm or (@x1 < @x2 and @y > @y2)
      # TODO: CANVAS
      paper.fillText s, xx, yc + dpy + ya
    textLabel

  @drawPosts: ->
    i = 0
    while i < @getPostCount()
      p = @getPost(i)
      @drawPost p.x1, p.y, @nodes[i]
      ++i

  @drawPost: (x0, y0, node) ->
    if node
      return  if not Circuit.dragElm? and not @needsHighlight() and Circuit.getCircuitNode(node).links.length is 2
      return  if Circuit.mouseMode is Circuit.MODE_DRAG_ROW or Circuit.mouseMode is Circuit.MODE_DRAG_COLUMN
    paper.beginPath()
    if @needsHighlight()
      paper.fillStyle = Color.color2HexString(Settings.POST_COLOR_SELECTED)
      paper.strokeStyle = Color.color2HexString(Settings.POST_COLOR_SELECTED)
    else
      paper.fillStyle = Color.color2HexString(Settings.POST_COLOR)
      paper.strokeStyle = Color.color2HexString(Settings.POST_COLOR)
    paper.arc x0, y0, Settings.POST_RADIUS, 0, 2 * Math.PI, true
    paper.stroke()
    paper.fill()
    paper.closePath()

  @setVoltageColor: (volts) ->
    return Settings.SELECT_COLOR  if @needsHighlight()
    return CircuitElement.whiteColor  unless Circuit.powerCheckItem  unless Circuit.voltsCheckItem
    c = Math.floor((volts + CircuitElement.voltageRange) * (CircuitElement.colorScaleCount - 1) / (CircuitElement.voltageRange * 2))
    c = 0  if c < 0
    c = CircuitElement.colorScaleCount - 1  if c >= CircuitElement.colorScaleCount
    Math.floor CircuitElement.colorScale[c].getColor()

  @setPowerColor: (yellow) ->
    return  unless Circuit.powerCheckItem

    w0 = @getPower() * CircuitElement.powerMult

    w = if (w0 < 0) then -w0 else w0
    w = 1 if w > 1
    rg = 128 + Math.floor w * 127
    b = Math.floor 128 * (1 - w)


# The Footer exports class(es) in this file via Node.js, if it is defined.
# This is necessary for testing through Mocha in development mode.
#
# see script/test and the /test directory for details.
#
# To require this class in another file through Node, write {ClassName} = require(<path_to_coffee_file>)
root = (exports) ? window
module.exports = CircuitElement