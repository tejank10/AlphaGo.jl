using BSON: @load
using AlphaGo

@load "agz_640_base" base
@load "agz_640_value" value
@load "agz_640_policy" policy

agz_nn = NeuralNet(base, value, policy)
agz = MCTSPlayer(agz_nn, num_readouts = 64, two_player_mode = true)

initialize_game!(agz)
num_moves = 0

while !is_done(agz)
  print(get_position(agz))

  if num_moves % 2 == 0
    move = input("Your move: ")
  else
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

    move = pick_move(active)
  end

  play_move!(agz, move)
  num_moves += 1
end


end
