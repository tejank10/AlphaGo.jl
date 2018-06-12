using AlphaGo
using HttpServer
using JSON
using BSON: @load

config = Dict()

function _deploy(f)
  handler= HttpHandler(f)
  server = Server(handler)
  run(server, 3000)
  server
end

function transform(req,res)
  if typeof(req.method) == GETDict
    return handleGET(req, res)
  else if typeof(req.method) == POSTDict
    return handlePOST(req, res)
  res
end

function __init__()
  # load neural network and configure env
  #  add nn and other env variables to config dict
  # ...
  _deploy(transform)
end

struct MCTSPlayer__
  # all the info without the common ones ( like nn )
  root
  qs::Vector{Float32}
  searches_π::Vector{Vector{Float32}}
  result::Int
  position
  # .....
end

function MCTSPlayer__(m::MCTSPlayer)
  MCTSPlayer__(m.root, m.qs, m.searches_π, m.result, m.position)
end

function handleGET(req, res)
  # create MCTSPlayer
  player = initialise_player()
  player__ = MCTSPlayer__(m)

  
  # Loading weights
  @load "../models/agz_512_base.bson" base_net
  @load "../models/agz_512_value.bson" value
  @load "../models/agz_512_policy.bson" policy

  # Making a player
  agz_net = NeuralNet(;base_net = base_net, value = value, policy = policy)
  agz = MCTSPlayer(agz_net, num_readouts = 64)

  initialize_game!(agz)

  res.data = JSON.json(Dict(mctsPlayer=>player__))
  return res
end


function makeMCTSPlayer(p::MCTSPlayer__)
  # make from p and config dict
end


function handlePOST(req, res)
  dict = JSON.parse(String(req.data))
  player__ = MCTSPlayer__(dict["mctsPlayer"])
  player = makeMCTSPlayer(player__)
  # add user action to env
  # .....

  # Selecting a move based on tree search. This part is required every time
  # computer has to make the move
  current_readouts = N(agz.root)
  readouts = agz.num_readouts

  while N(agz.root) < current_readouts + readouts
    tree_search!(agz)
  end

  # First, check the roots for hopeless games.
  if should_resign(agz)  # Force resign
    set_result!(agz, -agz.root.position.to_play, true)
  end
  if is_done(agz)
    set_result!(agz, 0, false)
    break
  end

  move = pick_move(agz)
  play_move!(agz, move)

  # get current env info and current player__ info
  # env = player.position?
  # player__ = MCTSPlayer__(player)

  data = Dict("env"=>env, "mctsPlayer"=>player__)
  res.data = JSON.json(data)
  return res
end

__init__()
