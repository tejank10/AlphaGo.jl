import Base.show
import Base.deepcopy

import Base.==
==(m1::Move, m2::Move) =
    (m1.color_moving == m2.color_moving &&
    m1.piece_moving == m2.piece_moving &&
    m1.sqr_src == m2.sqr_src &&
    m1.sqr_dest == m2.sqr_dest &&
    m1.piece_taken == m2.piece_taken &&
    m1.castling == m2.castling &&
    m1.sqr_ep == m2.sqr_ep &&
    m1.promotion_to == m2.promotion_to)


mutable struct ChessPosition <: Position
  env::ChessEnv
  board::Board
  n::Int
  moves::Vector{Move}
  score::Float32
  recent::Vector{Move}
  history::Vector{Board}
  to_play::Int
  done::Bool

  function ChessPosition(env::ChessEnv; board = nothing, n = 0,
    recent = Vector{Move}(), history = nothing, moves = nothing)
    if board == nothing && moves == nothing
      board = new_game()
      moves = generate_moves(board)
      num_moves = number_of_moves(board.game_movelist)
      moves = moves[1:num_moves]
    end
    bd = history != nothing ? history : [board]
    to_play = board.side_to_move == 1 ? -1 : (board.side_to_move == 2 ? 1 : 0)
    new(env, board, n, moves, 0.0f0, recent, bd, to_play, false)
  end
end

get_first_n(x::Vector{Board}, n) = length(x) < n ? x : x[1:n]

is_move_legal(pos::ChessPosition, c::Move) = any([c == move for move in pos.moves])

function all_legal_moves(pos::ChessPosition)
  flat_moves = zeros(Float32, pos.env.action_space)
  for move in pos.moves
    flat_moves[to_flat(move, pos.to_play)] = 1
  end
  return flat_moves
end

is_done(pos::ChessPosition) = length(pos.moves) < 1

function play_move!(pos::ChessPosition, c::Move; mutate=false)
  new_pos = mutate ? pos : deepcopy(pos)

  @assert !new_pos.done
  #print(pos.moves, new_pos.moves)
  if !is_move_legal(pos, c)
    throw(IllegalMove())
  end

  prev_pos = deepcopy(pos)
  make_move!(new_pos.board, c)

  new_pos.n += 1
  push!(new_pos.recent, c)
  # keep a rolling history of last 7 positions - that's all we'll need to
  # extract the last 8 board states.

  new_pos.history = vcat(prev_pos.board, get_first_n(new_pos.history, 6))
  new_pos.to_play = new_pos.board.side_to_move == 1 ? -1 : (new_pos.board.side_to_move == 2 ? 1 : 0)
  moves = generate_moves(new_pos.board)
  new_pos.moves = moves[1:number_of_moves(new_pos.board.game_movelist)]
  new_pos.done = is_done(new_pos)
  return new_pos
end

function result(pos::ChessPosition)
  if number_of_moves(pos.board.game_movelist)==0
    if is_king_in_check(pos.board)
      return -pos.to_play
    end
  end
  return 0 # Draw game
end

function result_string(pos::ChessPosition)
  res = result(pos)
  if result == 1
    return "BLACK"
  elseif result == -1
    return "WHITE"
  end
  return "DRAW"
end

function replay_position(pos::ChessPosition, result)
  #=
  Wrapper for a Position which replays its history.
  Assumes an empty start position! (i.e. no handicap, and history must be exhaustive.)

  Result must be passed in, since a resign cannot be inferred from position
  history alone.

  for position_w_context in replay_position(position):
    print(position_w_context.position)
  =#
  pos.n == length(pos.recent) ? nothing : throw(AssertionError("Position history is incomplete"))
  replay_buffer = Vector{PositionWithContext}()
  dummy_pos = Position(pos.env)

  for player_move in pos.recent
    push!(replay_buffer, PositionWithContext(dummy_pos, player_move, result))
    dummy_pos = play_move!(dummy_pos, player_move, color = color)
  end
  return replay_buffer
end

Base.show(io::IO, pos::ChessPosition) = printbd(pos.board)

function Base.deepcopy(pos::ChessPosition)
  board = deepcopy(pos.board)
  recent = deepcopy.(pos.recent)
  history = deepcopy.(pos.history)
  ChessPosition(pos.env; board=board, n=pos.n, recent=recent, history=history, moves=pos.moves)
end
