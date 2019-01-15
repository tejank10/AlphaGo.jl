function selfplay(env::AbstractEnv, nn::NeuralNet, num_ro::Int = 800)
  #= Plays out a self-play match, returning
  - the final position
  - the n x N² tensor of floats representing the mcts search probabilities
  - the n-ary tensor of floats representing the original value-net estimate
  where n is the number of moves in the game =#

  # Disable resign in 5% of games
  resign_threshold = rand() < 0.05 ? -1.0 : -0.9

  player = MCTSPlayer(env, nn, num_readouts = num_ro,
                      resign_threshold = resign_threshold)

  readouts = player.num_readouts
  initialize_game!(player, env)

  # Must run this once at the start, so that noise injection actually
  # affects the first move of the game.
  first_node = select_leaf(player.root)
  prob, val = nn(first_node.position)
  incorporate_results!(first_node, prob.data, val.data, first_node)

  while true
    inject_noise!(player.root)
    current_readouts = N(player.root)

    # we want to do "X additional readouts", rather than "up to X readouts".
    while N(player.root) < current_readouts + readouts
      tree_search!(player)
    end

    if should_resign(player)
      set_result!(player, -get_position(player).to_play, true)
      break
    end

    move = pick_move(player)
    play_move!(player, move)

    if is_done(player.root)
      set_result!(player, result(get_position(player)), false)
      break
    end
  end

  return player
end
