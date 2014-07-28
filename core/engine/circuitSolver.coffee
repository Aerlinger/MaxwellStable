MatrixStamper = require('./matrixStamper')

class CircuitSolver

  circuitMatrix    = new Array()
  circuitRightSide = new Array()

  origMatrix       = new Array()
  origRightSide    = new Array()

  circuitRowInfo   = new Array()
  circuitPermute   = new Array()

  scaleFactors     = new Array()

  circuitMatrixSize = undefined
  circuitMatrixFullSize = undefined

  stopped = false
  circuitNonLinear = false

  analyzeFlag  = true     # Flag indicating if the circuit needs to be reanalyzed (only true when the circuit has changed)

  @scaleFactors = (0 for i in [0..400])


  constructor: (@Circuit) ->
    @Stamper = new MatrixStamper(@Circuit, this)


  # When the circuit has changed we will need to rebuild the node graph and the circuit matrix.
  invalidate: ->
    analyzeFlag = true


  stop: (message="Simulator Stopped") ->
    stopped = true


  analyzeCircuit: ->

    @Circuit.calcCircuitBottom()
    return if @Circuit.numElements() is 0

    @Circuit.clearErrors()
    @Circuit.nodeList = new Array()

    vscount = 0

    gotGround = false
    gotRail = false
    volt = null

    i = 0
    while i < @Circuit.numElements()
      ce = @Circuit.getElm(i) # CircuitElement type
      if ce instanceof GroundElm
        gotGround = true
        break
      gotRail = true if ce instanceof RailElm
      volt = ce  if not volt? and ce instanceof VoltageElm
      ++i

    # If no ground and no rails then voltage element's first terminal instanceof referenced to ground:
    if not gotGround and volt? and not gotRail
      cn = new CircuitNode()
      pt = volt.getPost(0)
      cn.x = pt.x
      cn.y = pt.y
      @Circuit.nodeList.push cn
    else

      # Else allocate extra node for ground
      cn = new CircuitNode()
      cn.x = cn.y = -1
      @Circuit.nodeList.push cn

    # Allocate nodes and voltage sources
    i = 0
    while i < @Circuit.numElements()
      ce = @Circuit.getElm(i)
      inodes = ce.getInternalNodeCount()
      ivs = ce.getVoltageSourceCount()
      posts = ce.getPostCount()

      # allocate a node for each post and match posts to nodes
      j = 0
      while j isnt posts
        pt = ce.getPost(j)
        k = undefined
        k = 0
        while k isnt @Circuit.nodeList.length
          cn = @Circuit.getCircuitNode(k)
          break  if pt.x is cn.x and pt.y is cn.y
          ++k
        if k is @Circuit.nodeList.length
          cn = new CircuitNode()
          cn.x = pt.x
          cn.y = pt.y
          cn1 = new CircuitNodeLink()
          cn1.num = j
          cn1.elm = ce
          cn.links.push cn1
          ce.setNode j, @Circuit.nodeList.length
          @Circuit.nodeList.push cn
        else
          cn1 = new CircuitNodeLink()
          cn1.num = j
          cn1.elm = ce
          @Circuit.getCircuitNode(k).links.push cn1
          ce.setNode j, k

          # If it's the ground node, make sure the node voltage instanceof 0, because it may not get set later.
          ce.setNodeVoltage j, 0  if k is 0
        ++j
      j = 0
      while j isnt inodes
        cn = new CircuitNode()
        cn.x = -1
        cn.y = -1
        cn.intern = true
        cn1 = new CircuitNodeLink()
        cn1.num = j + posts
        cn1.elm = ce
        cn.links.push cn1
        ce.setNode cn1.num, @Circuit.nodeList.length
        @Circuit.nodeList.push cn
        ++j
      vscount += ivs
      ++i
    @Circuit.voltageSources = new Array(vscount)
    vscount = 0
    @Circuit.circuitNonLinear = false

    # determine if circuit instanceof nonlinear
    i = 0
    while i isnt @Circuit.numElements()
      ce = @Circuit.getElm(i) # circuitElement
      @Circuit.circuitNonLinear = true  if ce.nonLinear()
      ivs = ce.getVoltageSourceCount()
      j = 0
      while j isnt ivs
        @Circuit.voltageSources[vscount] = ce
        ce.setVoltageSource j, vscount++
        ++j
      ++i
    @Circuit.voltageSourceCount = vscount
    matrixSize = @Circuit.nodeList.length - 1 + vscount
    circuitMatrix = initializeTwoDArray(matrixSize, matrixSize)
    @Circuit.origMatrix = initializeTwoDArray(matrixSize, matrixSize)
    @Circuit.circuitRightSide = new Array(matrixSize)

    # Todo: check array length
    #circuitRightSide =
    zeroArray @Circuit.circuitRightSide
    @Circuit.origRightSide = new Array(matrixSize)

    #origRightSide =
    zeroArray @Circuit.origRightSide
    @Circuit.circuitMatrixSize = @Circuit.circuitMatrixFullSize = matrixSize
    @Circuit.circuitRowInfo = new Array(matrixSize)
    @Circuit.circuitPermute = new Array(matrixSize)

    # Todo: check
    #circuitRowInfo =
    zeroArray @Circuit.circuitRowInfo

    #circuitPermute =
    zeroArray @Circuit.circuitPermute
    i = 0
    while i isnt matrixSize
      @Circuit.circuitRowInfo[i] = new RowInfo()
      ++i
    @Circuit.circuitNeedsMap = false

    # stamp linear circuit elements
    i = 0
    while i isnt @Circuit.numElements()
      ce = @Circuit.getElm(i)
      ce.stamp()
      ++i
    closure = new Array(@Circuit.nodeList.length)
    changed = true
    closure[0] = true
    while changed
      changed = false
      i = 0
      while i isnt @Circuit.numElements()
        ce = @Circuit.getElm(i)

        # Loop through all ce's nodes to see if theya are connected to otehr nodes not in closure
        j = 0
        while j < ce.getPostCount()
          unless closure[ce.getNode(j)]
            closure[ce.getNode(j)] = changed = true  if ce.hasGroundConnection(j)
            continue
          k = undefined
          k = 0
          while k isnt ce.getPostCount()
            continue  if j is k
            kn = ce.getNode(k)
            if ce.getConnection(j, k) and not closure[kn]
              closure[kn] = true
              changed = true
            ++k
          ++j
        ++i
      continue  if changed

      # connect unconnected nodes
      i = 0
      while i isnt @Circuit.nodeList.length
        if not closure[i] and not @Circuit.getCircuitNode(i).intern
          @Circuit.error "node " + i + " unconnected"
          @Circuit.stampResistor 0, i, 1e8
          closure[i] = true
          changed = true
          break
        ++i
    i = 0
    while i isnt @Circuit.numElements()
      ce = @Circuit.getElm(i)
      if ce instanceof InductorElm
        fpi = new FindPathInfo(FindPathInfo.INDUCT, ce, ce.getNode(1), @Circuit.elmList, @Circuit.nodeList.length)

        # try findPath with maximum depth of 5, to avoid slowdown
        if not fpi.findPath(ce.getNode(0), 5) and not fpi.findPath(ce.getNode(0))
          console.log ce.toString() + " no path"
          ce.clearAndReset()

      # look for current sources with no current path
      if ce instanceof CurrentElm
        fpi = new FindPathInfo(FindPathInfo.INDUCT, ce, ce.getNode(1), @Circuit.elmList, @Circuit.nodeList.length)
        unless fpi.findPath(ce.getNode(0))
          @Circuit.halt "No path for current source!", ce
          return

      # Look for voltage soure loops:
      if (ce instanceof VoltageElm and ce.getPostCount() is 2) or ce instanceof WireElm
        fpi = new FindPathInfo(FindPathInfo.VOLTAGE, ce, ce.getNode(1), @Circuit.elmList, @Circuit.nodeList.length)
        if fpi.findPath(ce.getNode(0)) is true
          @Circuit.halt "Voltage source/wire loop with no resistance!", ce
          return

      # Look for shorted caps or caps with voltage but no resistance
      if ce instanceof CapacitorElm
        fpi = new FindPathInfo(FindPathInfo.SHORT, ce, ce.getNode(1), @Circuit.elmList, @Circuit.nodeList.length)
        if fpi.findPath(ce.getNode(0))
          console.log ce.toString() + " shorted"
          ce.clearAndReset()
        else
          fpi = new FindPathInfo(FindPathInfo.CAP_V, ce, ce.getNode(1), @Circuit.elmList, @Circuit.nodeList.length)
          if fpi.findPath(ce.getNode(0))
            @Circuit.halt "Capacitor loop with no resistance!", ce
            return
      ++i
    i = 0
    while i isnt matrixSize
      qm = -1
      qp = -1
      qv = 0
      re = @Circuit.circuitRowInfo[i]
      continue  if re.lsChanges or re.dropRow or re.rsChanges
      rsadd = 0

      # look for rows that can be removed
      j = 0
      while j isnt matrixSize
        q = circuitMatrix[i][j]
        if @Circuit.circuitRowInfo[j].type is RowInfo.ROW_CONST

          # Keep a running total of const values that have been removed already
          rsadd -= @Circuit.circuitRowInfo[j].value * q
          continue
        continue  if q is 0
        if qp is -1
          qp = j
          qv = q
          continue
        if qm is -1 and q is -qv
          qm = j
          continue
        break
        ++j

      #console.log("line " + i + " " + qp + " " + qm + " " + j);
      #if (qp != -1 && circuitRowInfo[qp].lsChanges) {
      #         console.log("lschanges");
      #         continue;
      #         }
      #         if (qm != -1 && circuitRowInfo[qm].lsChanges) {
      #         console.log("lschanges");
      #         continue;
      #         }
      if j is matrixSize
        if qp is -1
          @Circuit.halt "Matrix error", null
          return
        elt = @Circuit.circuitRowInfo[qp]
        if qm is -1

          # We found a row with only one nonzero entry, that value instanceof constant
          k = undefined
          k = 0
          while elt.type is RowInfo.ROW_EQUAL and k < 100

            # Follow the chain
            qp = elt.nodeEq
            elt = @Circuit.circuitRowInfo[qp]
            ++k
          if elt.type is RowInfo.ROW_EQUAL

            # break equal chains
            #console.log("Break equal chain");
            elt.type = RowInfo.ROW_NORMAL
            continue
          unless elt.type is RowInfo.ROW_NORMAL
            console.log "type already " + elt.type + " for " + qp + "!"
            continue
          elt.type = RowInfo.ROW_CONST
          elt.value = (@Circuit.circuitRightSide[i] + rsadd) / qv
          @Circuit.circuitRowInfo[i].dropRow = true

          #console.log(qp + " * " + qv + " = const " + elt.value);
          i = -1 # start over from scratch
        else if @Circuit.circuitRightSide[i] + rsadd is 0

          # we found a row with only two nonzero entries, and one
          # instanceof the negative of the other; the values are equal
          unless elt.type is RowInfo.ROW_NORMAL

            #console.log("swapping");
            qq = qm
            qm = qp
            qp = qq
            elt = @Circuit.circuitRowInfo[qp]
            unless elt.type is RowInfo.ROW_NORMAL

              # we should follow the chain here, but this hardly ever happens so it's not worth worrying about
              console.log "swap failed"
              continue
          elt.type = RowInfo.ROW_EQUAL
          elt.nodeEq = qm
          @Circuit.circuitRowInfo[i].dropRow = true
      ++i

    #console.log(qp + " = " + qm);
    # end elseif
    # end if(j==matrixSize)
    # end for(matrixSize)

    # find size of new matrix:
    nn = 0
    i = 0
    while i isnt matrixSize
      elt = @Circuit.circuitRowInfo[i]
      if elt.type is RowInfo.ROW_NORMAL
        elt.mapCol = nn++

        #console.log("col " + i + " maps to " + elt.mapCol);
        continue
      if elt.type is RowInfo.ROW_EQUAL
        e2 = null

        # resolve chains of equality; 100 max steps to avoid loops
        j = 0
        while j isnt 100
          e2 = @Circuit.circuitRowInfo[elt.nodeEq]
          break  unless e2.type is RowInfo.ROW_EQUAL
          break  if i is e2.nodeEq
          elt.nodeEq = e2.nodeEq
          j++
      elt.mapCol = -1  if elt.type is RowInfo.ROW_CONST
      ++i
    # END for
    i = 0
    while i isnt matrixSize
      elt = @Circuit.circuitRowInfo[i]
      if elt.type is RowInfo.ROW_EQUAL
        e2 = @Circuit.circuitRowInfo[elt.nodeEq]
        if e2.type is RowInfo.ROW_CONST

          # if something instanceof equal to a const, it's a const
          elt.type = e2.type
          elt.value = e2.value
          elt.mapCol = -1

          #console.log(i + " = [late]const " + elt.value);
        else
          elt.mapCol = e2.mapCol
      i++

    #console.log(i + " maps to: " + e2.mapCol);

    # make the new, simplified matrix
    newsize = nn
    newmatx = initializeTwoDArray(newsize, newsize)
    newrs = new Array(newsize)

    #var newrs:Array =
    zeroArray newrs
    ii = 0
    i = 0
    while i isnt matrixSize
      rri = @Circuit.circuitRowInfo[i]
      if rri.dropRow
        rri.mapRow = -1
        continue
      newrs[ii] = @Circuit.circuitRightSide[i]
      rri.mapRow = ii

      #console.log("Row " + i + " maps to " + ii);
      j = 0
      while j isnt matrixSize
        ri = @Circuit.circuitRowInfo[j]
        if ri.type is RowInfo.ROW_CONST
          newrs[ii] -= ri.value * circuitMatrix[i][j]
        else
          newmatx[ii][ri.mapCol] += circuitMatrix[i][j]
        j++
      ii++
      i++
    circuitMatrix = newmatx
    @Circuit.circuitRightSide = newrs
    matrixSize = @Circuit.circuitMatrixSize = newsize
    i = 0
    while i isnt matrixSize
      @Circuit.origRightSide[i] = @Circuit.circuitRightSide[i]
      i++
    i = 0
    while i isnt matrixSize
      j = 0
      while j isnt matrixSize
        @Circuit.origMatrix[i][j] = circuitMatrix[i][j]
        j++
      i++
    @Circuit.circuitNeedsMap = true

    # // For debugging
    #     console.log("matrixSize = " + matrixSize + " " + circuitNonLinear);
    #     for (j = 0; j != circuitMatrixSize; j++) {
    #     for (i = 0; i != circuitMatrixSize; i++)
    #     console.log(circuitMatrix[j][i] + " ");
    #     console.log("  " + circuitRightSide[j] + "\n");
    #     }
    #     console.log("\n");
    #

    # if a matrix instanceof linear, we can do the lu_factor here instead of needing to do it every frame
    unless @Circuit.circuitNonLinear
      unless @Circuit.lu_factor(circuitMatrix, @Circuit.circuitMatrixSize, @Circuit.circuitPermute)
        @Circuit.halt "Singular matrix!", null
        return



  runCircuit: ->
    if not circuitMatrix? or CirSim.elmList.length is 0
      circuitMatrix = null
      return
    iter = undefined
    debugPrint = CirSim.dumpMatrix
    CirSim.dumpMatrix = false
    steprate = Math.floor(160 * CirSim.getIterCount())
    tm = (new Date()).getTime()
    lit = CirSim.lastIterTime

    # Double-check
    if 1000 >= steprate * (tm - CirSim.lastIterTime)
      console.log "returned: diff: " + (tm - CirSim.lastIterTime)
      return

    # Main iteration
    iter = 1
    loop
      i = undefined
      j = undefined
      k = undefined
      subiter = undefined

      # Start Iteration for each element in the circuit
      i = 0
      while i < CirSim.elmList.length
        ce = CirSim.getElm(i)
        ce.startIteration()
        ++i

      # Keep track of the number of steps
      ++CirSim.steps

      # The number of maximum allowable iterations
      subiterCount = 500

      # Sub iteration
      subiter = 0
      while subiter isnt subiterCount
        CirSim.converged = true
        CirSim.subIterations = subiter
        i = 0
        while i < CirSim.circuitMatrixSize
          CirSim.circuitRightSide[i] = CirSim.origRightSide[i]
          ++i
        if CirSim.circuitNonLinear
          i = 0
          while i < CirSim.circuitMatrixSize
            j = 0
            while j < CirSim.circuitMatrixSize
              circuitMatrix[i][j] = CirSim.origMatrix[i][j]
              ++j
            ++i

        # Step each element this iteration
        i = 0
        while i < CirSim.elmList.length
          ce = CirSim.getElm(i)
          ce.doStep()
          ++i
        return  if CirSim.stopMessage?
        printit = debugPrint
        debugPrint = false
        j = 0
        while j < CirSim.circuitMatrixSize
          i = 0
          while i < CirSim.circuitMatrixSize
            x = circuitMatrix[i][j]
            if isNaN(x) or isInfinite(x)
              console.log "Matrix is invalid " + isNaN(x)
              CirSim.halt "Invalid matrix", null
              return
            ++i
          ++j

        #            if(printit) {
        #                for(j=0; i<circuitMatrixSize; j++) {
        #                    for( i=0; i<circuitMatrixSize; ++i)
        #                        console.log(circuitMatrix[j][i] + ",");
        #                    console.log(" " + circuitRightSide[j] + "\n");
        #                }
        #                console.log("\n");
        #            }
        if CirSim.circuitNonLinear
          break  if CirSim.converged and subiter > 0
          unless CirSim.lu_factor(circuitMatrix, CirSim.circuitMatrixSize, CirSim.circuitPermute)
            CirSim.halt "Singular matrix!", null
            return
        CirSim.lu_solve circuitMatrix, CirSim.circuitMatrixSize, CirSim.circuitPermute, CirSim.circuitRightSide
        j = 0
        while j < CirSim.circuitMatrixFullSize
          ri = CirSim.circuitRowInfo[j]
          res = 0
          if ri.type is RowInfo.ROW_CONST
            res = ri.value
          else
            res = CirSim.circuitRightSide[ri.mapCol]
          if isNaN(res)
            CirSim.converged = false
            break
          if j < (CirSim.nodeList.length - 1)
            cn = CirSim.getCircuitNode(j + 1)
            k = 0
            while k < cn.links.length
              cn1 = cn.links[k] # as CircuitNodeLink;
              cn1.elm.setNodeVoltage cn1.num, res
              ++k
          else
            ji = j - (CirSim.nodeList.length - 1)

            CirSim.voltageSources[ji].setCurrent ji, res
          ++j
        break  unless CirSim.circuitNonLinear
        subiter++
      # End for
      console.log "converged after " + subiter + " iterations"  if subiter > 5
      if subiter >= subiterCount
        CirSim.halt "Convergence failed: " + subiter, null
        break
      CirSim.t += CirSim.timeStep
      i = 0
      while i < CirSim.scopeCount
        CirSim.scopes[i].timeStep()
        ++i
      tm = (new Date()).getTime()
      lit = tm

      #console.log("diff: " + (tm-CirSim.lastIterTime) + " iter: " + iter + " ");
      #console.log(iterCount + " breaking from iteration: " + " sr: " + steprate + " iter: " + subiter + " time: " + (tm - CirSim.lastIterTime)+ " lastFrametime: " + CirSim.lastFrameTime );
      #iterCount++;
      if iter * 1000 >= steprate * (tm - CirSim.lastIterTime)

        #console.log("1 breaking from iteration: " + " sr: " + steprate + " iter: " + subiter + " time: " + (tm - CirSim.lastIterTime)+ " lastFrametime: " + CirSim.lastFrameTime );
        break

        #console.log("2 breaking from iteration: " + " sr: " + steprate + " iter: " + iter + " time: " + (tm - CirSim.lastIterTime) + " lastFrametime: " + CirSim.lastFrameTime );
      else break  if tm - CirSim.lastFrameTime > 500
      ++iter
    CirSim.lastIterTime = lit



  ###
  lu_factor: finds a solution to a factored matrix through LU (Lower-Upper) factorization

  Called once each frame for resistive circuits, otherwise called many times each frame

  @param a 2D matrix to be solved
  @param n dimension
  @param ipvt pivot index
  ###
  lu_factor: (a, n, ipvt) ->
    i = 0
    j = 0
    k = 0

    # Divide each row by largest element in that row and remember scale factors
    i = 0
    while i < n
      largest = 0
      j = 0
      while j < n
        x = Math.abs(a[i][j])
        largest = x  if x > largest
        ++j

      # Check for singular matrix:
      return false  if largest is 0
      CirSim.scaleFactors[i] = 1.0 / largest
      ++i

    # Crout's method: Loop through columns first
    j = 0
    while j < n

      # Calculate upper trangular elements for this column:
      i = 0
      while i < j
        q = a[i][j]
        k = 0
        while k isnt i
          q -= a[i][k] * a[k][j]
          ++k
        a[i][j] = q
        ++i

      # Calculate lower triangular elements for this column
      largest = 0
      largestRow = -1
      i = j
      while i < n
        q = a[i][j]
        k = 0
        while k < j
          q -= a[i][k] * a[k][j]
          ++k
        a[i][j] = q
        x = Math.abs(q)
        if x >= largest
          largest = x
          largestRow = i
        ++i

      # Pivot
      unless j is largestRow
        x = undefined
        k = 0

        while k < n
          x = a[largestRow][k]
          a[largestRow][k] = a[j][k]
          a[j][k] = x
          ++k
        CirSim.scaleFactors[largestRow] = CirSim.scaleFactors[j]

      # keep track of row interchanges
      ipvt[j] = largestRow

      # avoid zeros

      #console.log("avoided zero");
      a[j][j] = 1e-18  if a[j][j] is 0
      unless j is n - 1
        mult = 1 / a[j][j]
        i = j + 1
        while i isnt n
          a[i][j] *= mult
          ++i
      ++j
    true


  ###
  Step 2: lu_solve: Called by lu_factor

  finds a solution to a factored matrix through LU (Lower-Upper) factorization

  Called once each frame for resistive circuits, otherwise called many times each frame

  @param a matrix to be solved
  @param n dimension
  @param ipvt pivot index
  @param b factored matrix
  ###
  lu_solve: (a, n, ipvt, b) ->
    i = undefined

    # find first nonzero b element
    i = 0
    while i < n
      row = ipvt[i]
      swap = b[row]
      b[row] = b[i]
      b[i] = swap
      break unless swap is 0
      ++i
    bi = i++
    while i < n
      row = ipvt[i]
      j = undefined
      tot = b[row]
      b[row] = b[i]

      # Forward substitution by using the lower triangular matrix;
      j = bi
      while j < i
        tot -= a[i][j] * b[j]
        ++j
      b[i] = tot
      ++i
    i = n - 1
    while i >= 0
      tot = b[i]

      # back-substitution using the upper triangular matrix
      j = undefined
      j = i + 1
      while j isnt n
        tot -= a[i][j] * b[j]
        ++j
      b[i] = tot / a[i][i]
      i--

  updateVoltageSource: (n1, n2, vs, v) ->
    vn = Circuit.numNodes() + vs
    Circuit.stampRightSide(vn, v)



# The Footer exports class(es) in this file via Node.js, if Node.js is defined.
# This is necessary for testing through Mocha in development mode.
#
# see script/test and the /test directory for details.
#
# To require this class in another file through Node, write {ClassName} = require(<path_to_coffee_file>)
root = exports ? window
module.exports = CircuitSolver