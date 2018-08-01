#=
This is Julia implementation of Gomoku Board by Tejan Karmali.
=#

import Base: ==, deepcopy, show
using IterTools: chain

# Cell occupants
#@enum CELL_OCC WHITE = -1 EMPTY BLACK  FILL KO UNKNOWN
WHITE, EMPTY, BLACK, FILL, KO, UNKNOWN = collect(-1:4)

# Represents "group not found" in the LibertyTracker object
MISSING_GROUP_ID = -1
#=
struct PlayerMove
  color
  move
end

# making a (x,y) coordinate for board from flattened index x
coordify(x; N = 19) = 1 + (x - 1) % N, 1 + (x - 1) ÷ N

get_first_n(x::Array{Int8, 3}, n) = size(x, 3) < n ? x : x[:, :, 1:n]
=#
mutable struct GomokuPosition <: Position
  #=
  board: an array
  n: an int representing moves played so far
  recent: a tuple of PlayerMoves, such that recent[end] is the last move.
  board_deltas: an array of shape (N, N, n) representing changes
      made to the board at each move (played move and captures).
      Should satisfy next_pos.board - next_pos.board_deltas[:, :, 0] == pos.board
  to_play: BLACK or WHITE
  =#
  env::GomokuEnv
  board::Array{Int8, 2}
  n::Int
  recent::Vector{PlayerMove}
  board_deltas::Array{Int8, 3}
  to_play::Int
  done::Bool
  winner::Int8
  function GomokuPosition(env::GomokuEnv; board = nothing, n = 0, recent = Vector{PlayerMove}(),
	board_deltas = nothing, to_play = BLACK)

    b = board != nothing ? board : deepcopy(env.EMPTY_BOARD)
    bd = board_deltas != nothing ? board_deltas : zeros(Int8, env.N, env.N, 0)
    done, winner = has_game_ended(b, env)

    new(env, b, n, recent, bd, to_play, done, winner)
  end
end

function deepcopy(pos::GomokuPosition)
  new_board = deepcopy(pos.board)
  new_recent = deepcopy(pos.recent)
  return GomokuPosition(pos.env; board = new_board, n = pos.n, recent = new_recent,
                  board_deltas = pos.board_deltas, to_play = pos.to_play)
end

function show(io::IO, pos::GomokuPosition)
  pretty_print_map = Dict{Int, String}([
            WHITE => "O",
            EMPTY => ".",
            BLACK => "X",
            FILL => "#",
        ])
  board = deepcopy(pos.board)
  N = size(board, 1)

  raw_board_contents = []
  for i = 1:N
    row = []
    for j = 1:N
      appended = length(pos.recent) != 0 && (i, j) == pos.recent[end].move ? "<" : " "
      push!(row, pretty_print_map[board[i,j]] * appended)
    end
    push!(raw_board_contents, join(row))
  end

  row_labels_fmt = [@sprintf("%2d ", i) for i = N:-1:1]
  row_labels = [string(i) for i = N:-1:1]
  annotated_board_contents = [join(r) for r in zip(row_labels_fmt, raw_board_contents, row_labels)]
  header_footer_rows = ["   " * join("ABCDEFGHJKLMNOPQRST"[1:N], " ") * "   "]
  annotated_board = join(collect(chain(header_footer_rows, annotated_board_contents,
                                        header_footer_rows)), "\n")
  details = "\nMove: $(pos.n)\n"
  turn = pos.done ? "GAME OVER\n" : "To Play: " * (pos.to_play == BLACK ? "X(BLACK)\n" : "O(WHITE)\n")
  println(annotated_board * details * turn)
end

is_move_legal(pos::GomokuPosition, move) = pos.board[move...] == EMPTY

all_legal_moves(pos::GomokuPosition) = vec(pos.board .== EMPTY)

has_game_ended(pos::GomokuPosition) = has_game_ended(pos.board, pos.env)

function has_game_ended(board::Array{Int8, 2}, env)
  n_in_row = env.n_in_row
  dim = env.N
  
  for h = 1:dim
    for w = 1:dim
      if w in 1:dim-n_in_row+1 && board[h,w]!=EMPTY
        pieces = Set([board[h, i] for i = w:w+n_in_row-1])
        length(pieces) == 1 && return true, collect(pieces)[1]
      end
      
      if h in 1:dim-n_in_row+1 && board[h,w]!=EMPTY 
        pieces = Set([board[i, w] for i = h:h+n_in_row-1])
	length(pieces) == 1 && return true, collect(pieces)[1]
      end
      
      if w in 1:dim-n_in_row+1 && h in 1:dim-n_in_row+1 && board[h,w]!=EMPTY 
        pieces = Set([board[h+i,w+i] for i=0:n_in_row-1])
        length(pieces) == 1 && return true, collect(pieces)[1]
      end
    
      if w in n_in_row:dim && h in 1:dim-n_in_row+1 && board[h,w]!=EMPTY
        pieces = Set([board[h+i,w-i] for i=0:n_in_row-1])
        length(pieces) == 1 && return true, collect(pieces)[1]
      end
    end
  end

  false, EMPTY
end

function flip_playerturn!(pos::GomokuPosition; mutate = false)
  new_pos = mutate ? pos : deepcopy(pos)
  new_pos.to_play *= -1
  return new_pos
end

function play_move!(pos::GomokuPosition, c; color = nothing, mutate = false)
  if color == nothing
    color = pos.to_play
  end
 
  new_pos = mutate ? pos : deepcopy(pos)

  @assert !new_pos.done

  if !is_move_legal(pos, c)
    throw(IllegalMove())
  end
  
  new_pos.board[c...] = color
  opp_color = -color

  N = size(pos.board, 1)

  new_board_delta = zeros(Int8, N, N)
  new_board_delta[c...] = color

  new_pos.n += 1
  push!(new_pos.recent, PlayerMove(color, c))
  # keep a rolling history of last 7 deltas - that's all we'll need to
  # extract the last 8 board states.

  new_pos.board_deltas = cat(3, reshape(new_board_delta, N, N, 1), get_first_n(new_pos.board_deltas, new_pos.env.planes-2))
  new_pos.to_play *= -1
  new_pos.done, new_pos.winner = has_game_ended(new_pos)
  return new_pos
end

score(pos::GomokuPosition) = pos.winner

function result(pos::GomokuPosition)
  points = score(pos)
  if points > 0
    return 1
  elseif points < 0
    return -1
  else
    return 0
  end
end

function result_string(pos::GomokuPosition)
  points = score(pos)
  if points > 0
    return "B"
  elseif points < 0
    return "W"
  else
    return "DRAW"
  end
end

function replay_position(pos::GomokuPosition, result)
  #=
  Wrapper for a go.GoPosition which replays its history.
  Assumes an empty start position! (i.e. no handicap, and history must be exhaustive.)

  Result must be passed in, since a resign cannot be inferred from position
  history alone.

  for position_w_context in replay_position(position):
    print(position_w_context.position)
  =#
  pos.n == length(pos.recent) ? nothing : throw(AssertionError("GomokuPosition history is incomplete"))
  replay_buffer = Vector{PositionWithContext}()
  dummy_pos = GomokuPosition(pos.env)

  for player_move in pos.recent
    color, next_move = player_move.color, player_move.move
    push!(replay_buffer, PositionWithContext(dummy_pos, next_move, result))
    dummy_pos = play_move!(dummy_pos, next_move, color = color)
  end
  return replay_buffer
end
