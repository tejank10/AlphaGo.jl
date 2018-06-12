# Run set_board_size(N::Int) once you include go.jl

module AlphaGo
using Flux
using Flux: crossentropy, back!, mse
using StatsBase: Weights

export MCTSPlayer, NeuralNet, tree_search!, pick_move, play_move!,
      set_all_params, initialize_game!, extract_data, set_result!,
      should_resign, is_done, evaluate, result, train!, selfplay

include("go.jl")
include("mcts.jl")
include("mcts_play.jl")
include("features.jl")
include("neural_net.jl")
include("selfplay.jl")

using .go

function set_all_params(n::Int)
  go.set_board_size(n)
  set_mcts_params()
end

result(pos::go.Position) = go.result(pos)

end
