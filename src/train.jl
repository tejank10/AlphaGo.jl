using BSON: @save
using Flux.Tracker: data

function get_replay_batch(pos_buffer, π_buffer, res_buffer; batch_size = 32)
  idxs = sample(1:length(pos_buffer), batch_size, replace=false)

  pos_replay = pos_buffer[idxs]
  π_replay = hcat(π_buffer[idxs]...)
  res_replay = res_buffer[idxs]

  return pos_replay, π_replay, res_replay
end

function save_model(nn::NeuralNet)
  # checking for path to save
  path = joinpath(dirname(@__DIR__), "models")
  !isdir(path) && mkdir(path)

  @save path * "/agz_model.bson", nn
  
  # saving weights
  # checking for path to save weights
  path = path * "/weights"
  !isdir(path) && mkdir(path)
 
  base_net, value, policy = nn.base_net, nn.value, nn.policy

  bn_weights  = cpu.(data.(params(base_net)))
  val_weights = cpu.(data.(params(value)))
  pol_weights = cpu.(data.(params(policy)))

  @save path * "/agz_base.bson" bn_weights
  @save path * "/agz_value.bson" val_weights
  @save path * "/agz_policy.bson" pol_weights
end


function train(env::GameEnv; num_games::Int = 25000, memory_size::Int = 500000,
  batch_size::Int = 32, epochs = 1, ckp_freq::Int = 1000, readouts::Int = 800,
  tower_height::Int = 19, model = nothing, start_training_after = 50000)

  # @assert 0 ≤ tower_height ≤ 19
  cur_nn = model === nothing ? NeuralNet(env; tower_height = tower_height) : model

  # prev_nn = deepcopy(cur_nn)

  pos_buffer = Vector{Position}()
  π_buffer   = Vector{Vector{Float32}}()
  res_buffer = Vector{Int}()

  push_data(vec::Vector{T}, data::T) where T = vcat(vec, data)
  shrink(vec::Vector{T}) where T = vec[end-memory_size+1:end]
  
  opt = Momentum(2f-2)

  for i = 1:num_games
    player  = selfplay(env, cur_nn, readouts)
    p, π, v = extract_data(player)

    pos_buffer, π_buffer, res_buffer = 
      push_data.((pos_buffer, π_buffer, res_buffer), (p, π, v))

    if length(pos_buffer) > memory_size
      pos_buffer, π_buffer, res_buffer = shrink.((pos_buffer, π_buffer, res_buffer))
    end
   
    if length(pos_buffer) >= start_training_after
      replay_pos, replay_π, replay_res = get_replay_batch(pos_buffer, π_buffer, res_buffer; 
							  batch_size = batch_size)
      loss = _train(cur_nn, (replay_pos, replay_π, replay_res), opt; epochs = epochs)
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
