mutable struct neural_net
  base_net::Chain
  value::Chain
  policy::Chain

  function neural_net(; base_net = nothing, value = nothing, policy = nothing,
                          tower_height::Int = 19)
    if base_net == nothing
      res_block = ResidualBlock([256,256,256], [3,3], [1,1], [1,1])
      # 19 residual blocks
      tower = tuple(repmat([res_block], tower_height)...)
      base_net = Chain(Conv((3,3), 17=>256, pad=(1,1)), BatchNorm(256, relu),
                        tower...)
    end
    if value == nothing
      value = Chain(Conv((1,1), 256=>1, pad=(1,1)), BatchNorm(1, relu), x->reshape(x, :, size(x, 4)),
                    Dense(go.N*go.N, 256, relu), Dense(256, 1, tanh))
    end
    if policy == nothing
      policy = Chain(Conv((1,1), 256=>2), BatchNorm(2, relu), x->reshape(x, :, size(x, 4)),
                      Dense(2go.N*go.N, go.N*go.N+1, softmax))
    end
    new(base_net, value, policy)
  end
end

function deepcopy(nn::neural_net)
  base_net = deepcopy(nn.base_net)
  value = deepcopy(nn.value)
  policy = deepcopy(nn.policy)
  return neural_net(base_net, value, policy)
end

function (nn::neural_net)(input::Array{go.Position, 1})
  nn_in = cat(4, get_feats.(input)...)
  common_out = nn.base_net(nn_in)
  π, val = nn.policy(common_out), nn.value(common_out)
end
