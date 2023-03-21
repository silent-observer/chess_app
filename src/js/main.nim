import dom
import jsffi
import jsconsole
import ../engine/board
from strutils import parseInt
import fusion/js/jsxmlhttprequest
import tables
from sequtils import toSeq
import json

const pieceImages = [
  "black_king".cstring,
  "black_queen".cstring,
  "black_bishop".cstring,
  "black_knight".cstring,
  "black_rook".cstring,
  "black_pawn".cstring,
  "".cstring,
  "white_pawn".cstring,
  "white_rook".cstring,
  "white_knight".cstring,
  "white_bishop".cstring,
  "white_queen".cstring,
  "white_king".cstring,
]

var boardState: Board
var availableMoves: MoveSet
var dragging: Element = nil

proc typeToIndex(t: PieceType): int {.inline.} =
  t.int + 6

proc updatePieces(boardState: Board) =
  let board = getElementById("chess-board")
  for rank in 0..7:
    for file in 0..7:
      let cell = board.children[7-rank].children[file]
      cell.innerHTML = ""
      if boardState[file][rank] != Empty:
        let piece = document.createElement("div")
        let pieceType = boardState[file][rank]
        piece.style.backgroundImage = "url(resources/".cstring & pieceImages[pieceType.typeToIndex] & ".png)"
        piece.classList.add "piece"
        if pieceType.int > 0:
          piece.classList.add "draggable-piece"
        cell.appendChild(piece)

        piece.addEventListener("mousedown", proc(event: Event) =
          if "draggable-piece" in event.currentTarget.Element.classList:
            dragging = event.currentTarget.Element
            dragging.classList.add "dragging"
            let
              rank = parseInt($dragging.parentElement.getAttribute("rank"))
              file = parseInt($dragging.parentElement.getAttribute("file"))
            if (file: file, rank: rank) in availableMoves:
              for (c, capture) in availableMoves[(file: file, rank: rank)]:
                let cell = board.children[7-c.rank].children[c.file].Element
                cell.classList.add "move-possible"
        )

proc generateBoard() =
  let board = getElementById("chess-board")
  board.innerHTML = ""
  for i in 0..7:
    let row = document.createElement "tr"
    row.classList.add "chess-board-row"
    row.setAttr("draggable", "false")
    row.setAttr("ondragstart", "return false;")
    board.appendChild row
    for j in 0..7:
      let cell = document.createElement "td"
      cell.classList.add "chess-board-cell"
      if (i + j) mod 2 == 0:
        cell.classList.add "cell-white"
      else:
        cell.classList.add "cell-black"
      cell.setAttr("draggable", "false")
      cell.setAttr("ondragstart", "return false;")
      cell.setAttr("rank", $(7-i))
      cell.setAttr("file", $j)
      row.appendChild cell

proc `onreadystatechange=`(this: XMLHttpRequest, callback: proc ()) {.importjs: "#.$1 #".}

proc getMoves(request: XMLHttpRequest, callback: proc() = nil) =
  if request.readystate != 4: return
  if request.status != 200:
    console.log(request.statusText)
  else:
    let (b, m) = fromJson($request.responseText)
    boardState = b
    availableMoves = m
  if not callback.isNil:
    callback()


proc updateCurrentState(callback: proc()) =
  let request = newXMLHttpRequest()
  request.open("GET".cstring, cstring(window.location.href & "state"))
  
  request.onreadystatechange = (proc() = request.getMoves(callback))
  request.send()

proc checkUpdates() =
  let request = newXMLHttpRequest()
  request.open("GET".cstring, cstring(window.location.href & "update"))
  
  request.onreadystatechange = (proc() =
    if request.readystate != 4: return
    if request.status != 200:
      console.log(request.statusText)
    else:
      console.log(request.responseText)
      let json = parseJson($request.responseText)
      if "error" in json:
        if json["error"].str == "not ready":
          discard setTimeout(checkUpdates, 500)
        else:
          console.log(json["error"].str)
      else:
        let (b, m) = fromJson($request.responseText)
        boardState = b
        availableMoves = m
        updatePieces(boardState)
  )
  request.send()

