using BSON: @save
using Flux.Tracker: data
using DataStructures: CircularBuffer

function get_replay_batch(pos_buffer, π_buffer, res_buffer; batch_size = BATCH_SIZE)
  idxs = sample(1:length(pos_buffer), batch_size, replace=false)

  pos_replay = pos_buffer[idxs]
  π_replay   = hcat(π_buffer[idxs]...)
  res_replay = res_buffer[idxs]

  return pos_replay, π_replay, res_replay
end

function save_model(nn::NeuralNet, epochs::Integer)
  # checking for path to save
  path = joinpath(dirname(@__DIR__), "models")
  !isdir(path) && mkdir(path)

  @save path * "/ckpt_$epochs.bson", nn

  # saving weights
  # checking for path to save weights
  path = path * "/weights_$epochs"
  !isdir(path) && mkdir(path)

  base_net, value, policy = nn.base_net, nn.value, nn.policy

  bn_weights  = cpu.(data.(params(base_net)))
  val_weights = cpu.(data.(params(value)))
  pol_weights = cpu.(data.(params(policy)))

  @save path * "/base.bson" bn_weights
  @save path * "/value.bson" val_weights
  @save path * "/policy.bson" pol_weights
end

function train(env::AbstractEnv; num_games::T = 25000, memory_size::T = BUFFER_SIZE,
            	 batch_size::T = 32, epochs::T = 1, ckp_freq::T = 1000, readouts::T = 800,
            	 tower_height::T = 19, model = nothing, start_training_after::T = 50000,
          		 duel::Bool = false) where T <: Integer

  model === nothing && (cur_nn = NeuralNet(env; tower_height = tower_height))

  duel && (prev_nn = deepcopy(cur_nn))

  pos_buffer = CircularBuffer{Position}(memory_size)
  π_buffer   = CircularBuffer{Vector{Float32}}(memory_size)
  res_buffer = CircularBuffer{Int8}(memory_size)

  push_data!(cb::CircularBuffer, v::Vector) = foreach(x->push!(cb, x), v)

  opt = ADAM ? ADAM(η) : Momentum(η, ρ)

  for i = 1:num_games
    player  = selfplay(env, cur_nn, readouts)
    poses, πs, vs = extract_data(player)

    push_data!.((pos_buffer, π_buffer, res_buffer), (poses, πs, vs))

    if length(pos_buffer) ≥ start_training_after
      replay_pos, replay_π, replay_res = get_replay_batch(pos_buffer, π_buffer, res_buffer;
							                                            batch_size = batch_size)
      loss = train_epoch(cur_nn, (replay_pos, replay_π, replay_res), opt; epochs = epochs)
      result = player.result_string
      num_moves = player.root.position.n
      print("Episode $(@sprintf("%5d", i)) over | ")
	    println("Loss: $(@sprintf("%.5f", loss)) | Winner: $result. Moves: $num_moves.")
    end

  	if duel
      cur_is_winner = evaluate(cur_nn, prev_nn; num_games = eval_games, ro = readouts)
      print("Evaluated. ")
      if cur_is_winner
     		prev_nn = deepcopy(cur_nn)
        println("Model updated. ")
      else
        cur_nn = deepcopy(prev_nn)
        println("Model retained. ")
      end
  	end

    if i % ckp_freq == 1
      save_model(cur_nn, i * epochs)
      println("Model saved. ")
    end

    println()
  end

  return cur_nn
end
