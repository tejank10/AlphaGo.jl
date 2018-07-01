#=
This is Julia implementation of MCTS by Tejan Karmali.
Reference: Python version of the implementation of MCTS by
(https://github.com/tensorflow/minigo)
=#

using DataStructures: DefaultDict
using Distributions: Dirichlet

# Exploration constant balancing priors vs. value net output
c_puct = 0.96
# How much to weight the priors vs. dirichlet noise when mixing
dirichlet_noise_weight = 0.25

function set_mcts_params()
  global max_game_length, dirichlet_noise_alpha
  # 505 moves for 19x19, 113 for 9x9
  # Move number at which game is forcibly terminated
  max_game_length = (go.N ^ 2 * 7) ÷ 5

  # Concentrated-ness of the noise being injected into priors
  dirichlet_noise_alpha = 0.03 * 361 / (go.N ^ 2)
end

mutable struct DummyNode
  #= A fake node of a MCTS search tree.

  This node is intended to be a placeholder for the root node, which would
  otherwise have no parent node. If all nodes have parents, code becomes
  simpler. =#
  parent::Void
  child_N::DefaultDict{Any, Float32, Float32}
  child_W::DefaultDict{Any, Float32, Float32}
  function DummyNode()
    new(nothing, DefaultDict{Any, Float32}(0.0f0), DefaultDict{Any, Float32}(0.0f0))
  end
end

mutable struct MCTSNode
  #= A node of a MCTS search tree.

  A node knows how to compute the action scores of all of its children,
  so that a decision can be made about which move to explore next. Upon
  selecting a move, the children dictionary is updated with a new node.

  position: A go.Position instance
  fmove: A move (coordinate) that led to this position, a flattened coord
          (raw number ∈ [1-N^2], with nothing a pass)
  parent: A parent MCTSNode.
  =#

  parent
  fmove
  position::go.Position
  is_expanded::Bool
  losses_applied::Int
  child_N::Array{Float32, 1}
  child_W::Array{Float32, 1}
  original_prior::Array{Float32, 1}
  child_prior::Array{Float32, 1}
  children::Dict

  function MCTSNode(position::go.Position, fmove = nothing, parent = nothing)
    if parent == nothing
      parent = DummyNode()
    end
    is_expanded = false
    losses_applied = 0  # number of virtual losses on this node
    child_N = zeros(Float32, go.N * go.N + 1)
    child_W = zeros(Float32, go.N * go.N + 1)
    # save a copy of the original prior before it gets mutated by d-noise.
    original_prior = zeros(Float32, go.N * go.N + 1)
    child_prior = zeros(Float32, go.N * go.N + 1)
    children = Dict()  # map of flattened moves to resulting MCTSNode
    new(parent, fmove, position, is_expanded, losses_applied,
    child_N, child_W, original_prior, child_prior, children)
  end
end

legal_moves(x::MCTSNode) = go.all_legal_moves(x.position)

child_action_score(x::MCTSNode) = child_Q(x) * x.position.to_play .+
                                            child_U(x) - 1000 * (1 - legal_moves(x))

child_Q(x::MCTSNode) = x.child_W ./ (1 + x.child_N)

child_U(x::MCTSNode) = (c_puct * √(1 + N(x)) *
                x.child_prior ./ (1 + x.child_N))

Q(x::MCTSNode) = W(x) / (1 + N(x))

get_N(x::MCTSNode) = x.parent.child_N[x.fmove]
set_N!(x::MCTSNode, value) = x.parent.child_N[x.fmove] = value
N(x::MCTSNode) = get_N(x)

get_W(x::MCTSNode) = x.parent.child_W[x.fmove]
set_W!(x::MCTSNode, value) = x.parent.child_W[x.fmove] = value
W(x::MCTSNode) = get_W(x)

# Return value of position, from perspective of player to play
Q_perspective(x::MCTSNode) = Q(x) * x.position.to_play

function select_leaf(mcts_node::MCTSNode)
  current = mcts_node
  pass_move = go.N * go.N + 1
  while true
		current_new_N = N(current) + 1
    set_N!(current, current_new_N)
    # if a node has never been evaluated, we have no basis to select a child.
    if !current.is_expanded
      break
		end
    # HACK: if last move was a pass, always investigate double-pass first
    # to avoid situations where we auto-lose by passing too early.
    if (length(current.position.recent) != 0
      && current.position.recent[end].move == nothing
      && current.child_N[pass_move] == 0)
      current = maybe_add_child!(current, pass_move)
      continue
		end
    cas = child_action_score(current)
    #max_score = maximum(cas)
    #possible_moves = find(x -> x == max_score, cas)
    #best_move = sample(possible_moves)
    best_move = findmax(cas)[2]
    current = maybe_add_child!(current, best_move)
	end
  return current
end

function maybe_add_child!(mcts_node::MCTSNode, fcoord)
  # Adds child node for fcoord if it doesn't already exist, and returns it
  if fcoord ∉ keys(mcts_node.children)
    new_position = go.play_move!(mcts_node.position, go.from_flat(fcoord))
    mcts_node.children[fcoord] = MCTSNode(new_position, fcoord, mcts_node)
	end
  return mcts_node.children[fcoord]
end

function add_virtual_loss!(mcts_node::MCTSNode, up_to::MCTSNode)
  #= Propagate a virtual loss up to the root node.

    	Args:
        up_to: The node to propagate until. (Keep track of this! You'll
            need it to reverse the virtual loss later.)
  =#
  mcts_node.losses_applied += 1
  # This is a "win" for the current node; hence a loss for its parent node
  # who will be deciding whether to investigate this node again.
  loss = mcts_node.position.to_play
  set_W!(mcts_node, W(mcts_node) + loss)
  if (mcts_node.parent == nothing || mcts_node == up_to) return  end
	add_virtual_loss!(mcts_node.parent, up_to)
end

function revert_virtual_loss!(mcts_node::MCTSNode, up_to::MCTSNode)
  mcts_node.losses_applied -= 1
  revert = -mcts_node.position.to_play
	set_W!(mcts_node, W(mcts_node) + revert)
  if (mcts_node.parent == nothing || mcts_node == up_to) return end
  revert_virtual_loss!(mcts_node.parent, up_to)
end

function revert_visits!(mcts_node::MCTSNode, up_to::MCTSNode)
  #= Revert visit increments.

    Sometimes, repeated calls to select_leaf return the same node.
    This is rare and we're okay with the wasted computation to evaluate
    the position multiple times by the dual_net. But select_leaf has the
    side effect of incrementing visit counts. Since we want the value to
    only count once for the repeatedly selected node, we also have to
    revert the incremented visit counts.
  =#
  set_N!(mcts_node, N(mcts_node) - 1)
  if mcts_node.parent == nothing || mcts_node == up_to return end
  revert_visits!(mcts_node.parent, up_to)
end

function incorporate_results!(mcts_node::MCTSNode, move_probs, value, up_to)
  @assert size(move_probs) == (go.N * go.N + 1,)
  # A finished game should not be going through this code path - should
  # directly call backup_value() on the result of the game.
	@assert !mcts_node.position.done
  if mcts_node.is_expanded
    revert_visits!(mcts_node, up_to)
    return
	end
  mcts_node.is_expanded = true
  mcts_node.original_prior .= mcts_node.child_prior .= move_probs
  # initialize child Q as current node's value, to prevent dynamics where
  # if B is winning, then B will only ever explore 1 move, because the Q
  # estimation will be so much larger than the 0 of the other moves.
  #
  # Conversely, if W is winning, then B will explore all go.N² + 1 moves before
  # continuing to explore the most favorable move. This is a waste of search.
  #
  # The value seeded here acts as a prior, and gets averaged into Q calculations
  mcts_node.child_W .= ones(Float32, go.N * go.N + 1) * value
  backup_value!(mcts_node, value, up_to)
end

function backup_value!(mcts_node::MCTSNode, value, up_to::MCTSNode)
  #= Propagates a value estimation up to the root node.

  Args:
    value: the value to be propagated (1 = black wins, -1 = white wins)
    up_to: the node to propagate until.
	=#
  set_W!(mcts_node, W(mcts_node) + value)
  if mcts_node.parent == nothing || mcts_node == up_to return end
  backup_value!(mcts_node.parent, value, up_to)
end

#= true if the last two moves were Pass or if the position is at a move
  	greater than the max depth.
=#
is_done(mcts_node::MCTSNode) = mcts_node.position.done ||
	 																		mcts_node.position.n >= max_game_length

function inject_noise!(mcts_node::MCTSNode)
  dirch = rand(Dirichlet(dirichlet_noise_alpha * ones(go.N * go.N + 1)))
  mcts_node.child_prior .= mcts_node.child_prior * (1 - dirichlet_noise_weight) .+
                      dirch .* dirichlet_noise_weight
end

function children_as_π(mcts_node::MCTSNode, squash::Bool = false)
  #= Returns the child visit counts as a probability distribution, π
  If squash is true, exponentiate the probabilities by a temperature
  slightly larger than unity to encourage diversity in early play and
  hopefully to move away from 3-3s
  =#
  probs = mcts_node.child_N
  if squash
    probs = probs .^ 0.98
  end
  return probs ./ sum(probs)
end

function most_visited_path_nodes(mcts_node::MCTSNode)
  node = mcts_node
  output = Array{MCTSNode, 1}()
  while node.children
    next_kid = findmax(node.child_N)[2]
    node = get(node.children, next_kid, nothing)
    if node == nothing break end
    push!(output, node)
  end
  return output
end

function most_visited_path(mcts_node::MCTSNode)
  node = mcts_node
  output = Array{String, 1}()
  while !isempty(node.children)
    next_kid = findmax(node.child_N)[2]
    node = get(node.children, next_kid, nothing)
    if node == nothing
      push!(output, "GAME END")
      break
    end
    push!(output, go.to_kgs(go.from_flat(node.fmove)) * " ($(N(node))) ==> ")
  end
  push!(output, @sprintf("Q: %.5f\n", Q(node)))
  return join(output)
end

function mvp_gg(mcts_node::MCTSNode)
  # Returns most visited path in go-gui VAR format e.g. 'b r3 w c17...
  node = mcts_node
  output = Array{String, 1}()
  while !isempty(node.children) && maximum(node.child_N) > 1
    next_kid = findmax(node.child_N)[2]
    node = node.children[next_kid]
    push!(output, go.to_kgs(go.from_flat(node.fmove)))
  end
  return join(output, " ")
end

function describe(mcts_node::MCTSNode)
  sort_order = collect(1:go.N * go.N + 1)
  sort!(sort_order, by = i -> (
      mcts_node.child_N[i], child_action_score(mcts_node)[i]), rev = true)
  soft_n = mcts_node.child_N / max(1, sum(mcts_node.child_N))
  prior = mcts_node.child_prior
  p_delta = soft_n - prior
  p_rel = zeros(p_delta)
  mask = prior .!= 0
  p_rel[mask] .= p_delta[mask] ./ prior[mask]

  # Dump out some statistics
  output = Array{String, 1}()
  push!(output, @sprintf("%.4f\n", Q(mcts_node)))
  push!(output, most_visited_path(mcts_node))
  push!(output,
      "move : action    Q     U     P   P-Dir    N  soft-N  p-delta  p-rel")
  for key in sort_order[1:15]
    if mcts_node.child_N[key] == 0 break end
    push!(output, @sprintf("\n%s   : % .3f % .3f %.3f %.3f %.3f %5d %.4f % .5f % .2f",
        go.to_kgs(go.from_flat(key)),
        child_action_score(mcts_node)[key],
        child_Q(mcts_node)[key],
        child_U(mcts_node)[key],
        mcts_node.child_prior[key],
        mcts_node.original_prior[key],
        trunc(Int, mcts_node.child_N[key]),
        soft_n[key],
        p_delta[key],
        p_rel[key]))
  end
  return join(output)
end
