mutable ChessPosition <: Position
  env::ChessEnv
  board::Board
  n::Int
  score::Float32
  recent::Vector{Move}
  history::Array{Board, 3}
  to_play::UInt8
  done::Bool

  function ChessPosition(env::ChessEnv; board = nothing, n = 0,
    recent = Vector{Move}(), board_deltas = nothing, to_play = NONE)

    b = board != nothing ? board : Board()
    bd = board_deltas != nothing ? board_deltas : zeros(Int8, env.N, env.N, 0)
    new(env, b, n, komi, caps, lib_trac, ko, recent, bd, to_play, false)
  end
end

get_first_n(x::Array{Board, 3}, n) = size(x, 3) < n ? x : x[:, :, 1:n]

function is_move_legal(pos::ChessPosition, c)
  moves = generate_moves(pos)
  c in moves
end

function all_legal_moves(pos::ChessPosition)
  moves = generate_moves(pos)
  flat_moves = zeros(pos.env.action_space)
  for move in moves
    flat_moves[to_flat(move)] = 1
  end
  return flat_moves
end

function play_move!(pos::ChessPosition, c::Move; mutate=false)
  new_pos = mutate ? deepcopy(pos) : pos

  @assert !new_pos.done

  if !is_move_legal(pos, c)
    throw(IllegalMove())
  end

  prev_pos = deepcopy(pos)
  make_move!(new_pos, c)
  opp_color = -pos.to_play

  new_pos.n += 1
  push!(new_pos.recent, c)
  # keep a rolling history of last 7 positions - that's all we'll need to
  # extract the last 8 board states.

  new_pos.history = vcat(prev_pos, get_first_n(new_pos.history, 6))
  new_pos.to_play *= -1
  return new_pos
end

function result(pos::ChessPosition)
  moves = generate_moves(board)
  if number_of_moves(board.game_movelist)==0
    if is_king_in_check(board)
      return pos.to_play $ 3
    else
      return NONE # Draw game
    end
  end
  return -1 # Implies the game has not ended
end

function result_string(pos::ChessPosition)
  res = result(pos)
  if result == Chess.BLACK
    return "BLACK"
  elseif result == Chess.WHITE
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
