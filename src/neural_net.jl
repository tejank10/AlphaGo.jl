import Flux.testmode!
import Base: show, deepcopy
using Flux: @treelike
using Flux.Optimise: update!

struct NeuralNet
  base_net::Chain
  value::Chain
  policy::Chain
end

function NeuralNet(env::AbstractEnv; blocks = BLOCKS)
  N, num_planes = env.board_data.N, env.board_data.planes

  res_block() = ResidualBlock([256,256,256], [3,3], [1,1], [1,1])
  # BLOCKS residual blocks
  tower = [res_block() for i = 1:BLOCKS]
  action_space_size = length(env.board_data.action_space)

  base_net = Chain(Conv((3, 3), 2num_planes+1 => 256, pad=(1, 1)),
                   BatchNorm(256, relu),
                   tower...) |> gpu

  value    = Chain(Conv((1, 1), 256 => 1),
	               BatchNorm(1, relu), x->reshape(x, N^2, :),
                   Dense(N^2, 256, relu),
	        	   Dense(256, 1, tanh)) |> gpu

  policy   = Chain(Conv((1, 1), 256 => 2),
	               BatchNorm(2, relu), x->reshape(x, 2N^2, :),
	               Dense(2N^2, action_space_size), softmax) |> gpu

  NeuralNet(base_net, value, policy)
end

@treelike NeuralNet

function Base.show(io::IO, nn::NeuralNet)
  println("Base: ", nn.base_net)
  println("Policy: ", nn.policy)
  println("Value: ", nn.value)
end


function deepcopy(nn::NeuralNet)
  base_net = deepcopy(nn.base_net)
  value = deepcopy(nn.value)
  policy = deepcopy(nn.policy)

  return NeuralNet(base_net, value, policy)
end


function testmode!(nn::NeuralNet, val::Bool=true)
  testmode!(nn.base_net, val)
  testmode!(nn.policy, val)
  testmode!(nn.value, val)
end

function (nn::NeuralNet)(input::Vector{T}, train::Bool = false) where T <: Position
  nn_in = cat(dims=4, get_feats.(input)...) |> gpu

  !train && testmode!(nn)

  common_out = nn.base_net(nn_in)
  π, z = nn.policy(common_out), nn.value(common_out)

  !train && testmode!(nn, false)

  return π, z
end

function (nn::NeuralNet)(input::Position)
  π, z = nn([input])
  return π[:, 1], z[1]
end

loss_π(π, p) = crossentropy(p, π; weight = 1f-2)

loss_value(z, v) = 1f-2 * mse(z, v)

function loss_reg(nn::NeuralNet)
  sum_sqr(x) = sum([sum(i.^2) for i in x])
  L2_REG * sum_sqr(params(nn))
end

function train_epoch(nn::NeuralNet, positions, π, z, opt; epochs = 1)
  π = π |> gpu
  z = z |> gpu

  data_size = length(positions)
  loss_avg = 0f0

  for i = 1:epochs
    p, v = nn(positions, true)
    loss = loss_π(π, p) + loss_value(z, v) + loss_reg(nn)
    back!(loss)
    update!(opt, params(nn))
    loss_avg += loss.data
  end

  return loss_avg / epochs
end

function evaluate(env::AbstractEnv, black_net::NeuralNet, white_net::NeuralNet;
		              num_games::Integer = 400, ro::Integer = 800, verbose::Bool=false)
  games_won = 0

  testmode!(black_net)
  testmode!(white_net)

  black = MCTSPlayer(env, black_net, num_readouts = ro, two_player_mode = true)
  white = MCTSPlayer(env, white_net, num_readouts = ro, two_player_mode = true)

  for i = 1:num_games
    num_moves = 0  # The move number of the current game

    initialize_game!(black, env)
    initialize_game!(white, env)

    while true
      active   = num_moves % 2 == true ? white : black
      inactive = num_moves % 2 == true ? black : white

      current_readouts = N(active.root)
      readouts = active.num_readouts

      while N(active.root) < current_readouts + readouts
        tree_search!(active)
      end

      # First, check the roots for hopeless games.
      if should_resign(active)  # Force resign
        set_result!(active,   -active.root.position.to_play, true)
        set_result!(inactive, -active.root.position.to_play, true)
	      break
      end

      move = pick_move(active)
      play_move!(active, move)
      play_move!(inactive, move)
      num_moves += 1

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

  win_rate = games_won / num_games
  if verbose
    print("Won $games_won / $num_games. ")
    println("Win rate: $(@sprintf("%.2f", win_rate))")
  end

  return games_won / num_games ≥ EVAL_THRESHOLD
end
