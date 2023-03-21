import board
import compact_board, checks, transpositions

proc getMoves(s: GameState, c: CellIndex): seq[(CellIndex, int8)] =
  let pieceSign = if s.board[c] > 0: 1 else: -1
  let piece = abs(s.board[c])
  if piece == WhitePawn.int8:
    if s.white:
      if s.board[c + Up] == 0: result.add (c + Up, 0'i8)
      if s.board[c + Up + Left] != WallCell and s.board[c + Up + Left] < 0: result.add (c + Up + Left, s.board[c + Up + Left])
      if s.board[c + Up + Right] != WallCell and s.board[c + Up + Right] < 0: result.add (c + Up + Right, s.board[c + Up + Right])
      if c.rank == 1 and s.board[c + Up] == 0 and s.board[c + Up + Up] == 0: result.add (c + Up + Up, 0'i8)
    else:
      if s.board[c + Down] == 0: result.add (c + Down, 0'i8)
      if s.board[c + Down + Left] != WallCell and s.board[c + Down + Left] > 0: result.add (c + Down + Left, s.board[c + Down + Left])
      if s.board[c + Down + Right] != WallCell and s.board[c + Down + Right] > 0: result.add (c + Down + Right, s.board[c + Down + Right])
      if c.rank == 6 and s.board[c + Down] == 0 and s.board[c + Down + Down] == 0: result.add (c + Down + Down, 0'i8)
  elif piece == WhiteKnight.int8:
    const KnightMoves = [
      Up + Up + Right, Up + Up + Left,
      Down + Down + Right, Down + Down + Left,
      Left + Left + Up, Left + Left + Down,
      Right + Right + Up, Right + Right + Down
    ]
    for m in KnightMoves:
      if s.board[c + m] != WallCell and s.board[c + m] * pieceSign <= 0:
        result.add (c+m, s.board[c+m])
  elif piece == WhiteKing.int8:
    const KingMoves = [Up, Down, Left, Right, Up+Left, Up+Right, Down+Left, Down+Right]
    for m in KingMoves:
      if s.board[c + m] != WallCell and s.board[c + m] * pieceSign <= 0:
        if not s.isChecked(c+m):
          result.add (c+m, s.board[c+m])
  else:
    template addMove(): untyped =
      if s.board[pos] == WallCell or s.board[pos] * pieceSign > 0: break
      result.add (pos, s.board[pos])
      if s.board[pos] * pieceSign < 0: break
    if piece != WhiteBishop.int:
      var pos = c
      while true:
        pos += Up
        addMove()
      pos = c
      while true:
        pos += Down
        addMove()
      pos = c
      while true:
        pos += Left
        addMove()
      pos = c
      while true:
        pos += Right
        addMove()
    
    if piece != WhiteRook.int:
      var pos = c
      while true:
        pos += Up + Left
        addMove()
      pos = c
      while true:
        pos += Down + Left
        addMove()
      pos = c
      while true:
        pos += Up + Right
        addMove()
      pos = c
      while true:
        pos += Down + Right
        addMove()

proc isBetween*(a, b, c: CellIndex): bool =
  if (a < b and c < b) or (a > b and c > b): return false
  if a.rank == b.rank and b.rank == c.rank: return true
  if a.file == b.file and b.file == c.file: return true
  if a.diag1 == b.diag1 and b.diag1 == c.diag1: return true
  if a.diag2 == b.diag2 and b.diag2 == c.diag2: return true
  return false

proc getPossibleMoves*(s: GameState): (seq[MoveData], seq[MoveData]) =
  let king = s.myKing
  if s.checks.len > 0:
    for (cell, capture) in s.getMoves(king):
      result[0].add MoveData(
        move: MoveIndex(start: king, finish: cell, capture: capture != 0),
        capturePiece: capture.PieceType,
        movePiece: s.board[king].PieceType)
    if s.checks.len == 1:
      let checkCell = s.checks[0][1]
      for c in 0..<144:
        if c == king: continue
        if s.board[c] == WallCell or s.board[c] == 0: continue
        if s.white and s.board[c] < 0: continue
        if not s.white and s.board[c] > 0: continue
        if c.rank == 6 and s.board[c] == WhitePawn.int8 or
           c.rank == 1 and s.board[c] == BlackPawn.int8:
          for (cell, capture) in s.getMoves(c):
            if cell != checkCell and not isBetween(checkCell, cell, king): continue
            if not s.checkPinned((c, cell)):
              result[1].add MoveData(
                move: MoveIndex(start: c, finish: cell, capture: capture != 0),
                capturePiece: capture.PieceType,
                movePiece: s.board[c].PieceType)
        else:
          for (cell, capture) in s.getMoves(c):
            if cell != checkCell and not isBetween(checkCell, cell, king): continue
            if not s.checkPinned((c, cell)):
              result[0].add MoveData(
                move: MoveIndex(start: c, finish: cell, capture: capture != 0),
                capturePiece: capture.PieceType,
                movePiece: s.board[c].PieceType)
      if s.enPassant != 0:
        if s.white and s.checks[0][0] == BlackPawn and s.enPassant == checkCell + Up:
          if s.board[s.enPassant + Down + Left] == WhitePawn.int8:
            if not s.checkEnPassant(s.enPassant + Down + Left):
              result[0].add MoveData(
                move: MoveIndex(
                  start: s.enPassant + Down + Left, 
                  finish: s.enPassant,
                  capture: true
                ),
                capturePiece: BlackPawn,
                movePiece: WhitePawn)
          if s.board[s.enPassant + Down + Right] == WhitePawn.int8:
            if not s.checkEnPassant(s.enPassant + Down + Right):
              result[0].add MoveData(
                move: MoveIndex(
                  start: s.enPassant + Down + Right, 
                  finish: s.enPassant,
                  capture: true
                ),
                capturePiece: BlackPawn,
                movePiece: WhitePawn)
        elif not s.white and s.checks[0][0] == WhitePawn and s.enPassant == checkCell + Down:
          if s.board[s.enPassant + Up + Left] == BlackPawn.int8:
            if not s.checkEnPassant(s.enPassant + Up + Left):
              result[0].add MoveData(
                move: MoveIndex(
                  start: s.enPassant + Up + Left, 
                  finish: s.enPassant,
                  capture: true
                ),
                capturePiece: WhitePawn,
                movePiece: BlackPawn)
          if s.board[s.enPassant + Up + Right] == BlackPawn.int8:
            if not s.checkEnPassant(s.enPassant + Up + Right):
              result[0].add MoveData(
                move: MoveIndex(
                  start: s.enPassant + Up + Right, 
                  finish: s.enPassant,
                  capture: true
                ),
                capturePiece: WhitePawn,
                movePiece: BlackPawn)
    return

  for c in 0..<144:
    if s.board[c] == WallCell or s.board[c] == 0: continue
    if s.white and s.board[c] < 0: continue
    if not s.white and s.board[c] > 0: continue
    if c.rank == 6 and s.board[c] == WhitePawn.int8 or
       c.rank == 1 and s.board[c] == BlackPawn.int8:
      for (cell, capture) in s.getMoves(c):
        if not s.checkPinned((c, cell)):
          result[1].add MoveData(
            move: MoveIndex(start: c, finish: cell, capture: capture != 0),
            capturePiece: capture.PieceType,
            movePiece: s.board[c].PieceType
          )
    else:
      for (cell, capture) in s.getMoves(c):
        if not s.checkPinned((c, cell)):
          result[0].add MoveData(
            move: MoveIndex(start: c, finish: cell, capture: capture != 0),
            capturePiece: capture.PieceType,
            movePiece: s.board[c].PieceType
          )
  if s.white and s.castlings[0]:
    if s.board[cellIndex(1, 0)] == 0 and
       s.board[cellIndex(2, 0)] == 0 and
       s.board[cellIndex(3, 0)] == 0 and
       not s.isChecked(cellIndex(3, 0)) and
       not s.isChecked(cellIndex(2, 0)):
      result[0].add MoveData(
        move: MoveIndex(
          start: cellIndex(4, 0),
          finish: cellIndex(2, 0),
          capture: false
        ), 
        capturePiece: Empty, 
        movePiece: WhiteKing
      )
  if s.white and s.castlings[1]:
    if s.board[cellIndex(5, 0)] == 0 and
       s.board[cellIndex(6, 0)] == 0 and
       not s.isChecked(cellIndex(5, 0)) and
       not s.isChecked(cellIndex(6, 0)):
      result[0].add MoveData(
        move: MoveIndex(
          start: cellIndex(4, 0),
          finish: cellIndex(6, 0),
          capture: false
        ), 
        capturePiece: Empty, 
        movePiece: WhiteKing
      )
  if not s.white and s.castlings[2]:
    if s.board[cellIndex(1, 7)] == 0 and
       s.board[cellIndex(2, 7)] == 0 and
       s.board[cellIndex(3, 7)] == 0 and
       not s.isChecked(cellIndex(3, 7)) and
       not s.isChecked(cellIndex(2, 7)):
      result[0].add MoveData(
        move: MoveIndex(
          start: cellIndex(4, 7),
          finish: cellIndex(2, 7),
          capture: false
        ), 
        capturePiece: Empty, 
        movePiece: BlackKing
      )
  if not s.white and s.castlings[3]:
    if s.board[cellIndex(5, 7)] == 0 and
       s.board[cellIndex(6, 7)] == 0 and
       not s.isChecked(cellIndex(5, 7)) and
       not s.isChecked(cellIndex(6, 7)):
      result[0].add MoveData(
        move: MoveIndex(
          start: cellIndex(4, 7),
          finish: cellIndex(6, 7),
          capture: false
        ), 
        capturePiece: Empty, 
        movePiece: BlackKing
      )
  if s.enPassant != 0:
    if s.white and s.enPassant.rank == 5:
      if s.board[s.enPassant + Down + Left] == WhitePawn.int8:
        if not s.checkEnPassant(s.enPassant + Down + Left):
          result[0].add MoveData(
            move: MoveIndex(
              start: s.enPassant + Down + Left, 
              finish: s.enPassant,
              capture: true
            ),
            capturePiece: BlackPawn,
            movePiece: WhitePawn
          )
      if s.board[s.enPassant + Down + Right] == WhitePawn.int8:
        if not s.checkEnPassant(s.enPassant + Down + Right):
          result[0].add MoveData(
            move: MoveIndex(
              start: s.enPassant + Down + Right, 
              finish: s.enPassant,
              capture: true
            ),
            capturePiece: BlackPawn,
            movePiece: WhitePawn
          )
    elif not s.white and s.enPassant.rank == 2:
      if s.board[s.enPassant + Up + Left] == BlackPawn.int8:
        if not s.checkEnPassant(s.enPassant + Up + Left):
          result[0].add MoveData(
            move: MoveIndex(
              start: s.enPassant + Up + Left, 
              finish: s.enPassant,
              capture: true
            ),
            capturePiece: WhitePawn,
            movePiece: BlackPawn
          )
      if s.board[s.enPassant + Up + Right] == BlackPawn.int8:
        if not s.checkEnPassant(s.enPassant + Up + Right):
          result[0].add MoveData(
            move: MoveIndex(
              start: s.enPassant + Up + Right,
              finish: s.enPassant,
              capture: true
            ),
            capturePiece: WhitePawn,
            movePiece: BlackPawn
          )
  if s.white:
    for m in result[0].mitems:
      if s.board[m.move.finish + Up + Right] == BlackPawn.int8:
        m.underPawnAttack = true
      elif s.board[m.move.finish + Up + Left] == BlackPawn.int8:
        m.underPawnAttack = true
  else:
    for m in result[0].mitems:
      if s.board[m.move.finish + Down + Right] == WhitePawn.int8:
        m.underPawnAttack = true
      elif s.board[m.move.finish + Down + Left] == WhitePawn.int8:
        m.underPawnAttack = true

proc simplify*(m: (seq[MoveData], seq[MoveData])): (seq[MoveIndex], seq[MoveIndex]) =
  result[0].setLen m[0].len
  result[1].setLen m[1].len
  for i in 0..<m[0].len:
    result[0][i] = m[0][i].move
  for i in 0..<m[1].len:
    result[1][i] = m[1][i].move

const
  Corner0 = cellIndex(0, 0)
  Corner1 = cellIndex(7, 0)
  Corner2 = cellIndex(0, 7)
  Corner3 = cellIndex(7, 7)

proc handleMove*(s: GameState, moveIndex: MoveIndex, promotion: PieceType): GameState =
  let (moves, proms) = s.getPossibleMoves().simplify()
  if moveIndex notin moves and moveIndex notin proms:
    echo "???"
    echo moves
    echo moveIndex
    quit()
    #return s

  result = s
  result.white = not s.white
  result.zobrist = s.zobrist
  if result.zobrist.uint64 == 0:
    result.zobrist = result.toZobrist()

  if promotion != Empty:
    if moveIndex.finish.rank == 7 and s.board[moveIndex.start] == WhitePawn.int8:
      if promotion in [WhiteQueen, WhiteRook, WhiteBishop, WhiteKnight]:
        result.zobrist = result.zobrist.flip(moveIndex.finish, result.board[moveIndex.finish])
        result.board[moveIndex.finish] = promotion.int8
        result.zobrist = result.zobrist.flip(moveIndex.finish, promotion)
        
        result.pieceCounts[WhitePawn.int] -= 1
        result.pieceCounts[promotion.int] += 1
      else:
        return s
    elif moveIndex.finish.rank == 0 and s.board[moveIndex.start] == BlackPawn.int8:
      if promotion in [BlackQueen, BlackRook, BlackBishop, BlackKnight]:
          result.zobrist = result.zobrist.flip(moveIndex.finish, result.board[moveIndex.finish])
          result.board[moveIndex.finish] = promotion.int8
          result.zobrist = result.zobrist.flip(moveIndex.finish, promotion)
          
          result.pieceCounts[BlackPawn.int] -= 1
          result.pieceCounts[promotion.int] += 1
      else: 
        return s
    else: 
      return s
  else:
    result.zobrist = result.zobrist.flip(moveIndex.finish, s.board[moveIndex.finish])
    result.board[moveIndex.finish] = s.board[moveIndex.start]
    result.zobrist = result.zobrist.flip(moveIndex.finish, s.board[moveIndex.start])
    if s.board[moveIndex.finish] != 0:
      result.pieceCounts[s.board[moveIndex.finish]] -= 1
  
  result.zobrist = result.zobrist.flip(moveIndex.start, result.board[moveIndex.start])
  result.board[moveIndex.start] = 0
  if s.board[moveIndex.start] == WhitePawn.int8 and moveIndex.capture and
     s.board[moveIndex.finish] == 0:
    result.board[moveIndex.finish + Down] = 0
    result.zobrist = result.zobrist.flip(moveIndex.finish + Down, BlackPawn)
    result.pieceCounts[BlackPawn.int] -= 1
  if s.board[moveIndex.start] == BlackPawn.int8 and moveIndex.capture and
     s.board[moveIndex.finish] == 0:
    result.board[moveIndex.finish + Up] = 0
    result.zobrist = result.zobrist.flip(moveIndex.finish + Up, WhitePawn)
    result.pieceCounts[WhitePawn.int] -= 1

  if s.board[moveIndex.start] == WhiteKing.int8:
    result.kingPositions[0] = moveIndex.finish
    if moveIndex.start == cellIndex(4, 0) and moveIndex.finish == cellIndex(2, 0):
      result.board[cellIndex(3, 0)] = WhiteRook.int8
      result.board[cellIndex(0, 0)] = 0
      result.zobrist = result.zobrist
        .flip(cellIndex(3, 0), WhiteRook)
        .flip(cellIndex(0, 0), WhiteRook)
    elif moveIndex.start == cellIndex(4, 0) and moveIndex.finish == cellIndex(6, 0):
      result.board[cellIndex(5, 0)] = WhiteRook.int8
      result.board[cellIndex(7, 0)] = 0
      result.zobrist = result.zobrist
        .flip(cellIndex(5, 0), WhiteRook)
        .flip(cellIndex(7, 0), WhiteRook)
    
    if result.castlings[0]:
      result.zobrist = result.zobrist.removeCastling(0)
    if result.castlings[1]:
      result.zobrist = result.zobrist.removeCastling(1)
    result.castlings[0] = false
    result.castlings[1] = false
  elif s.board[moveIndex.start] == BlackKing.int8:
    result.kingPositions[1] = moveIndex.finish
    if moveIndex.start == cellIndex(4, 7) and moveIndex.finish == cellIndex(2, 7):
      result.board[cellIndex(3, 7)] = BlackRook.int8
      result.board[cellIndex(0, 7)] = 0
      result.zobrist = result.zobrist
        .flip(cellIndex(3, 7), BlackRook)
        .flip(cellIndex(0, 7), BlackRook)
    elif moveIndex.start == cellIndex(4, 7) and moveIndex.finish == cellIndex(6, 7):
      result.board[cellIndex(5, 7)] = BlackRook.int8
      result.board[cellIndex(7, 7)] = 0
      result.zobrist = result.zobrist
        .flip(cellIndex(5, 7), BlackRook)
        .flip(cellIndex(7, 7), BlackRook)
    if result.castlings[2]:
      result.zobrist = result.zobrist.removeCastling(2)
    if result.castlings[3]:
      result.zobrist = result.zobrist.removeCastling(3)
    result.castlings[2] = false
    result.castlings[3] = false
  if moveIndex.start == Corner0 or moveIndex.finish == Corner0:
    if result.castlings[0]:
      result.zobrist = result.zobrist.removeCastling(0)
    result.castlings[0] = false
  elif moveIndex.start == Corner1 or moveIndex.finish == Corner1:
    if result.castlings[1]:
      result.zobrist = result.zobrist.removeCastling(1)
    result.castlings[1] = false
  elif moveIndex.start == Corner2 or moveIndex.finish == Corner2:
    if result.castlings[2]:
      result.zobrist = result.zobrist.removeCastling(2)
    result.castlings[2] = false
  elif moveIndex.start == Corner3 or moveIndex.finish == Corner3:
    if result.castlings[3]:
      result.zobrist = result.zobrist.removeCastling(3)
    result.castlings[3] = false
  
  result.enPassant = 0
  if s.board[moveIndex.start] == WhitePawn.int8 and 
      moveIndex.start.rank == 1 and 
      moveIndex.finish.rank == 3:
    result.enPassant = moveIndex.start + Up
  elif s.board[moveIndex.start] == BlackPawn.int8 and 
      moveIndex.start.rank == 6 and 
      moveIndex.finish.rank == 4:
    result.enPassant = moveIndex.start + Down

  let king = result.myKing
  if result.isChecked(king):
    result.checks = result.findChecks(king)
  else:
    result.checks = @[]

proc handleMove*(s: GameState, m: Move, promotion: PieceType): GameState {.inline.} = 
  handleMove(s, m.fromMove, promotion)