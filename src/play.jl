using BSON: @load
using AlphaGo
using AlphaGo:N, go
using Flux
# CuArrays

set_all_params(9)

@load "../models/agz_128_base.bson" bn
@load "../models/agz_128_value.bson" value
@load "../models/agz_128_policy.bson" policy

@load "../models/weights/agz_128_base.bson" bn_weights
@load "../models/weights/agz_128_value.bson" val_weights
@load "../models/weights/agz_128_policy.bson" pol_weights

Flux.loadparams!(bn,bn_weights)
Flux.loadparams!(value, val_weights)
Flux.loadparams!(policy, pol_weights)

bn = mapleaves(cu, bn)
value = mapleaves(cu, value)
policy = mapleaves(cu, policy)

# agz_nn = NeuralNet(base_net = bn, value = value, policy = policy)
agz_nn = NeuralNet(;tower_height=1)
agz = MCTSPlayer(agz_nn, num_readouts = 64, two_player_mode = true)

initialize_game!(agz)
num_moves = 0

while !is_done(agz)
  print(agz.root.position)

  if num_moves % 2 == 0
    print("Your turn: ")
    move = input(STDIN)
    move = go.from_kgs(move)
  else
    print("AGZ's turn: ")
    current_readouts = N(agz.root)
    readouts = agz.num_readouts

    while N(agz.root) < current_readouts + readouts
      tree_search!(agz)
    end

    # First, check the roots for hopeless games.
    if should_resign(agz)  # Force resign
      set_result!(agz, -agz.root.position.to_play, true)
    end
    if is_done(agz)
      set_result!(agz, 0, false)
      break
    end

    move = pick_move(agz)
    println(go.to_kgs(move))
  end

  if play_move!(agz, move)
    num_moves += 1
  end
end

println(agz.result_string)
