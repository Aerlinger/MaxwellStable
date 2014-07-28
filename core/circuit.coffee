# #######################################################################
# Circuit:
#     Top-level-class specification for a circuit
#
# @author Anthony Erlinger
# @year 2012
# #######################################################################

if process.env
  CircuitEngineParams = require('./engineParams')
  CircuitSolver = require('./engine/circuitSolver')
  ComponentDefs = require('./componentDefs')

  CircuitLoader = require('../io/circuitLoader')
  Logger = require('../io/logger')

  MouseState = require('../ui/circuitStates').MouseState
  KeyboardState = require('../ui/circuitStates').KeyboardState
  ColorMapState = require('../ui/circuitStates').ColorMapState

  CommandHistory = require('../ui/commandHistory')
  Hint = require('./hint')
  Grid = require('../ui/grid')
  ArrayUtils = require('../util/arrayUtils')

  Scope = require('../scope/scope')



class Circuit

  # CLASS VARIABLES:
  @muString     = "u"
  @ohmString    = "ohm"

  engineParams = new CircuitEngineParams()

  # State Handlers
  mouseState = new MouseState()
  keyboardState = new KeyboardState()
  colorMapState = new ColorMapState()

  UndoRedo = new UndoRedo()
  hint = new Hint()


  # simulation variables
  t = 0                 # t is simulation time (in seconds)
  pause = 10
  converged = true      # true if numerical analysis has converged
  subIterations = 5000

  stopElm = null
  stopMessage  = 0

  renderContext = null

  scopes = new Array(20)        # Array of scope objects
  scopeColCount = new Array(20) # Array of integers
  scopeCount = 0

  dumpTypes = new Array()
  nodeList = new Array()

  voltageSources = new Array()
  voltageSourceCount = 0

  circuitBottom = 0


  constructor: ->
    console.log("Started Simulation")
    @elementList = []
    @Solver = new CircuitSolver(this)
    @init()


  init: () ->
    # CircuitElement.initClass() # < REMOVED
    @Solver.invalidate()

    dumpTypes = new Array(300)
    dumpTypes["o"] = Scope::
    dumpTypes["h"] = Scope::
    dumpTypes["$"] = Scope::
    dumpTypes["%"] = Scope::
    dumpTypes["?"] = Scope::
    dumpTypes["B"] = Scope::

    @grid = new Grid()
    @registerAll()

    scopes = new Array(20) # Array of scope objects
    scopeColCount = new Array(20) # Array of integers
    scopeCount = 0

    @loadCircuit(Settings.defaultCircuit)


  ## #######################################################################################################
  # Loops through through all existing elements defined within the ElementMap Hash (see
  #   <code>ComponentDefinitions.coffee</code>) and registers their class with the solver engine
  # ##########
  registerAll: ->
    for ElementName, ElementDescription of ComponentDefs
      console.log("\tRegistering Element: #{ElementName}")
      @register(ElementName)


  ## #######################################################################################################
  # Registers, constructs, and places an element with the given class name within this circuit.
  #   This method is called by <code>register</code>
  # ##########
  register: (elmClassName) ->
    try
      # Create this component by its className
      elm = Circuit.constructElement(elmClassName, 0, 0, 0, 0, 0, null)

      dumpType = elm.getDumpType()
      dumpClass = elmClassName

      if Circuit.dumpTypes[dumpType] is dumpClass
        console.log "#{elmClassName} is a dump class"
        return
      if Circuit.dumpTypes[dumpType]?
        console.log "Dump type conflict: " + dumpType + " " + Circuit.dumpTypes[dumpType]
        return

      Circuit.dumpTypes[dumpType] = elmClassName
    catch e
      Logger.warn "\t\tElement: " + elmClassName + " Not yet implemented"


  ## #######################################################################################################
  # Loads the circuit from the given text file
  # ##########
  loadCircuit: (defaultCircuit) ->

    # Clear and reset circuit elements
    @clearAndReset()
    UndoRedo.reset()
    CircuitLoader.readSetupList this, false
    CircuitLoader.readCircuitFromFile this, "#{defaultCircuit}.txt", false


  ###
  Removes all circuit elements and scopes from the workspace and resets time to zero.
  ###
  clearAndReset: ->

    for element in elementList
      element.destroy()

    # simulation variables
    t = 0                 # t is simulation time (in seconds)
    converged = true      # true if numerical analysis has converged
    subIterations = 5000

    @clearErrors()

    scopes = new Array(20)        # Array of scope objects
    scopeColCount = new Array(20) # Array of integers
    scopeCount = 0

    dumpTypes = new Array()
    nodeList = new Array()
    elementList = new Array()

    voltageSources = new Array();
    voltageSourceCount = 0;

    circuitBottom = 0;


  ###
  Clears current states, graphs, and errors then Restarts the circuit from time zero.
  ###
  restartAndStop: ->

    restartAndPlay()

    @Solver.stop("Restarted Circuit from t=0")
    @Solver.invalidate()


  restartAndPlay: ->
    for element in elementList
      element.reset()

    for scope in scopes
      scope.resetGraph()

    t = 0


  # Returns the y position of the bottom of the circuit
  calcCircuitBottom: ->
    @circuitBottom = 0;

    for element in elementList
      rect = element.boundingBox
      bottom = rect.height + rect.y;

      circuitBottom = bottom if (bottom > circuitBottom)

    return circuitBottom


  clearErrors: ->
    stopMessage = null
    stopElm = null

  getRenderContext: ->
    renderContext

  #It may be worthwhile to return a defensive copy here
  getElements: ->
    elementList

  numElements: ->
    return elementList.length

  getNodes: ->
    nodeList

  numNodes: ->
    nodeList.length

  getGrid: ->
    return grid;




  ###
  UpdateCircuit: Outermost method in event loops

  Called once each frame
  ###
  Circuit.updateCircuit = ->
    startTime = (new Date()).getTime()

    # Reset the page:
    renderContext.clearRect 0, 0, CANVAS.width(), CANVAS.height()
    # CircuitElement
    realMouseElm = Circuit.mouseElm

    # Render Warning and error messages:
    #CirSim.drawError();
    #CirSim.drawWarning();
    if Circuit.analyzeFlag
      Circuit.analyzeCircuit()
      Circuit.analyzeFlag = false

    # TODO
    #    if(CirSim.editDialog != null && CirSim.editDialog.elm instanceof CircuitElement)
    #		CirSim.mouseElm = CirSim.editDialog.elm;
    # as CircuitElement;
    Circuit.mouseElm = Circuit.stopElm  unless Circuit.mouseElm?

    # TODO: test
    Circuit.setupScopes()
    CircuitElement.selectColor = Settings.SELECT_COLOR
    if Circuit.printableCheckItem
      CircuitElement.whiteColor = Color.WHITE
      CircuitElement.lightGrayColor = Color.BLACK
    else
      CircuitElement.whiteColor = Color.WHITE
      CircuitElement.lightGrayColor = Color.LIGHT_GREY
    unless Circuit.stoppedCheck
      try
        Circuit.runCircuit()
      catch e
        console.log "error in run circuit: " + e.message
        Circuit.analyzeFlag = true

        #cv.paint(g);
        return
    unless Circuit.stoppedCheck
      sysTime = (new Date()).getTime()
      unless Circuit.lastTime is 0
        inc = Math.floor(sysTime - Circuit.lastTime)
        c = Circuit.currentBar # The value of CirSim number must be carefully set for current to display properly

        #console.log("Frame time: " + inc  + "   #: "  + frames);
        c = Math.exp(c / 3.5 - 14.2)
        CircuitElement.currentMult = 1.7 * inc * c
        CircuitElement.currentMult = -CircuitElement.currentMult  unless Circuit.conventionCheckItem
      if sysTime - Circuit.secTime >= 1000
        Circuit.framerate = Circuit.frames
        Circuit.steprate = Circuit.steps
        Circuit.frames = 0
        Circuit.steps = 0
        Circuit.secTime = sysTime
      Circuit.lastTime = sysTime
    else
      Circuit.lastTime = 0
    CircuitElement.powerMult = Math.exp(Circuit.powerBar / 4.762 - 7)

    # Draw each circuit element
    i = 0

    while i < Circuit.elementList.length
      Circuit.getElm(i).draw()
      ++i

    # Draw the posts for each circuit
    if Circuit.tempMouseMode is Circuit.MODE_DRAG_ROW or Circuit.tempMouseMode is Circuit.MODE_DRAG_COLUMN or Circuit.tempMouseMode is Circuit.MODE_DRAG_POST or Circuit.tempMouseMode is Circuit.MODE_DRAG_SELECTED
      i = 0
      while i < Circuit.elementList.length
        ce = Circuit.getElm(i)
        ce.drawPost ce.x, ce.y
        ce.drawPost ce.x2, ce.y2
        ++i
    badNodes = 0

    # find bad connections. Nodes not connected to other elements which intersect other elements' bounding boxes
    i = 0
    while i < Circuit.nodeList.length
      cn = Circuit.getCircuitNode(i)
      if not cn.intern and cn.links.length is 1
        bb = 0
        cn1 = cn.links[0]

        # CircuitNodeLink
        j = 0

        while j < Circuit.elementList.length
          bb++  if cn1.elm isnt Circuit.getElm(j) and Circuit.getElm(j).boundingBox.contains(cn.x, cn.y)
          ++j
        if bb > 0

          # Outline bad nodes
          renderContext.circle(cn.x, cn.y, 2 * Settings.POST_RADIUS).attr
            stroke: Color.color2HexString(Color.RED)
            "stroke-dasharray": "--"

          badNodes++
      ++i
    Circuit.dragElm.draw null  if Circuit.dragElm? and (Circuit.dragElm.x isnt Circuit.dragElm.x2 or Circuit.dragElm.y isnt Circuit.dragElm.y2)
    ct = Circuit.scopeCount
    ct = 0  if Circuit.stopMessage?

    # TODO Implement scopes
    #for(i=0; i!=ct; ++i)
    #    CirSim.scopes[i].draw();
    if Circuit.stopMessage?
      printError Circuit.stopMessage
    else
      Circuit.calcCircuitBottom()  if Circuit.circuitBottom is 0
      info = []

      # Array of messages to be displayed at the bottom of the canvas
      if Circuit.mouseElm?
        if Circuit.mousePost is -1
          Circuit.mouseElm.getInfo info
        else
          info[0] = "V = " + CircuitElement.getUnitText(Circuit.mouseElm.getPostVoltage(Circuit.mousePost), "V")
      else
        CircuitElement.showFormat.fractionalDigits = 2
        info[0] = "t = " + CircuitElement.getUnitText(Circuit.t, "s") + "\nf.t.: " + (Circuit.lastTime - Circuit.lastFrameTime) + "\n"
      unless Circuit.hintType is -1
        i = 0
        while info[i]?
          ++i
        s = Circuit.getHint()
        unless s?
          Circuit.hintType = -1
        else
          info[i] = s
      x = 0

      # TODO: Implement scopes
      x = Circuit.scopes[ct - 1].rightEdge() + 20  unless ct is 0
      CanvasBounds = getCanvasBounds()
      x = 0  unless x
      x = Math.max(x, CanvasBounds.width * 2 / 3)
      i = 0
      while info[i]?
        ++i
      info[++i] = badNodes + ((if (badNodes is 1) then " bad connection" else " bad connections"))  if badNodes > 0
      bottomTextOffset = 100

      # Find where to show data; below circuit, not too high unless we need it
      ybase = CanvasBounds.height - 15 * i - bottomTextOffset
      ybase = Math.min(ybase, CanvasBounds.height)
      ybase = Math.max(ybase, Circuit.circuitBottom)

      # TODO: CANVAS
      i = 0
      while info[i]?
        renderContext.fillStyle = Color.color2HexString(Settings.TEXT_COLOR)
        renderContext.fillText info[i], x, ybase + 15 * (i + 1)
        ++i

    # Draw selection outline:
    if Circuit.selectedArea?

      #renderContext.strokeStyle = Color.color2HexString(Settings.SELECTION_MARQUEE_COLOR);
      renderContext.beginPath()
      renderContext.strokeStyle = Settings.SELECT_COLOR
      renderContext.strokeRect @selectedArea.x, @selectedArea.y, @selectedArea.width, @selectedArea.height
      renderContext.closePath()

    Circuit.mouseElm = realMouseElm
    Circuit.frames++

    endTime = (new Date()).getTime()
    Circuit.lastFrameTime = Circuit.lastTime



# The Footer exports class(es) in this file via Node.js, if Node.js is defined.
# This is necessary for testing through Mocha in development mode.
#
# see script/test and the /test directory for details.
#
# To require this class in another file through Node, write {ClassName} = require(<path_to_coffee_file>)
root = module.exports ? window
module.exports = Circuit