proc promote(fromCell, toCell: Cell, capture: bool, mouseEvent: MouseEvent) =
  var prom: Element
  var sign: int
  if toCell.rank == 7:
    prom = getElementById("promotion-window-white")
    sign = 1
  elif toCell.rank == 0:
    prom = getElementById("promotion-window-black")
    sign = -1
  prom.style.display = "flex"
  prom.style.top = $(mouseEvent.pageY + 10) & "px"
  prom.style.left = $(mouseEvent.pageX + 10) & "px"
  for c in prom.children:
    c.addEventListener("click", proc(event: Event) =
      let c = event.currentTarget.Element
      for allC in prom.children:
        allC.outerHTML = allC.outerHTML
      prom.style.display = "none"
      
      console.log(c.id)
      let pieceType = case ($c.id)[^1]:
        of 'q': WhiteQueen
        of 'r': WhiteRook
        of 'b': WhiteBishop
        of 'k': WhiteKnight
        else: return
      
      boardState[toCell.file][toCell.rank] = PieceType(pieceType.int * sign)
      availableMoves.clear()
      updatePieces(boardState)

      let request = newXMLHttpRequest()
      request.open("POST".cstring, cstring(window.location.href & "move"))
      request.setRequestHeader("Content-Type".cstring, "application/json".cstring)
      request.onreadystatechange = (proc() =
        if request.readystate != 4: return
        request.getMoves()
        discard setTimeout(checkUpdates, 500)
      )
      request.send(toJson(
        Move(
          start: fromCell, 
          finish: toCell, 
          capture: capture
        ), pieceType).cstring)
    )

proc handleMove(rankBefore, fileBefore, rankAfter, fileAfter: int, mouseEvent: MouseEvent) =
  console.log($rankBefore & "-" & $fileBefore & " -> " & $rankAfter & "-" & $fileAfter)
  let fromCell = (file: fileBefore, rank: rankBefore)
  let toCell = (file: fileAfter, rank: rankAfter)
  if fromCell in availableMoves:
    var capture = false
    var found = false
    console.log(availableMoves[fromCell])
    for (c, cap) in availableMoves[fromCell]:
      if c == toCell:
        found = true
        capture = cap
        break
    if not found: return

    boardState[toCell.file][toCell.rank] = boardState[fromCell.file][fromCell.rank]
    boardState[fromCell.file][fromCell.rank] = Empty
    availableMoves.clear()
    updatePieces(boardState)

    if toCell.rank == 7 and boardState[toCell.file][toCell.rank] == WhitePawn:
      promote(fromCell, toCell, capture, mouseEvent)
    else:
      let request = newXMLHttpRequest()
      request.open("POST".cstring, cstring(window.location.href & "move"))
      request.setRequestHeader("Content-Type".cstring, "application/json".cstring)
      request.onreadystatechange = (proc() =
        if request.readystate != 4: return
        request.getMoves()
        discard setTimeout(checkUpdates, 500)
      )
      request.send(Move(start: fromCell, finish: toCell, capture: capture).toJson.cstring)

proc onLoad(event: Event) =
  let board = getElementById("chess-board")
  generateBoard()

  updateCurrentState(proc() =
    updatePieces(boardState)
  )
  
  document.addEventListener("mousemove", proc(event: Event) =
    if not dragging.isNil:
      dragging.style.position = "absolute"
      dragging.style.top = $(event.MouseEvent.pageY - 50) & "px"
      dragging.style.left = $(event.MouseEvent.pageX - 50) & "px"
  )
  
  proc clearDragging() =
    dragging.style.position = "static"
    dragging.classList.remove "dragging"
    dragging = nil
    let movesPossible = document.getElementsByClassName("move-possible").toSeq
    for cell in movesPossible:
      cell.classList.remove "move-possible"

  for rank in 0..7:
    for file in 0..7:
      let cell = board.children[7-rank].children[file]
      cell.addEventListener("mouseup", proc(event: Event) =
        if not dragging.isNil:
          let
            rankBefore = parseInt($dragging.parentElement.getAttribute("rank"))
            fileBefore = parseInt($dragging.parentElement.getAttribute("file"))
            rankAfter = parseInt($event.currentTarget.Element.getAttribute("rank"))
            fileAfter = parseInt($event.currentTarget.Element.getAttribute("file"))
          handleMove(rankBefore, fileBefore, rankAfter, fileAfter, event.MouseEvent)
          clearDragging()
      )
  document.addEventListener("mouseup", proc(event: Event) =
    if not dragging.isNil:
      clearDragging()
  )

window.onLoad = onLoad