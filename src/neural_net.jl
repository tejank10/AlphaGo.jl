import Flux.testmode!
import Base.deepcopy

include("resnet.jl")
#TODO: gpu
mutable struct NeuralNet
  base_net::Chain
  value::Chain
  policy::Chain
  opt
  function NeuralNet(;base_net = nothing, value = nothing, policy = nothing,
                          tower_height::Int = 19)
    if base_net == nothing
      res_block = ResidualBlock([256,256,256], [3,3], [1,1], [1,1])
      # 19 residual blocks
      tower = tuple(repmat([res_block], tower_height)...)
      base_net = Chain(Conv((3,3), 17=>256, pad=(1,1)), BatchNorm(256, relu),
                        tower...) |> gpu
    end
    if value == nothing
      value = Chain(Conv((1,1), 256=>1), BatchNorm(1, relu), x->reshape(x, :, size(x, 4)),
                    Dense(go.N*go.N, 256, relu), Dense(256, 1, tanh)) |> gpu
    end
    if policy == nothing
      policy = Chain(Conv((1,1), 256=>2), BatchNorm(2, relu), x->reshape(x, :, size(x, 4)),
                      Dense(2go.N*go.N, go.N*go.N+1)) |> gpu
    end

    all_params = vcat(params(base_net), params(value), params(policy))
    opt = ADAM(all_params)
    new(base_net, value, policy, opt)
  end
end

function deepcopy(nn::NeuralNet)
  base_net = deepcopy(nn.base_net)
  value = deepcopy(nn.value)
  policy = deepcopy(nn.policy)
  return NeuralNet(; base_net = base_net, value = value, policy = policy)
end

function testmode!(nn::NeuralNet, val::Bool=true)
  testmode!(nn.base_net, val)
  testmode!(nn.policy, val)
  testmode!(nn.value, val)
end

function (nn::NeuralNet)(input::Vector{go.Position})
  nn_in = cat(4, get_feats.(input)...) |> gpu
  testmode!(nn)

  common_out = nn.base_net(nn_in)
  π, val = nn.policy(common_out), nn.value(common_out)
  testmode!(nn, false)

  return π, val
end

function (nn::NeuralNet)(input::go.Position)
  p, v = nn([input])
  return p[:, 1], v[1]
end

loss_π(π, p) = 0.01f0 * crossentropy(softmax(π), p)

loss_value(z, v) = 0.01f0 * mse(z, v)

loss_reg(nn::NeuralNet) = 0.0001f0 * (sum(vecnorm, params(nn.base_net)) +
                           sum(vecnorm, params(nn.value)) +
                           sum(vecnorm, params(nn.policy)))

function train!(nn::NeuralNet, input_data::Tuple{Vector{go.Position}, Matrix{Float32}, Vector{Int}})
  positions, π, z = input_data
  p, v = nn(positions)
  loss = loss_π(π, p) + loss_value(z, v) + loss_reg(nn)
  back!(loss)
  nn.opt()
  return loss.tracker.data
end

function evaluate(black_net::NeuralNet, white_net::NeuralNet; num_games = 400)
  games_won = 0

  testmode!(black_net)
  testmode!(white_net)

  black = MCTSPlayer(black_net, two_player_mode = true)
  white = MCTSPlayer(white_net, two_player_mode = true)

  for i = 1:num_games
    num_move = 0  # The move number of the current game

    initialize_game!(black)
    initialize_game!(white)

    while true
      active = num_move % 2 == true ? white : black
      inactive = num_move % 2 == true? black : white

      current_readouts = N(active.root)
      readouts = active.num_readouts

      while N(active.root) < current_readouts + readouts
        tree_search!(active)
      end

      # First, check the roots for hopeless games.
      if should_resign(active)  # Force resign
        set_result!(active, -active.root.position.to_play, true)
        set_result!(inactive, active.root.position.to_play, true)
      end
      if is_done(active) break end

      move = pick_move(active)
      play_move!(active, move)
      play_move!(inactive, move)
      num_move += 1
    end
    games_won += black.result_string[1] == "B"
  end

  testmode!(black_net, false)
  testmode!(white_net, false)

  return games_won / num_games ≥ 0.55
end
