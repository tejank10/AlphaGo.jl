module go

struct GoEnv
  N::Int
  action_space::Int
  max_action_space::Int
  EMPTY_BOARD::Array{Int8, 2}
  NEIGHBORS::Dict{NTuple{2, Int}, Array{NTuple{2, Int}, 1}}
  DIAGONALS::Dict{NTuple{2, Int}, Array{NTuple{2, Int}, 1}}

  function GoEnv(board_size::Int = 19)
    N = board_size
    action_space = N ^ 2 + 1 # plus 1 for pass move
    ALL_COORDS = [(i, j) for i = 1:N for j = 1:N]
    EMPTY_BOARD = zeros(Int8, N, N)

    check_bounds(c) = 1 <= c[1] <= N && 1 <= c[2] <= N

    NEIGHBORS = Dict((x, y) => filter(k->check_bounds(k),
                              [(x+1, y), (x-1, y), (x, y+1), (x, y-1)]) for (x, y) in ALL_COORDS)
    DIAGONALS = Dict((x, y) => filter(k->check_bounds(k),
                              [(x+1, y+1), (x+1, y-1), (x-1, y+1), (x-1, y-1)]) for (x, y) in ALL_COORDS)
    new(N, action_space, 361, EMPTY_BOARD, NEIGHBORS, DIAGONALS)
  end
end

include("board.jl")
include("coords.jl")

export all_legal_moves, play_move!, result_string, BLACK, WHITE, GoPosition,
        GoEnv, to_flat, from_flat


end
