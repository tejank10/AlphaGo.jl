using StatsBase: sample

mutable struct MCTSPlayer
  network
  num_readouts::Integer
  two_player_mode::Bool
  τ_threshold::Integer
  qs::Vector{Float32}
  searches_π::Vector{Vector{Float32}}
  result::Integer
  result_string::String
  root
  resign_threshold::Float32
end

function MCTSPlayer(env::AbstractEnv, network; num_readouts::Int = 800,
                    two_player_mode::Bool = false, resign_threshold = -0.9f0)
  N = env.board_data.N
  τ_threshold = two_player_mode ? -1 : (N ^ 2 ÷ 12) ÷ 2 * 2
  MCTSPlayer(network, num_readouts, two_player_mode, τ_threshold,
      Vector{Float32}(), Vector{Vector{Float32}}(), 0, "",
      nothing, resign_threshold)
end

function play_move!(mcts_player::MCTSPlayer, c)
  #=
  Notable side effects:
    - finalizes the probability distribution according to
    this roots visit counts into the class' running tally, `searches_π`
    - Makes the node associated with this move the root, for future
      `inject_noise` calls.
  =#
  if !mcts_player.two_player_mode
    pos = get_position(mcts_player)
    squash = num_moves(pos) ≤ mcts_player.τ_threshold
    push!(mcts_player.searches_π, children_as_π(mcts_player.root, squash))
  end

  push!(mcts_player.qs, Q(mcts_player.root))  # Save our resulting Q.

  try
    mcts_player.root = maybe_add_child!(mcts_player.root,
                                        to_flat(c, board_size(pos)))
  catch IllegalMove
    println("Illegal move")
    mcts_player.two_player_mode || pop!(mcts_player.searches_π)
    pop!(mcts_player.qs)
    return false
  end

  mcts_player.root.parent.children = Dict()

  return true
end

function pick_move(mcts_player::MCTSPlayer)
  #= Picks a move to play, based on MCTS readout statistics.

  Highest N is most robust indicator. In the early stage of the game, pick
  a move weighted by visit count; later on, pick the absolute max. =#

  if num_moves(get_position(mcts_player)) ≥ mcts_player.τ_threshold
    max_val = maximum(mcts_player.root.child_N)
    possible_moves = findall(x -> x == max_val, mcts_player.root.child_N)
    fcoord = sample(possible_moves)
    #fcoord = findmax(mcts_player.root.child_N)[2]
  else
    cdf = cumsum(mcts_player.root.child_N)
    cdf /= cdf[end - 1]  # Prevents passing via softpick.
    selection = rand()
    fcoord = searchsortedfirst(cdf, selection)
    @assert mcts_player.root.child_N[fcoord] != 0
  end

  return from_flat(fcoord, board_size(get_position(mcts_player)))
end

function tree_search!(mcts_player::MCTSPlayer, parallel_readouts::Int = 8)
  leaves = Vector{MCTSNode}()
  failsafe = 0

  while length(leaves) < parallel_readouts && failsafe < 2parallel_readouts
    failsafe += 1
    leaf = select_leaf(mcts_player.root)

    # if game is over, override the value estimate with the true score
    if is_done(leaf)
      value = result(leaf.position)
      backup_value!(leaf, value, mcts_player.root)
      continue
    end

    add_virtual_loss!(leaf, mcts_player.root)
    push!(leaves, leaf)
  end

  if !isempty(leaves)
    #TODO: network API
    move_probs, values = mcts_player.network([leaf.position for leaf in leaves])
    move_probs, values = move_probs.data, values.data
    move_probs = [move_probs[:, i] for i = 1:size(move_probs, 2)]
    for (leaf, move_prob, value) in zip(leaves, move_probs, values)
      revert_virtual_loss!(leaf, mcts_player.root)
      incorporate_results!(leaf, move_prob, value, mcts_player.root)
    end
  end

  return leaves
end

function set_result!(mcts_player::MCTSPlayer, winner, was_resign)
  mcts_player.result = winner
  str = result_string(get_position(mcts_player);
                      winner = winner, was_resign = was_resign)
  mcts_player.result_string = str
end

function initialize_game!(mcts_player::MCTSPlayer, env::AbstractEnv)
  pos = init_position(env)
  initialize_game!(mcts_player, pos)
end

function initialize_game!(mcts_player::MCTSPlayer, pos = nothing)
  @assert !(pos === get_position(mcts_player) === nothing)

  pos === nothing && (pos = init_position(get_position(mcts_player)))

  mcts_player.root = MCTSNode(pos)
  mcts_player.result = 0
  mcts_player.searches_π = Vector{Vector{Float32}}()
  mcts_player.qs = Vector{Float32}()
end

is_done(mcts_player::MCTSPlayer) = mcts_player.result != 0 || is_done(mcts_player.root)

# Returns true if the player resigned.  No further moves should be played

should_resign(mcts_player::MCTSPlayer) = Q_perspective(mcts_player.root) <
                                         mcts_player.resign_threshold

get_position(mcts_player::MCTSPlayer) = mcts_player.root === nothing ? nothing :
                                            get_position(mcts_player.root)

function extract_data(mcts_player::MCTSPlayer)
  @assert length(mcts_player.searches_π) == num_moves(get_position(mcts_player))
  #@assert mcts_player.result != 0
  positions = Vector{Position}()
  πs = deepcopy.(mcts_player.searches_π)
  results = Vector{Int}()

  pwcs = replay_position(get_position(mcts_player), mcts_player.result)

  for pwc in pwcs
    push!(positions, pwc.position)
    push!(results, pwc.result)
  end

  return positions, πs, results
end

function suggest_move(mcts_player::MCTSPlayer)
  current_readouts = N(mcts_player.root)

  while N(mcts_player.root) < current_readouts + mcts_player.num_readouts
    tree_search!(mcts_player)
  end

  pick_move(mcts_player)
end
