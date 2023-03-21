import board, compact_board, moves, transpositions
from random import sample
import sets
from algorithm import sort

proc calculateNextMoveRandomly*(s: GameState): (MoveIndex, PieceType) =
  let (m, p) = s.getPossibleMoves().simplify()
  let moves = m & p
  result[0] = moves.sample()
  let startCell = result[0].start
  let endCell = result[0].finish
  if abs(s.board[startCell]) == WhitePawn.int8 and (endCell.rank == 0 or endCell.rank == 7):
    result[1] = if s.white: WhiteQueen else: BlackQueen
  else:
    result[1] = Empty

proc pieceValue(p: PieceType): int {.inline.} =
  case p:
    of WhiteKing, BlackKing: int.high
    of WhiteQueen, BlackQueen: 9
    of WhiteRook, BlackRook: 5
    of WhiteBishop, BlackBishop: 3
    of WhiteKnight, BlackKnight: 3
    of WhitePawn, BlackPawn: 1
    else: 0

proc evaluateLeafPosition*(s: GameState): float =
  var totalWhite = 0.0
  var totalBlack = 0.0
  totalWhite = s.pieceCounts[WhiteQueen.int].float * 9
  totalBlack = s.pieceCounts[BlackQueen.int].float * 9
  totalWhite += s.pieceCounts[WhiteRook.int].float * 5
  totalBlack += s.pieceCounts[BlackRook.int].float * 5
  totalWhite += s.pieceCounts[WhiteKnight.int].float * 3
  totalBlack += s.pieceCounts[BlackKnight.int].float * 3
  totalWhite += s.pieceCounts[WhiteBishop.int].float * 3
  totalBlack += s.pieceCounts[BlackBishop.int].float * 3
  totalWhite += s.pieceCounts[WhitePawn.int].float
  totalBlack += s.pieceCounts[BlackPawn.int].float

  result = totalWhite - totalBlack
  if not s.white: result = -result

  if totalWhite < 13 and totalBlack < 13:
    let otherKing = if s.white: s.kingPositions[1] else: s.kingPositions[0]
    let otherKingHor = max(3 - otherKing.file, otherKing.file - 4)
    let otherKingVer = max(3 - otherKing.rank, otherKing.rank - 4)
    let distFromCenter = otherKingHor + otherKingVer
    result += 0.1 * distFromCenter.float

    let myKing = s.myKing
    let distBetweenKings = abs(myKing.file - otherKing.file) + abs(myKing.rank - otherKing.rank)
    result -= 0.05 * distBetweenKings.float



proc rateMove(m: MoveData): int =
  result = 0
  if m.move.capture:
    result += 3 * m.capturePiece.pieceValue - m.movePiece.pieceValue
  if m.underPawnAttack:
    result -= m.movePiece.pieceValue

proc sortMoves(m: var seq[MoveData]) =
  m.sort(proc(a, b: MoveData): int = -cmp(a.rateMove, b.rateMove))

proc countPositions*(s: GameState, limit: int): int64 =
  if limit == 0:
    return 1
  let (moves, proms) = s.getPossibleMoves()
  #if limit == 2:
  #  echo moves
  result = 0

  for m in moves:
    let newState = s.handleMove(m.move, Empty)
    let count = newState.countPositions(limit - 1)
    #if limit == 2:
    #  echo count
    result += count
  for m in proms:
    if s.white:
      for p in [WhiteQueen, WhiteRook, WhiteBishop, WhiteKnight]:
        let newState = s.handleMove(m.move, p)
        result += newState.countPositions(limit - 1)
    else:
      for p in [BlackQueen, BlackRook, BlackBishop, BlackKnight]:
        let newState = s.handleMove(m.move, p)
        result += newState.countPositions(limit - 1)

