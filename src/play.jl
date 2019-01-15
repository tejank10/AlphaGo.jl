using BSON: @load

function load_model(str, env::AbstractEnv, epochs::Integer)
  path = joinpath(dirname(@__DIR__), "models")

  @load path * "/ckpt_$epochs.bson" nn

  @load str*"/weights/base.bson" bn_weights
  @load str*"/weights/value.bson" val_weights
  @load str*"/weights/policy.bson" pol_weights

  loadparams!(nn.base_net, bn_weights)
  loadparams!(nn.value, val_weights)
  loadparams!(nn.policy, pol_weights)

  (@isdefined CuArrays )&& (nn = mapleaves(cu, nn))

  return nn
end


# Plays with user
function play(env::AbstractEnv, nn = nothing; res_blocks::UInt = BLOCKS,
              num_readouts::UInt = 800, play_as::String = "BLACK")
  @assert play_as == "BLACK" || play_as == "WHITE"

  if nn === nothing
    # Play with randomly initialized network
    nn = NeuralNet(env; tower_height = tower_height)
  end

  az = MCTSPlayer(env, nn, num_readouts = num_readouts, two_player_mode = true)

  initialize_game!(az, env)
  num_moves = 0

  mode = play_as == "BLACK" ? 0 : 1

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
      println(to_kgs(move, az.env.pos))
    end

    if play_move!(az, move; mutate=true)
      num_moves += 1
    end
  end

  pos = get_position(az)

  printnln(pos)

  winner = result(pos)
  set_result!(az, winner, false)
  mode = mode == 0 ? env["BLACK"] : env["WHITE"]

  if winner == mode
    print("You win! ")
  else
    print("AlphaZero wins! ")
  end

  println(az.result_string)
end
