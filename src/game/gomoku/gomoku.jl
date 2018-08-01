struct GomokuEnv <: GameEnv
  N::Int
  n_in_row::Int
  action_space::Int
  planes::Int
  max_action_space::Int
  EMPTY_BOARD::Array{Int8, 2}

  function GomokuEnv(board_size::Int = 15, connect_row = 5, planes::Int = 17)
    N = board_size
    n_in_row = connect_row
    action_space = N ^ 2
    EMPTY_BOARD = zeros(Int8, N, N)
    @assert planes % 2 == 1
    planes = (planes - 1) ÷ 2

    new(N, n_in_row, action_space, planes, 361 , EMPTY_BOARD)
  end
end

include("board.jl")
include("coords.jl")
