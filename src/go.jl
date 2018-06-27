# Run set_board_size(N::Int) once you include go.jl

module go
export show, is_over, step!, make_env

include("board.jl")
include("coords.jl")

N = 19
ALL_COORDS = [(i, j) for i = 1:N for j = 1:N]
EMPTY_BOARD = zeros(Int8, N, N)

check_bounds(c) = 1 <= c[1] <= N && 1 <= c[2] <= N

NEIGHBORS = Dict((x, y) => filter(k->check_bounds(k),
                          [(x+1, y), (x-1, y), (x, y+1), (x, y-1)]) for (x, y) in ALL_COORDS)
DIAGONALS = Dict((x, y) => filter(k->check_bounds(k),
                          [(x+1, y+1), (x+1, y-1), (x-1, y+1), (x-1, y-1)]) for (x, y) in ALL_COORDS)

action_space() = N * N  + 1 # N² + pass move

state_space() = N * N # Board size

mutable struct env
  pos::Position
end

show(io::IO, game::env) = show(game.pos)

is_over(game::env) = game.pos.done

function step!(game::env, action; coord = "KGS", show_board = false)
  s = game.pos.board, game.pos.to_play
  a = coord == "KGS" ? from_kgs(action) : from_sgf(action)
  r = 0
  try play_move!(game.pos, a; mutate = true) catch; r = -10 end # negative reward for playing illegal moves
  s′ = game.pos.board, game.pos.to_play
  done = game.pos.done
  if show_board
    print(game.pos)
  end
  return (s, a, r, s′, done)
end

function make_env(n::Int)
  set_board_size(n)
  return env(Position())
end

end
