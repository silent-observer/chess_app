import tables, json
from strutils import split, parseInt

type PieceType* = enum
  BlackKing = -6
  BlackQueen = -5
  BlackBishop = -4
  BlackKnight = -3
  BlackRook = -2
  BlackPawn = -1
  Empty = 0
  WhitePawn = 1
  WhiteRook = 2
  WhiteKnight = 3
  WhiteBishop = 4
  WhiteQueen = 5
  WhiteKing = 6
type Board* = array[0..7, array[0..7, PieceType]]
type Zobrist* = distinct uint64

proc initBoard*(): Board =
  for file in 0..7:
    result[file][1] = WhitePawn
    result[file][6] = BlackPawn
  result[0][0] = WhiteRook
  result[1][0] = WhiteKnight
  result[2][0] = WhiteBishop
  result[3][0] = WhiteQueen
  result[4][0] = WhiteKing
  result[5][0] = WhiteBishop
  result[6][0] = WhiteKnight
  result[7][0] = WhiteRook

  result[0][7] = BlackRook
  result[1][7] = BlackKnight
  result[2][7] = BlackBishop
  result[3][7] = BlackQueen
  result[4][7] = BlackKing
  result[5][7] = BlackBishop
  result[6][7] = BlackKnight
  result[7][7] = BlackRook

type Cell* = tuple[file: int, rank: int]
type Move* = object
  start*: Cell
  finish*: Cell
  capture*: bool
type MoveSet* = Table[Cell, seq[(Cell, bool)]]

proc cellToStr(c: Cell): string {.inline.} = $c.file & ";" & $c.rank
proc strToCell(s: string): Cell =
  let parts = s.split(';')
  return (file: parts[0].parseInt, rank: parts[1].parseInt)

proc toJson*(b: Board, m: MoveSet): string =
  var moves = newJObject()
  for fromCell, toCells in m:
    var arr = newJArray()
    for (c, capture) in toCells:
      if capture:
        arr.add %(c.cellToStr & "X")
      else:
        arr.add %c.cellToStr
    moves[fromCell.cellToStr] = arr
  
  var board = newJArray()
  for column in b:
    var columnArr = newJArray()
    for c in column:
      columnArr.add %c.int
    board.add columnArr
  let json = %* {
    "moves": moves,
    "board": board
  }
  return $json

proc fromJson*(jsonStr: string): (Board, MoveSet) =
  let json = jsonStr.parseJson()
  var file = 0
  for row in json["board"]:
    var rank = 0
    for cell in row:
      result[0][file][rank] = cell.num.PieceType
      rank += 1
    file += 1
  for key, val in json["moves"]:
    var arr: seq[(Cell, bool)] = @[]
    for c in val:
      let s = c.str
      if s[^1] == 'X':
        arr.add (s[0..^2].strToCell, true)
      else:
        arr.add (s.strToCell, false)
    result[1][key.strToCell] = arr

proc toJson*(m: Move): string =
  let json = %* {
    "from": { "file": m.start.file, "rank": m.start.rank },
    "to": { "file": m.finish.file, "rank": m.finish.rank },
    "capture": m.capture
  }
  return $json

proc toJson*(m: Move, promotion: PieceType): string =
  let json = %* {
    "from": { "file": m.start.file, "rank": m.start.rank },
    "to": { "file": m.finish.file, "rank": m.finish.rank },
    "capture": m.capture,
    "promotion": promotion.int
  }
  return $json

proc toMove*(jsonStr: string): (Move, PieceType) =
  let json = jsonStr.parseJson()
  let fromCell = (file: json["from"]["file"].num.int, rank: json["from"]["rank"].num.int)
  let toCell = (file: json["to"]["file"].num.int, rank: json["to"]["rank"].num.int)
  let promotion = json.getOrDefault("promotion").getInt(0)
  let capture = json.getOrDefault("capture").getBool(false)
  let m = Move(start: fromCell, finish: toCell, capture: capture)
  return (m, promotion.PieceType)