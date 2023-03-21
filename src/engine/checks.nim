import board, compact_board

proc isChecked*(s: GameState, c: CellIndex): bool =
  if s.white and s.board[c + Up + Left] == BlackPawn.int8:
    return true
  if s.white and s.board[c + Up + Right] == BlackPawn.int8:
    return true
  if not s.white and s.board[c + Down + Left] == WhitePawn.int8:
    return true
  if not s.white and s.board[c + Down + Right] == WhitePawn.int8:
    return true

  let thisSign = if s.white: 1 else: -1
  let otherSign = -thisSign

  const KnightMoves = [
      Up + Up + Right, Up + Up + Left,
      Down + Down + Right, Down + Down + Left,
      Left + Left + Up, Left + Left + Down,
      Right + Right + Up, Right + Right + Down
    ]
  for m in KnightMoves:
    if s.board[c + m] == WhiteKnight.int8 * otherSign:
      return true
  const KingMoves = [Up, Down, Left, Right, Up+Left, Up+Right, Down+Left, Down+Right]
  for m in KingMoves:
    if s.board[c + m] == WhiteKing.int8 * otherSign:
      return true
  
  template check(t: PieceType): untyped =
    if s.board[pos] == WhiteQueen.int8 * otherSign or s.board[pos] == t.int8 * otherSign:
      return true
    if s.board[pos] != 0 and s.board[pos] != WhiteKing.int8 * thisSign: break
  
  var pos = c
  while true:
    pos += Up
    check(WhiteRook)
  pos = c
  while true:
    pos += Down
    check(WhiteRook)
  pos = c
  while true:
    pos += Left
    check(WhiteRook)
  pos = c
  while true:
    pos += Right
    check(WhiteRook)

  pos = c
  while true:
    pos += Up + Left
    check(WhiteBishop)
  pos = c
  while true:
    pos += Down + Left
    check(WhiteBishop)
  pos = c
  while true:
    pos += Up + Right
    check(WhiteBishop)
  pos = c
  while true:
    pos += Down + Right
    check(WhiteBishop)
  return false

proc isEmptyBetween(s: GameState, a, b: CellIndex, inc: int): bool =
  var pos = a
  let trueInc = if (b - a) * inc > 0: inc else: -inc
  while true:
    pos += trueInc
    if pos == b: return true
    if s.board[pos] != Empty.int8: return false
  return true

proc checkPinned*(s: GameState, m: (CellIndex, CellIndex)): bool =
  let thisPos = m[0]
  let kingPos = s.myKing
  if thisPos == kingPos: return false
  let otherSign = if s.white: -1 else: 1

  template check(t: PieceType): untyped =
    if s.board[pos] == WhiteQueen.int8 * otherSign or s.board[pos] == t.int8 * otherSign:
      return true
    if s.board[pos] != 0: break

  if thisPos.file == kingPos.file:
    if m[1].file == thisPos.file: return false
    if not s.isEmptyBetween(thisPos, kingPos, Up): return false
    if thisPos.rank > kingPos.rank:
      var pos = thisPos
      while true:
        pos += Up
        check(WhiteRook)
    elif thisPos.rank < kingPos.rank:
      var pos = thisPos
      while true:
        pos += Down
        check(WhiteRook)
  elif thisPos.rank == kingPos.rank:
    if m[1].rank == thisPos.rank: return false
    if not s.isEmptyBetween(thisPos, kingPos, Right): return false
    if thisPos.file > kingPos.file:
      var pos = thisPos
      while true:
        pos += Right
        check(WhiteRook)
    elif thisPos.file < kingPos.file:
      var pos = thisPos
      while true:
        pos += Left
        check(WhiteRook)
  elif thisPos.diag1 == kingPos.diag1:
    if m[1].diag1 == thisPos.diag1: return false
    if not s.isEmptyBetween(thisPos, kingPos, Right + Down): return false
    if thisPos.file > kingPos.file:
      var pos = thisPos
      while true:
        pos += Right + Down
        check(WhiteBishop)
    elif thisPos.file < kingPos.file:
      var pos = thisPos
      while true:
        pos += Left + Up
        check(WhiteBishop)
  elif thisPos.diag2 == kingPos.diag2:
    if m[1].diag2 == thisPos.diag2: return false
    if not s.isEmptyBetween(thisPos, kingPos, Right + Up): return false
    if thisPos.file > kingPos.file:
      var pos = thisPos
      while true:
        pos += Right + Up
        check(WhiteBishop)
    elif thisPos.file < kingPos.file:
      var pos = thisPos
      while true:
        pos += Left + Down
        check(WhiteBishop)
  return false

