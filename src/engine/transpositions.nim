import board, compact_board
import random, math, hashes

type ZobristLUT = (array[144, array[PieceType, Zobrist]], array[4, Zobrist])

proc generateLUT(): ZobristLUT {.compiletime.} =
  var rng = initRand(0x1337DEADBEEF)
  for r in 0..7:
    for f in 0..7:
      for t in [BlackKing, BlackQueen, BlackBishop, BlackKnight, BlackRook, BlackPawn,
          WhiteKing, WhiteQueen, WhiteBishop, WhiteKnight, WhiteRook, BlackPawn]:
        result[0][cellIndex(f, r)][t] = rng.next().Zobrist
  for i in 0..3:
    result[1][i] = rng.next().Zobrist

const zobLut: ZobristLUT = generateLUT()

proc `xor`(a, b: Zobrist): Zobrist {.inline.} = Zobrist(a.uint64 xor b.uint64)

proc flip*(z: Zobrist, c: CellIndex, p: PieceType): Zobrist {.inline.} = z xor zobLut[0][c][p]
proc flip*(z: Zobrist, c: CellIndex, p: int8): Zobrist {.inline.} = z.flip(c, p.PieceType)
proc removeCastling*(z: Zobrist, i: int): Zobrist {.inline.} = z xor zobLut[1][i]

proc toZobrist*(state: GameState): Zobrist =
  result = Zobrist(0)
  for r in 0..7:
    for f in 0..7:
      let i = cellIndex(f, r)
      if state.board[i] != 0:
        result = result.flip(i, state.board[i].PieceType)
  for i in 0..3:
    if not state.castlings[i]:
      result = result.removeCastling(i)

const TranspositionBits = 12
const TranspositionSize = 2^TranspositionBits
const TranspositionMask = TranspositionSize - 1
type TransTable* = array[TranspositionSize, (Zobrist, float)]

proc initTransTable*(): TransTable =
  for i in 0..<TranspositionSize:
    result[i] = (Zobrist(0), 0.0)

proc `[]`*(t: TransTable, z: Zobrist): float {.inline.} =
  t[hash(z.uint64) and TranspositionMask][1]
proc has*(t: TransTable, z: Zobrist): bool {.inline.} =
  t[hash(z.uint64) and TranspositionMask][0].uint64 == z.uint64
proc `[]=`*(t: var TransTable, z: Zobrist, f: float) {.inline.} =
  t[hash(z.uint64) and TranspositionMask] = (z, f)