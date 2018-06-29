include("Chess.jl")
using Chess

struct ChessEnv <: GameEnv
  N::Int
  action_space::Int
  max_action_space::Int

  function ChessEnv()
    N = 8
    action_space = 8 * 8 * 73
    new(N, action_space, action_space)
  end
end

include("board_wrapper.jl")
include("move_wrapper.jl")
