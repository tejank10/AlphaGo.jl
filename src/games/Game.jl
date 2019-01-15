module Game

#TODO: legal_moves -> legal_action_space to show all possible actions
# preferably on a board

struct IllegalMove <:Exception end

abstract type AbstractEnv end
abstract type Position end

export IllegalMove, AbstractEnv, Position, Go,
       action_space, max_action_space, board_size, legal_moves,
       init_position, num_moves, result, result_string


struct PositionWithContext
  position::Position
  next_move
  result::Int8
end

struct BoardEnv
  N::UInt8                         # size of the board
  action_space::UnitRange{Int}
  max_action_space::UnitRange{Int} # action space of max size of board
  planes::UInt                     # no. of past states to train neural network
end

board_size(env::AbstractEnv) = board_size(env.pos)

state(env::AbstractEnv) = env.pos
step!(env::AbstractEnv, move) = play_move!(env.pos, move, mutate = true)

num_moves(pos::Position) = pos.n
is_done(pos::Position) = pos.done

include("go.jl")
include("coords.jl")
#include("gomoku.jl")
end #module
