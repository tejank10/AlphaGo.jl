using BSON: @save

function get_replay_batch(pos_buffer, π_buffer, res_buffer)
  idxs = rand(1:length(pos_buffer), BATCH_SIZE)
  pos_replay = pos_buffer[idxs]
  π_replay = hcat(π_buffer[idxs]...)
  res_replay = res_buffer[idxs]

  pos_replay, π_replay, res_replay
end

#TODO: Model save path

function save_model(nn::NeuralNet, iter)
  bn,value, policy = cpu.((nn.base_net, nn.value, nn.policy))
  @save "../models/agz_$(iter)_base.bson" bn
  @save "../models/agz_$(iter)_value.bson" value
  @save "../models/agz_$(iter)_policy.bson" policy

  # saving weights
  bn_weights = cpu.(Tracker.data.(params(bn)))
  val_weights = cpu.(Tracker.data.(params(value)))
  pol_weights = cpu.(Tracker.data.(params(policy)))

  @save "../models/weights/agz_$(iter)_base.bson" bn_weights
  @save "../models/weights/agz_$(iter)_value.bson" val_weights
  @save "../models/weights/agz_$(iter)_policy.bson" pol_weights
end


#TODO: default model??

function train(; num_games::Int = 25000, memory_size::Int = 500000,
  batch_size::Int = 32, eval_freq::Int = 1000, readouts::Int = 800,
  eval_games::Int=400, tower_height::Int = 19, model = nothing)

  @assert 0 ≤ tower_height ≤ 19

  if model == nothing
    cur_nn = NeuralNet(; tower_height = tower_height)
  else
    cur_nn = model
  end

  prev_nn = deepcopy(cur_nn)

  pos_buffer = Vector{AlphaGo.go.Position}()
  π_buffer = Vector{Vector{Float32}}()
  res_buffer = Vector{Int}()

  for i = 1:num_games
    player = selfplay(cur_nn, readouts)
    p, π, v = extract_data(player)

    pos_buffer = vcat(pos_buffer, p)
    π_buffer = vcat(π_buffer, π)
    res_buffer = vcat(res_buffer, v)

    if length(pos_buffer) > memory_size
      pos_buffer = pos_buffer[end-memory_size+1:end]
      π_buffer = π_buffer[end-memory_size+1:end]
      res_buffer = res_buffer[end-memory_size+1:end]
    end

    replay_pos, replay_π, replay_res = get_replay_batch(pos_buffer, π_buffer, res_buffer)
    loss = train!(cur_nn, (replay_pos, replay_π, replay_res))

    print("Episode $i over. Loss: $loss ")
    if i % eval_freq == 0
      cur_is_winner = evaluate(cur_nn, prev_nn; num_games = eval_games, ro = readouts)
      print("Evaluated. ")
      if cur_is_winner
        prev_nn = deepcopy(cur_nn)
        save_model(cur_nn, i)
        print("Model updated. ")
      else
        cur_nn = deepcopy(prev_nn)
        print("Model retained. ")
      end
    end

    println()
  end
end
