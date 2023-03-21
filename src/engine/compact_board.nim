import board
import tables
from algorithm import fill

const WallCell* = 99;
type CompactBoard* = array[144, int8]
type CellIndex* = int
type CheckData* = (PieceType, CellIndex)
type GameState* = object
  board*: CompactBoard
  white*: bool
  castlings*: array[4, bool]
  enPassant*: CellIndex
  kingPositions*: array[2, CellIndex]
  pieceCounts*: array[-6..6, int]
  checks*: seq[CheckData]
  zobrist*: Zobrist
type MoveIndex* = object
  start*: CellIndex
  finish*: CellIndex
  capture*: bool
type MoveData* = object
  move*: MoveIndex
  movePiece*: PieceType
  capturePiece*: PieceType
  underPawnAttack*: bool

proc toCompact*(b: Board): CompactBoard =
  for i in 0..11:
    result[i*12] = WallCell
    result[i*12 + 1] = WallCell
    result[i*12 + 10] = WallCell
    result[i*12 + 11] = WallCell
  for i in 2..9:
    result[i] = WallCell
    result[i + 12] = WallCell
    result[i + 120] = WallCell
    result[i + 132] = WallCell
  for i in 0..7:
    for j in 0..7:
      result[i + j*12 + 26] = b[i][j].int8

proc emptyCompact*(): CompactBoard =
  result.fill(0)
  for i in 0..11:
    result[i*12] = WallCell
    result[i*12 + 1] = WallCell
    result[i*12 + 10] = WallCell
    result[i*12 + 11] = WallCell
  for i in 2..9:
    result[i] = WallCell
    result[i + 12] = WallCell
    result[i + 120] = WallCell
    result[i + 132] = WallCell

proc fromCompact*(b: CompactBoard): Board =
  for i in 0..7:
    for j in 0..7:
      result[i][j] = b[i + j*12 + 26].PieceType



proc fromCell*(c: Cell): CellIndex {.inline.} = c.file + c.rank*12 + 26
proc `[]`*(b: CompactBoard, c: Cell): int8 {.inline.} = b[c.fromCell]
proc `[]=`*(b: var CompactBoard, c: Cell, x: int8) {.inline.} = b[c.fromCell] = x

proc rank*(c: CellIndex): int {.inline.} = c div 12 - 2
proc file*(c: CellIndex): int {.inline.} = c mod 12 - 2
proc diag1*(c: CellIndex): int {.inline.} = c.rank + c.file
proc diag2*(c: CellIndex): int {.inline.} = c.rank - c.file
proc cell*(c: CellIndex): Cell {.inline.} = (file: c.file, rank: c.rank)
proc cellIndex*(file, rank: int): CellIndex {.inline.} = (file: file, rank: rank).fromCell
proc fromMove*(m: Move): MoveIndex {.inline.} = 
  MoveIndex(
    start: m.start.fromCell,
    finish: m.finish.fromCell,
    capture: m.capture
  )
proc toMove*(m: MoveIndex): Move {.inline.} =
  Move(
    start: m.start.cell,
    finish: m.finish.cell,
    capture: m.capture
  )

const 
  Up* = 12
  Down* = -12
  Right* = 1
  Left* = -1

proc toMoveSet*(moves: seq[MoveIndex]): MoveSet =
  for m in moves:
    if m.start.cell notin result:
      result[m.start.cell] = @[]
    result[m.start.cell].add (m.finish.cell, m.capture)

proc initGameState*(): GameState =
  result.board = initBoard().toCompact
  result.white = true
  result.castlings.fill(true)
  result.enPassant = 0
  result.kingPositions[0] = cellIndex(4, 0)
  result.kingPositions[1] = cellIndex(4, 7)
  result.pieceCounts = [1, 1, 2, 2, 2, 8, 0, 8, 2, 2, 2, 1, 1]
  result.checks = @[]

proc myKing*(s: GameState): CellIndex {.inline.} = 
  if s.white:
    s.kingPositions[0]
  else:
    s.kingPositions[1]