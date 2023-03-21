import jester
import engine/[moves, board, compact_board, ai, checks, transpositions]
import random
import threadpool

include "templates/index.tmpl"

randomize()
var stateChan: Channel[GameState]
var counter = 0
stateChan.open()
stateChan.send(initGameState())

var nextMove: FlowVar[(MoveIndex, PieceType)] = nil

routes:
  get "/state":
    let state = stateChan.recv()
    stateChan.send(state)

    let (m, p) = state.getPossibleMoves().simplify()
    let json = toJson(state.board.fromCompact, toMoveSet(m & p))
    resp json, "application/json"
  post "/move":
    var state = stateChan.recv()
    let (move, prom) = toMove(request.body)
    state = state.handleMove(move, prom)
    #counter += 1
    stateChan.send state
    nextMove = spawn calculateNextMove(state)
    let (m, p) = state.getPossibleMoves().simplify()
    let json = toJson(state.board.fromCompact, toMoveSet(m & p))
    resp json, "application/json"
  get "/update":
    if nextMove.isNil:
      resp r"{""error"": ""no move""}", "application/json"
    if nextMove.isReady:
      var state = stateChan.recv()
      let (move, prom) = ^nextMove
      state = state.handleMove(move, prom)
      #counter += 1
      #if counter == 4:
      #  state = initGameState("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -")
      #  counter = 0
      stateChan.send state
      let (m, p) = state.getPossibleMoves().simplify()
      let json = toJson(state.board.fromCompact, toMoveSet(m & p))
      nextMove = nil
      resp json, "application/json"
    else:
      resp r"{""error"": ""not ready""}", "application/json"
  get "/":
    resp genIndex()