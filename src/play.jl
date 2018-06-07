using AlphaGo, CuArrays
using BSON: @load, @save

CL_FLAGS = ["-brd_sz", "-twr_ht", "-mem_sz", "-num_games", "-batch_sz", "-eval_frq", "-ro", "-eval_games"]

BOARD_SIZE = 19
TOWER_HEIGHT = 19
NUM_GAMES = 25000
MEM_SIZE = 500000
BATCH_SIZE = 2048
EVAL_FREQ = 1000
READOUTS = 800
EVAL_GAMES = 400

function parse_args()
  global BOARD_SIZE, TOWER_HEIGHT, NUM_GAMES, MEM_SIZE, BATCH_SIZE, EVAL_FREQ,
          READOUTS, EVAL_GAMES
  ix = findfirst(x->x=="-brd_sz", ARGS)
  if ix != 0
    BOARD_SIZE = parse(Int, ARGS[ix + 1])
  end

  ix = findfirst(x->x=="-twr_ht", ARGS)
  if ix != 0
    TOWER_HEIGHT = parse(Int, ARGS[ix + 1])
  end

  ix = findfirst(x->x=="-num_games", ARGS)
  if ix != 0
    NUM_GAMES = parse(Int, ARGS[ix + 1])
  end

  ix = findfirst(x->x=="-mem_sz", ARGS)
  if ix != 0
    MEM_SIZE = parse(Int, ARGS[ix + 1])
  end

  ix = findfirst(x->x=="-batch_sz", ARGS)
  if ix != 0
    BATCH_SIZE = parse(Int, ARGS[ix + 1])
  end

  ix = findfirst(x->x=="-eval_frq", ARGS)
  if ix != 0
    EVAL_FREQ = parse(Int, ARGS[ix + 1])
  end

  ix = findfirst(x->x=="-ro", ARGS)
  if ix != 0
    READOUTS = parse(Int, ARGS[ix + 1])
  end

  ix = findfirst(x->x=="-eval_games", ARGS)
  if ix != 0
    EVAL_GAMES = parse(Int, ARGS[ix + 1])
  end
end

parse_args()

set_all_params(BOARD_SIZE)

cur_nn = NeuralNet(; tower_height = TOWER_HEIGHT)
prev_nn = deepcopy(cur_nn)

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
  player = selfplay(cur_nn, READOUTS)
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

  print("Episode $i over. Loss: $loss ")
  if i % EVAL_FREQ == 0
    cur_is_winner = evaluate(cur_nn, prev_nn; num_games = EVAL_GAMES, ro = READOUTS)
    print(" Evaluated.")
    if cur_is_winner
      prev_nn = deepcopy(cur_nn)
      @save "agz_$(i)_base.bson" cur_nn.base_net
      @save "agz_$(i)_value.bson" cur_nn.value
      @save "agz_$(i)_policy.bson" cur_nn.policy
      print(" Model updated")
    else
      cur_nn = deepcopy(prev_nn)
      print(" Model retained")
    end
  end
  println()
end
