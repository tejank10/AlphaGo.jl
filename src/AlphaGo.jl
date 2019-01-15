module AlphaGo
#using CuArrays
using Flux
using Flux: crossentropy, back!, mse, @treelike, loadparams!
using StatsBase: Weights
using Printf: @sprintf

include("games/Game.jl")

using .Game
using .Game: from_flat, to_flat, from_kgs, replay_position
using .Game: GoPosition

get_feats(player) = get_feats(player.root.position)

export MCTSPlayer, pick_move, play_move!,
      initialize_game!, set_result!,
      Go, num_moves, action_space, max_action_space,
      result_string, is_done, get_feats, train

include("const.jl")
include("mcts.jl")
include("mcts_play.jl")

include("features.jl")
include("resnet.jl")
include("neural_net.jl")
include("selfplay.jl")
include("train.jl")
include("play.jl")


end #module