proc findChecks*(s: GameState, c: CellIndex): seq[CheckData] =
  if s.white and s.board[c + Up + Left] == BlackPawn.int8:
    result.add (BlackPawn, c + Up + Left)
  if s.white and s.board[c + Up + Right] == BlackPawn.int8:
    result.add (BlackPawn, c + Up + Right)
  if not s.white and s.board[c + Down + Left] == WhitePawn.int8:
    result.add (BlackPawn, c + Down + Left)
  if not s.white and s.board[c + Down + Right] == WhitePawn.int8:
    result.add (BlackPawn, c + Down + Right)

  let otherSign = if s.white: -1 else: 1

  const KnightMoves = [
      Up + Up + Right, Up + Up + Left,
      Down + Down + Right, Down + Down + Left,
      Left + Left + Up, Left + Left + Down,
      Right + Right + Up, Right + Right + Down
    ]
  for m in KnightMoves:
    if s.board[c + m] == WhiteKnight.int8 * otherSign:
      result.add (s.board[c + m].PieceType, c + m)
  
  template check(t: PieceType): untyped =
    if s.board[pos] == WhiteQueen.int8 * otherSign or s.board[pos] == t.int8 * otherSign:
      result.add (s.board[pos].PieceType, pos)
    if s.board[pos] != 0: break
  
  var pos = c
  while true:
    pos += Up
    check(WhiteRook)
  pos = c
  while true:
    pos += Down
    check(WhiteRook)
  pos = c
  while true:
    pos += Left
    check(WhiteRook)
  pos = c
  while true:
    pos += Right
    check(WhiteRook)

  pos = c
  while true:
    pos += Up + Left
    check(WhiteBishop)
  pos = c
  while true:
    pos += Down + Left
    check(WhiteBishop)
  pos = c
  while true:
    pos += Up + Right
    check(WhiteBishop)
  pos = c
  while true:
    pos += Down + Right
    check(WhiteBishop)

proc checkEnPassant*(s: GameState, c: CellIndex): bool =
  var newS = s
  newS.enPassant = 0
  newS.board[c] = 0
  newS.board[s.enPassant] = s.board[c]
  if s.white:
    newS.board[s.enPassant + Down] = 0
  else:
    newS.board[s.enPassant + Up] = 0
  result = newS.isChecked(s.myKing)

import strutils, std/enumerate
from algorithm import fill
proc initGameState*(fen: string): GameState =
  let parts = fen.split(' ')
  result.board = emptyCompact()
  result.pieceCounts.fill 0
  for i, s in enumerate(parts[0].split('/')):
    let rank = 7-i
    var file = 0
    for c in s:
      if c in "12345678":
        file += c.int - '0'.int
      else:
        let p = case c:
          of 'P': WhitePawn
          of 'p': BlackPawn
          of 'N': WhiteKnight
          of 'n': BlackKnight
          of 'B': WhiteBishop
          of 'b': BlackBishop
          of 'R': WhiteRook
          of 'r': BlackRook
          of 'Q': WhiteQueen
          of 'q': BlackQueen
          of 'K':
            result.kingPositions[0] = (file: file, rank: rank).fromCell
            WhiteKing
          of 'k':
            result.kingPositions[1] = (file: file, rank: rank).fromCell
            BlackKing
          else: Empty
        result.board[(file: file, rank: rank)] = p.int8
        result.pieceCounts[p.int] += 1
        file += 1
  result.white = parts[1] == "w"
  result.castlings.fill(false)
  if parts[2] != "-":
    for c in parts[2]:
      case c:
        of 'Q': result.castlings[0] = true
        of 'K': result.castlings[1] = true
        of 'q': result.castlings[2] = true
        of 'k': result.castlings[3] = true
        else: discard
  if parts[3] != "-":
    let file = parts[3][0].int - 'a'.int
    let rank = parts[3][1].int - '1'.int32
    result.enPassant = (file: file, rank: rank).fromCell
  else:
    result.enPassant = 0
  
  let king = result.myKing
  if result.isChecked(king):
    result.checks = result.findChecks(king)
  else:
    result.checks = @[]