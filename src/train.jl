using BSON: @save

function get_replay_batch(pos_buffer, π_buffer, res_buffer; batch_size = 32)
  while true
    shfl = shuffle(1:length(pos_buffer))
    pos_buffer, π_buffer, res_buffer = pos_buffer[shfl], π_buffer[shfl], res_buffer[shfl]
    idxs = sample(1:length(pos_buffer), batch_size, replace=false)
    pos_replay = pos_buffer[idxs]
    π_replay = hcat(π_buffer[idxs]...)
    res_replay = res_buffer[idxs]
    if -5 < sum(res_replay) < 5
      return pos_replay, π_replay, res_replay
    end
  end
end

#TODO: Model save path

function save_model(nn::NeuralNet)
  bn,value, policy = cpu.((nn.base_net, nn.value, nn.policy))
  @save "../models/agz_base.bson" bn
  @save "../models/agz_value.bson" value
  @save "../models/agz_policy.bson" policy

  # saving weights
  bn_weights = cpu.(Tracker.data.(params(bn)))
  val_weights = cpu.(Tracker.data.(params(value)))
  pol_weights = cpu.(Tracker.data.(params(policy)))

  @save "../models/weights/agz_base.bson" bn_weights
  @save "../models/weights/agz_value.bson" val_weights
  @save "../models/weights/agz_policy.bson" pol_weights
end


function train(env::GameEnv; num_games::Int = 25000, memory_size::Int = 500000,
  batch_size::Int = 32, epochs = 1, ckp_freq::Int = 1000, readouts::Int = 800,
  tower_height::Int = 19, model = nothing)

  # @assert 0 ≤ tower_height ≤ 19
  cur_nn = nothing
  if model == nothing
    cur_nn = NeuralNet(env; tower_height = tower_height)
  else
    cur_nn = model
  end

  # prev_nn = deepcopy(cur_nn)

  pos_buffer = Vector{Position}()
  π_buffer = Vector{Vector{Float32}}()
  res_buffer = Vector{Int}()

  for i = 1:num_games
    player = selfplay(env, cur_nn, readouts)
    p, π, v = extract_data(player)

    pos_buffer = vcat(pos_buffer, p)
    π_buffer   = vcat(π_buffer, π)
    res_buffer = vcat(res_buffer, v)

    if length(pos_buffer) > memory_size
      pos_buffer = pos_buffer[end-memory_size+1:end]
      π_buffer   = π_buffer[end-memory_size+1:end]
      res_buffer = res_buffer[end-memory_size+1:end]
    end
     
    if length(pos_buffer) >= 1024
      replay_pos, replay_π, replay_res = get_replay_batch(pos_buffer, π_buffer, res_buffer; batch_size = batch_size)
      loss = train!(cur_nn, (replay_pos, replay_π, replay_res); epochs = epochs)
      result = player.result_string
      num_moves = player.root.position.n
      println("Episode $i over. Loss: $loss. Winner: $result. Moves: $num_moves.")
    end

  # cur_is_winner = evaluate(cur_nn, prev_nn; num_games = eval_games, ro = readouts)
  # print("Evaluated. ")
  # if cur_is_winner
  #   prev_nn = deepcopy(cur_nn)
  #   print("Model updated. ")
  # else
  #   cur_nn = deepcopy(prev_nn)
  #   print("Model retained. ")
  # end
        
    if i % ckp_freq == 0
      save_model(cur_nn)
      print("Model saved. ")
    end
  end
  return cur_nn
end
