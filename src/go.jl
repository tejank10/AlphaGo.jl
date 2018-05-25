module go
export show, is_over, step!, make_env

include("board.jl")
include("utils.jl")

action_space = N * N  + 1 # N² + pass move

state_space = N * N # Board size

mutable struct env
  pos::Position
  action_space
  state_space
end

show(io::IO, game::env) = show(game.pos)

is_over(game::env) = game.pos.done

function step!(game::env, action)
  s = game.pos.board, game.pos.to_play
  a = action == nothing ? action : parse_kgs_coords(action)
  r = 0
  try play_move!(game.pos, a; mutate = true) catch; r = -10 end # negative reward for playing illegal moves
  s′ = game.pos.board, game.pos.to_play
  done = game.pos.done
  return (s, a, r, s′, done)
end

function make_env(n::Int)
  set_board_size(n)
  return env(Position(), n * n + 1, n * n)
end

end
