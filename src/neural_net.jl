import Flux.testmode!
import Base: show, deepcopy
using Flux: @treelike
include("resnet.jl")


struct NeuralNet
  base_net::Chain
  value::Chain
  policy::Chain
end

function NeuralNet(env::T; tower_height::Int = 19) where T <: GameEnv
  N, num_planes = env.N, env.planes

  res_block() = ResidualBlock([256,256,256], [3,3], [1,1], [1,1])
  # 19 residual blocks
  tower = [res_block() for i = 1:tower_height]
  base_net = Chain(Conv((3,3), 2num_planes+1=>256, pad=(1,1)),
                   BatchNorm(256, relu),
                   tower...) |> gpu

  value = Chain(Conv((1,1), 256=>1),
	        BatchNorm(1, relu), x->reshape(x, N^2, :),
                Dense(N^2, 256, relu), 
	        Dense(256, 1, tanh)) |> gpu

  policy = Chain(Conv((1,1), 256=>2), 
                 BatchNorm(2, relu), x->reshape(x, 2N^2, size(x, 4)),
                 Dense(2N^2, env.action_space), softmax) |> gpu

  NeuralNet(base_net, value, policy)
end

function Base.show(io::IO, nn::NeuralNet)
  println("Base: ", nn.base_net)
  println("Policy: ", nn.policy)
  println("Value: ", nn.value)
end

#=
function deepcopy(nn::NeuralNet)
  base_net = deepcopy(nn.base_net)
  value = deepcopy(nn.value)
  policy = deepcopy(nn.policy)

  return NeuralNet(;base_net = base_net, value = value, policy = policy)
end
=#

function testmode!(nn::NeuralNet, val::Bool=true)
  testmode!(nn.base_net, val)
  testmode!(nn.policy, val)
  testmode!(nn.value, val)
end

function (nn::NeuralNet)(input::Vector{T}, train::Bool = false) where T <: Position
  nn_in = cat(dims=4, get_feats.(input)...) |> gpu
  
  !train && testmode!(nn)
  
  common_out = nn.base_net(nn_in)
  π, val = nn.policy(common_out), nn.value(common_out)
  
  !train && testmode!(nn, false)
  
  return π, val
end

function (nn::NeuralNet)(input::Position)
  p, v = nn([input])
  return p[:, 1], v[1]
end

loss_π(π, p) = crossentropy(p, π; weight = 0.01f0)

loss_value(z, v) = 0.01f0 * mse(z, v)


function loss_reg(nn::NeuralNet)
  sum_sqr(x) = sum([sum(i.^2) for i in x])
  0.0001f0 * sum_sqr(params(nn))
end

function _train(nn::NeuralNet, input_data::T, opt; epochs = 1) where T<:NamedTuple{(:positions, :policy, :values), Tuple{Vector{Position}, Matrix{Float32}, Vector{Int}}}
  positions = input_data.positions
  π = input_data.policy |> gpu
  z = input_data.values |> gpu
  
  data_size = length(positions)

  for i = 1:epochs, j = 1:32:data_size
    p, v = nn(positions[j:j+31], true)
    loss = loss_π(π[:, j:j+31], p) + loss_value(z[j:j+31], v) + loss_reg(nn)
    back!(loss)
    loss_avg += loss.data
    update!(opt, params(nn))
  end

  return loss_avg / epochs
end

function evaluate(env::GameEnv, black_net::NeuralNet, white_net::NeuralNet; 
		  num_games = 400, ro = 800, verbose::Bool=false)
  games_won = 0

  testmode!(black_net)
  testmode!(white_net)

  black = MCTSPlayer(env, black_net, num_readouts = ro, two_player_mode = true)
  white = MCTSPlayer(env, white_net, num_readouts = ro, two_player_mode = true)

  for i = 1:num_games
    num_move = 0  # The move number of the current game

    initialize_game!(black)
    initialize_game!(white)

    while true
      active = num_move % 2 == true ? white : black
      inactive = num_move % 2 == true ? black : white

      current_readouts = N(active.root)
      readouts = active.num_readouts

      while N(active.root) < current_readouts + readouts
        tree_search!(active)
      end

      # First, check the roots for hopeless games.
      if should_resign(active)  # Force resign
        set_result!(active, -active.root.position.to_play, true)
        set_result!(inactive, -active.root.position.to_play, true)
	break
      end

      move = pick_move(active)
      play_move!(active, move)
      play_move!(inactive, move)
      num_move += 1

      if is_done(active)
        winner = result(active.root.position)
        set_result!(active,winner,false)
	set_result!(inactive, winner, false)
	break
      end
    end
    games_won += result(black.root.position) == BLACK
  end

  testmode!(black_net, false)
  testmode!(white_net, false)
  
  verbose && print("Won $games_won / $num_games. Win rate: $(games_won/num_games). ")
  
  return games_won / num_games ≥ 0.55
end
