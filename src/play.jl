using BSON: @load

function load_model(str)
  @load str*"/agz_base.bson" bn
  @load str*"/agz_value.bson" value
  @load str*"/agz_policy.bson" policy

  @load  str*"/weights/agz_base.bson" bn_weights
  @load str*"/weights/agz_value.bson" val_weights
  @load str*"/weights/agz_policy.bson" pol_weights

  Flux.loadparams!(bn, bn_weights)
  Flux.loadparams!(value, val_weights)
  Flux.loadparams!(policy, pol_weights)
                
  bn=mapleaves(cu, bn)
  val = mapleaves(cu, value)
  pol = mapleaves(cu, policy)

  NeuralNet(; base_net=bn, value=val, policy=pol)
end


# Plays with user
function play(nn = nothing; tower_height = 19, num_readouts = 800)
  @assert 0 ≤ tower_height ≤ 19

  if nn == nothing
    nn = NeuralNet(; tower_height = tower_height)
  end

  agz = MCTSPlayer(nn, num_readouts = num_readouts, two_player_mode = true)

  initialize_game!(agz)
  num_moves = 0

  while !is_done(agz)
    print(agz.root.position)

    if num_moves % 2 == 0
      print("Your turn: ")
      move = readline(STDIN)
      try
      	move = go.from_kgs(move)
      catch
        println("Illegal move! Try again.")
      end
    else
      print("AGZ's turn: ")
      current_readouts = N(agz.root)
      readouts = agz.num_readouts

      while N(agz.root) < current_readouts + readouts
        tree_search!(agz)
      end

      move = pick_move(agz)
      println(go.to_kgs(move))
    end
    if play_move!(agz, move)
      num_moves += 1
    end
  end

  winner = go.result(agz.root.position)
  set_result!(agz, winner, false)

  if winner == go.BLACK
    print("You Win! ")
  else
    print("AGZ wins! ")
  end
  println(agz.result_string)
end
