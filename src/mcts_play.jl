using StatsBase: sample

mutable struct MCTSPlayer
  env :: GameEnv
  network
  num_readouts::Int
  two_player_mode::Bool
  τ_threshold::Int
  qs::Vector{Float32}
  searches_π::Vector{Vector{Float32}}
  result::Int
  result_string
  root
  resign_threshold
  position

  function MCTSPlayer(env::T, network; num_readouts = 800, two_player_mode = false,
               resign_threshold = -0.9) where T <: GameEnv
    τ_threshold = two_player_mode ? -1 : (env.N * env.N ÷ 12) ÷ 2 * 2
    new(env, network, num_readouts, two_player_mode, τ_threshold,
        Array{Float32, 1}(), Array{Array{Float32, 1}, 1}(), 0, "",
        nothing, resign_threshold, nothing)
  end
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
    push!(mcts_player.searches_π, children_as_π(mcts_player.root,
    mcts_player.root.position.n ≤ mcts_player.τ_threshold))
  end
  push!(mcts_player.qs, Q(mcts_player.root))  # Save our resulting Q.
  try
    mcts_player.root = maybe_add_child!(mcts_player.root, to_flat(c, mcts_player.root.position))
  catch IllegalMove
    println("Illegal move")
    if !mcts_player.two_player_mode pop!(mcts_player.searches_π) end
    pop!(mcts_player.qs)
    return false
  end
  mcts_player.position = mcts_player.root.position  # for showboard
  mcts_player.root.parent.children = Dict()
  return true
end

function pick_move(mcts_player::MCTSPlayer)
  #= Picks a move to play, based on MCTS readout statistics.

  Highest N is most robust indicator. In the early stage of the game, pick
  a move weighted by visit count; later on, pick the absolute max. =#
  if mcts_player.root.position.n ≥ mcts_player.τ_threshold
    fcoord = findmax(mcts_player.root.child_N)[2]
  else
    cdf = cumsum(mcts_player.root.child_N)
    cdf /= cdf[end]  # Prevents passing via softpick if end - 1 is used
    selection = rand()
    fcoord = searchsortedfirst(cdf, selection)
    @assert mcts_player.root.child_N[fcoord] != 0
  end
  return from_flat(fcoord, mcts_player.root.position)
end

function tree_search!(mcts_player::MCTSPlayer, parallel_readouts = 8)
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
    move_probs, values = mcts_player.network([leaf.position for leaf in leaves])
    move_probs, values = move_probs.tracker.data, values.tracker.data
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
  if was_resign
    string = winner == BLACK ? "B+R" : "W+R"
  else
    string = result_string(mcts_player.root.position)
    mcts_player.result = string[1] == 'B' ? BLACK :
                                              (string[1] == 'W' ? WHITE : 0)
  end
  mcts_player.result_string = string
end

function initialize_game!(mcts_player::MCTSPlayer, pos = nothing)
  if pos == nothing
    pos = Position(mcts_player.env)
  end
  mcts_player.root = MCTSNode(pos)
  mcts_player.result = 0
  mcts_player.searches_π = Vector{Vector{Float32}}()
  mcts_player.qs = Vector{Float32}()
end

is_done(mcts_player::MCTSPlayer) = mcts_player.result != 0 || is_done(mcts_player.root)

# Returns true if the player resigned.  No further moves should be played

should_resign(mcts_player::MCTSPlayer) = Q_perspective(mcts_player.root) < mcts_player.resign_threshold

function extract_data(mcts_player::MCTSPlayer)
  @assert length(mcts_player.searches_π) == mcts_player.root.position.n
  @assert mcts_player.result != 0
  positions = Vector{Position}()
  πs = deepcopy(mcts_player.searches_π)
  results = Vector{Int}()

  pwcs = replay_position(mcts_player.root.position, mcts_player.result)
  for pwc in pwcs
    push!(positions, pwc.position)
    push!(results, pwc.result)
  end
  return positions, πs, results
end

get_position(mcts_player::MCTSPlayer) = mcts_player.root != nothing ?
                                            mcts_player.root.position : nothing

function suggest_move(mcts_player::MCTSPlayer)
  current_readouts = N(mcts_player.root)
  while N(mcts_player.root) < current_readouts + mcts_player.num_readouts
    tree_search!(mcts_player)
  end

  pick_move(mcts_player)
end
