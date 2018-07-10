using BSON: @save

function get_replay_batch(pos_buffer, π_buffer, res_buffer; batch_size = 32)
  idxs = sample(1:length(pos_buffer), batch_size, replace=false)
  pos_replay = pos_buffer[idxs]
  π_replay = hcat(π_buffer[idxs]...)
  res_replay = res_buffer[idxs]
  return pos_replay, π_replay, res_replay
end

#TODO: Model save path

function save_model(nn::NeuralNet)
  # checking for path to save
  path = joinpath(Pkg.dir("AlphaGo"), "models")
  if !isdir(path) mkdir(path) end

  bn,value, policy = cpu.((nn.base_net, nn.value, nn.policy))
  @save path * "/agz_base.bson" bn
  @save path * "/agz_value.bson" value
  @save path * "/agz_policy.bson" policy

  # saving weights
  # checking for path to save weights
  path = path * "/weights"
  if !isdir(path) mkdir(path) end

  bn_weights  = cpu.(Tracker.data.(params(bn)))
  val_weights = cpu.(Tracker.data.(params(value)))
  pol_weights = cpu.(Tracker.data.(params(policy)))

  @save path * "/agz_base.bson" bn_weights
  @save path * "/weights/agz_value.bson" val_weights
  @save path * "/agz_policy.bson" pol_weights
end


function train(env::GameEnv; num_games::Int = 25000, memory_size::Int = 500000,
  batch_size::Int = 32, epochs = 1, ckp_freq::Int = 1000, readouts::Int = 800,
  tower_height::Int = 19, model = nothing, start_training_after = 50000)

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
   
    if length(pos_buffer) >= start_training_after
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
