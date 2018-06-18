# Run set_board_size(N::Int) once you include go.jl

module AlphaGo
#using CuArrays
using Flux
using Flux: crossentropy, back!, mse
using StatsBase: Weights

export MCTSPlayer, NeuralNet, pick_move, play_move!,
      initialize_game!, extract_data, set_result!,
      should_resign, is_done, evaluate, result, train!, selfplay,
      train, play, load_model

include("game/go.jl")
include("mcts.jl")
include("mcts_play.jl")
include("features.jl")
include("neural_net.jl")
include("selfplay.jl")
include("train.jl")
include("play.jl")

using .go

function set_all_params(n::Int)
  go.set_board_size(n)
  set_mcts_params()
end

result(pos::go.Position) = go.result(pos)

end
