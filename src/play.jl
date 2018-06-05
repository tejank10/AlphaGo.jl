using AlphaGo

set_all_params(9)

cur_nn = NeuralNet(; tower_height = 10)
prev_nn = deepcopy(cur_nn)

NUM_GAMES = 5000

MEM_SIZE = 100000
BATCH_SIZE = 32
EVAL_FREQ = 500

pos_buffer = Vector{AlphaGo.go.Position}()
π_buffer = Vector{Vector{Float32}}()
res_buffer = Vector{Int}()

function get_replay_batch(pos_buffer, π_buffer, res_buffer)
  idxs = rand(1:length(pos_buffer), BATCH_SIZE)
  pos_replay = pos_buffer[idxs]
  π_replay = hcat(π_buffer[idxs]...)
  res_replay = res_buffer[idxs]

  pos_replay, π_replay, res_replay
end

for i = 1:NUM_GAMES
  player = selfplay(cur_nn)
  p, π, v = extract_data(player)

  pos_buffer = vcat(pos_buffer, p)
  π_buffer = vcat(π_buffer, π)
  res_buffer = vcat(res_buffer, v)

  if length(pos_buffer) > MEM_SIZE
    pos_buffer = pos_buffer[end-MEM_SIZE+1:end]
    π_buffer = π_buffer[end-MEM_SIZE+1:end]
    res_buffer = res_buffer[end-MEM_SIZE+1:end]
  end

  replay_pos, replay_π, replay_res = get_replay_batch(pos_buffer, π_buffer, res_buffer)
  loss = train!(cur_nn, (replay_pos, replay_π, replay_res))

  print("Episode $i over. Loss: $loss")
  if i % EVAL_FREQ == 0
    cur_is_winner = evaluate(cur_nn, prev_nn; num_games = 200)
    if cur_is_winner
      prev_nn = deepcopy(cur_nn)
    else
      cur_nn = deepcopy(prev_nn)
    end
    print("Evaluated")
  end
  println()
end