proc evaluateQuiet(s: GameState, trans: var TransTable, alpha, beta: float, moveCount: int, level: int = 0): float =
  #if trans.has s.zobrist:
  #  return trans[s.zobrist]

  let leafVal = s.evaluateLeafPosition()
  if leafVal >= beta:
    trans[s.zobrist] = beta
    return beta
  result = alpha
  if result < leafVal:
    result = leafVal

  var (moves, proms) = s.getPossibleMoves()
  if moves.len == 0 and proms.len == 0:
    if s.checks.len > 0:
      result = -10000.0 / moveCount.float
    else:
      result = 0
    trans[s.zobrist] = result
    return
  moves.sortMoves()

  if level > 100:
    echo level
    echo s
    echo moves
  if level > 110:
    quit()

  template updateResult(): untyped =
    let val = -newState.evaluateQuiet(trans, -beta, -result, moveCount+1, level+1)
    if val >= beta:
      trans[s.zobrist] = beta
      return beta
    result = max(result, val)

  for m in proms:
    if s.white:
      for p in [WhiteQueen, WhiteRook, WhiteBishop, WhiteKnight]:
        let newState = s.handleMove(m.move, p)
        updateResult()
    else:
      for p in [BlackQueen, BlackRook, BlackBishop, BlackKnight]:
        let newState = s.handleMove(m.move, p)
        updateResult()
  for m in moves:
    if m.move.capture:
      let newState = s.handleMove(m.move, Empty)
      updateResult()
  trans[s.zobrist] = result

proc evaluatePosition(s: GameState, trans: var TransTable, limit: int, 
    alpha, beta: float, moveCount: int): float =
  #if trans.has s.zobrist:
  #  return trans[s.zobrist]

  if limit <= 0:
    return s.evaluateQuiet(trans, alpha, beta, moveCount+1)
  var (moves, proms) = s.getPossibleMoves()

  if moves.len == 0 and proms.len == 0:
    if s.checks.len > 0:
      result = -10000.0 / moveCount.float
    else:
      result = 0
    trans[s.zobrist] = result
    return
  moves.sortMoves()
  #echo limit
  result = alpha
  template updateResult(): untyped =
    let val = -newState.evaluatePosition(trans, limit - 1, -beta, -result, moveCount+1)
    if val >= beta:
      trans[s.zobrist] = beta
      return beta
    result = max(result, val)

  for m in proms:
    if s.white:
      for p in [WhiteQueen, WhiteRook, WhiteBishop, WhiteKnight]:
        let newState = s.handleMove(m.move, p)
        updateResult()
    else:
      for p in [BlackQueen, BlackRook, BlackBishop, BlackKnight]:
        let newState = s.handleMove(m.move, p)
        updateResult()
  for m in moves:
    let newState = s.handleMove(m.move, Empty)
    updateResult()
  trans[s.zobrist] = result

proc calculateNextMove*(s: GameState): (MoveIndex, PieceType) =
  var (moves, proms) = s.getPossibleMoves()
  moves.sortMoves()
  echo moves
  echo s

  var trans = initTransTable()
  
  var bestVal = -Inf
  const Depth = 4
  template updateResult(): untyped =
    let val = -newState.evaluatePosition(trans, Depth, -Inf, -bestVal, 1)
    echo val
    if val > bestVal:
      bestVal = val
      result = (m.move, p)

  for m in proms:
    if s.white:
      for p in [WhiteQueen, WhiteRook, WhiteBishop, WhiteKnight]:
        let newState = s.handleMove(m.move, p)
        updateResult()
    else:
      for p in [BlackQueen, BlackRook, BlackBishop, BlackKnight]:
        let newState = s.handleMove(m.move, p)
        updateResult()
  for m in moves:
    let p = Empty
    let newState = s.handleMove(m.move, p)
    updateResult()
  echo "! ", result

when isMainModule:
  import checks
  let startState = initGameState("r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10")
  for limit in 1..4:
    let count = startState.countPositions(limit)
    echo limit, ": ", count