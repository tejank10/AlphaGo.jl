mutable struct MCTSPlayer
  network::Chain
  num_readouts
  two_player_mode
  τ_threshold
  qs
  searches_π
  result
  root
  resign_threshold

  function MCTSPlayer(network, num_readouts = 0, two_player_mode = false,
               resign_threshold = nothing)
    num_readouts = num_readouts == nothing ? FLAGS.num_readouts : num_readouts
    τ_threshold = two_player_mode ? -1 : FLAGS.softpick_move_cutoff
    resign_threshold = resign_threshold == nothing ? FLAGS.resign_threshold :
                                                              resign_threshold
    new(network, num_readouts, two_player_mode, τ_threshold,
        [], [], 0, nothing, resign_threshold)
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
    push!(searches_π(mcts_player), mcts_player.root.children_as_π(
    mcts_player.root.position.n <= mcts_player.temp_threshold))
  end
  push!(mcts_player.qs, Q(mcts_player.root))  # Save our resulting Q.
  try
    mcts_player.root = maybe_add_child!(mcts_player.root, go.to_flat(c))
  catch go.IllegalMove:
    print("Illegal move")
    if ! mcts_player.two_player_mode pop!(mcts_player.searches_π) end
    pop!(mcts_player.qs)
    return false
  end
  mcts_player.position = mcts_player.root.position  # for showboard
  # del self.root.parent.children
  return true
end

function pick_move(mcts_player::MCTSPlayer)
  #= Picks a move to play, based on MCTS readout statistics.

  Highest N is most robust indicator. In the early stage of the game, pick
  a move weighted by visit count; later on, pick the absolute max.=#
  if mcts_player.root.position.n >= mcts_player.τ_threshold:
    fcoord = findmax(mcts_player.root.child_N)[2]
  else
    child_N_exp = mcts_player.root.child_N .^ (1 / τ)
    π = child_N_exp ./ sum(child_N_exp)
    fcoord = sample(1:length(π), Weights(π))
    @assert mcts_player.root.child_N[fcoord] != 0
  return coords.from_flat(fcoord)
end

function tree_search!(mcts_player::MCTSPlayer, parallel_readouts = nothing)
  if parallel_readouts == nothing
    parallel_readouts = FLAGS.parallel_readouts
  end
  leaves = Array{MCTSNode, 1}()
  failsafe = 0
  while length(leaves) < parallel_readouts && failsafe < 2parallel_readouts
    failsafe += 1
    leaf = select_leaf!(mcts_player.root)
    # if game is over, override the value estimate with the true score
    if is_done(leaf)
      value = score(leaf.position) > 0 ? 1 : -1
      backup_value!(leaf, value, mcts_player.root)
      continue
    end
    add_virtual_loss!(leaf, mcts_player.root)
    push!(leaves, leaf)
  end
  if !isempty(leaves)
    #TODO: network
    move_probs, values = network.run_many([leaf.position for leaf in leaves])
    for (leaf, move_prob, value) in zip(leaves, move_probs, values)
      revert_virtual_loss!(leaf, mcts_player.root)
      incorporate_results!(leaf, move_prob, value, mcts_player.root)
    end
  end
  return leaves
end
