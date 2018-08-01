using BSON: @load

function load_model(str, env::GameEnv)
  @load str*"/agz_base.bson" bn
  @load str*"/agz_value.bson" value
  @load str*"/agz_policy.bson" policy

  @load str*"/weights/agz_base.bson" bn_weights
  @load str*"/weights/agz_value.bson" val_weights
  @load str*"/weights/agz_policy.bson" pol_weights

  Flux.loadparams!(bn, bn_weights)
  Flux.loadparams!(value, val_weights)
  Flux.loadparams!(policy, pol_weights)
                
  bn  = mapleaves(cu, bn)
  val = mapleaves(cu, value)
  pol = mapleaves(cu, policy)

  NeuralNet(env; base_net=bn, value=val, policy=pol)
end


# Plays with user
function play(env::GameEnv, nn = nothing; tower_height = 19, num_readouts = 800, mode = 0) #mode=0, human starts with black, else starts with white
  @assert 0 ≤ tower_height ≤ 19

  if nn == nothing
    nn = NeuralNet(env; tower_height = tower_height)
  end

  az = MCTSPlayer(env, nn, num_readouts = num_readouts, two_player_mode = true)

  initialize_game!(az)
  num_moves = 0

  mode = mode == 0 ? mode : 1
  while !is_done(az)
    print(az.root.position)

    if num_moves % 2 == mode
      print("Your turn: ")
      move = readline(STDIN)
      try
      	move = from_kgs(move, az.env)
      catch
        println("Try again.")
      end
    else
      print("AlphaZero's turn: ")
      current_readouts = N(az.root)
      readouts = az.num_readouts

      while N(az.root) < current_readouts + readouts
        tree_search!(az)
      end

      move = pick_move(az)
      println(to_kgs(move, az.env))
    end
    if play_move!(az, move)
      num_moves += 1
    end
  end

  println(az.root.position)

  winner = result(az.root.position)
  set_result!(az, winner, false)
  mode = mode == 0 ? -1 : 1
  if winner == mode
    print("You Win! ")
  else
    print("AlphaZero wins! ")
  end
  println(az.result_string)
end
