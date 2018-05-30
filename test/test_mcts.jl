include("../src/go.jl")
include("../src/mcts.jl")
include("test_utils.jl")
using Base.Test: @test, @test_throws

go.set_board_size(9);
set_mcts_params()
ALMOST_DONE_BOARD = load_board("""
                              .XO.XO.OO
                              X.XXOOOO.
                              XXXXXOOOO
                              XXXXXOOOO
                              .XXXXOOO.
                              XXXXXOOOO
                              .XXXXOOO.
                              XXXXXOOOO
                              XXXXOOOOO
                              """)

TEST_POSITION = go.Position(
    board = ALMOST_DONE_BOARD,
    n = 105,
    komi = 2.5,
    caps = (1, 4),
    ko = nothing,
    recent = [go.PlayerMove(go.BLACK, (1, 2)),
            go.PlayerMove(go.WHITE, (1, 9))],
    to_play = go.BLACK);

SEND_TWO_RETURN_ONE = go.Position(
    board = ALMOST_DONE_BOARD,
    n = 75,
    komi =  0.5,
    caps = (0, 0),
    ko = nothing,
    recent = [go.PlayerMove(go.BLACK, (1, 2)),
            go.PlayerMove(go.WHITE, (1, 9)),
            go.PlayerMove(go.BLACK, (2, 1))],
    to_play = go.WHITE);

function test_action_flipping()
  srand(1)
  probs = 0.02 * ones(go.N * go.N + 1)
  probs = probs + rand(go.N * go.N + 1) * 0.001
  black_root = MCTSNode(go.Position())
  white_root = MCTSNode(go.Position(to_play = go.WHITE))
  incorporate_results!(select_leaf(black_root), probs, 0, black_root)
  incorporate_results!(select_leaf(white_root), probs, 0, white_root)
  # No matter who is to play, when we know nothing else, the priors
  # should be respected, and the same move should be picked
  black_leaf = select_leaf(black_root)
  white_leaf = select_leaf(white_root)
  @test black_leaf.fmove == white_leaf.fmove
  @test assertEqualArray(child_action_score(black_root), child_action_score(white_root))
end

function test_select_leaf()
  flattened = go.to_flat(go.from_kgs("D9"))
  probs = 0.02 * ones(go.N * go.N + 1)
  probs[flattened] = 0.4
  root = MCTSNode(SEND_TWO_RETURN_ONE)
  incorporate_results!(select_leaf(root), probs, 0, root)

  @test root.position.to_play == go.WHITE
  @test select_leaf(root) == root.children[flattened]
end

function test_backup_incorporate_results()
  probs = 0.02 * ones(go.N * go.N + 1)
  root = MCTSNode(SEND_TWO_RETURN_ONE)
  incorporate_results!(select_leaf(root), probs, 0, root)

  leaf = select_leaf(root)
  incorporate_results!(leaf, probs, -1, root)  # white wins!

  # Root was visited twice: first at the root, then at this child.
  @test N(root) == 2
  # Root has 0 as a prior and two visits with value 0, -1
  @test Q(root) ≈ -1/3  # average of 0, 0, -1
  # Leaf should have one visit
  @test root.child_N[leaf.fmove] == 1
  @test N(leaf) == 1
  # And that leaf's value had its parent's Q (0) as a prior, so the Q
  # should now be the average of 0, -1
  @test child_Q(root)[leaf.fmove] == -0.5
  @test Q(leaf) ≈ -0.5

  # We're assuming that select_leaf() returns a leaf like:
  #   root
  #     \
  #     leaf
  #       \
  #       leaf2
  # which happens in this test because root is W to play and leaf was a W win.
  @test root.position.to_play == go.WHITE
  leaf2 = select_leaf(root)
  incorporate_results!(leaf2, probs, -0.2, root)  # another white semi-win
  @test N(root) == 3
  # average of 0, 0, -1, -0.2
  @test Q(root) ≈ -0.3

  @test N(leaf) == 2
  @test N(leaf2) == 1
  # average of 0, -1, -0.2
  @test Q(leaf) ≈ child_Q(root)[leaf.fmove]
  @test Q(leaf) ≈ -0.4
  # average of -1, -0.2
  @test child_Q(leaf)[leaf2.fmove] ≈ -0.6
  @test Q(leaf2) ≈ -0.6
end

function test_do_not_explore_past_finish()
  probs = 0.02 * ones(Float32, go.N * go.N + 1)
  root = MCTSNode(go.Position())
  incorporate_results!(select_leaf(root), probs, 0, root)
  first_pass = maybe_add_child!(root, go.to_flat(nothing))
  incorporate_results!(first_pass, probs, 0, root)
  second_pass = maybe_add_child!(first_pass, go.to_flat(nothing))
  @test_throws AssertionError incorporate_results!(second_pass, probs, 0, root)
  node_to_explore = select_leaf(second_pass)
  # should just stop exploring at the end position.
  @test node_to_explore == second_pass
end

function test_add_child()
  root = MCTSNode(go.Position())
  child = maybe_add_child!(root, 17)
  @test 17 ∈ keys(root.children)
  @test child.parent == root
  @test child.fmove == 17
end

function test_add_child_idempotency()
  root = MCTSNode(go.Position())
  child = maybe_add_child!(root, 17)
  current_children = copy(root.children)
  child2 = maybe_add_child!(root, 17)
  @test child == child2
  @test current_children == root.children
end

function test_never_select_illegal_moves()
  probs = 0.02 * ones(go.N * go.N + 1)
  # let's say the NN were to accidentally put a high weight on an illegal move
  probs[2] = 0.99
  root = MCTSNode(SEND_TWO_RETURN_ONE)
  incorporate_results!(root, probs, 0, root)
  # and let's say the root were visited a lot of times, which pumps up the
  # action score for unvisited moves...
  set_N!(root, 10000)
  root.child_N[Bool.(go.all_legal_moves(root.position))] = 10000
  # this should not throw an error...
  leaf = select_leaf(root)
  # the returned leaf should not be the illegal move
  @test leaf.fmove != 2

  # and even after injecting noise, we should still not select an illegal move
  for i = 1:10
    inject_noise!(root)
    leaf = select_leaf(root)
    @test leaf.fmove != 2
  end
end

function test_dont_pick_unexpanded_child()
  probs = 0.02 * ones(go.N * go.N + 1)
  # make one move really likely so that tree search goes down that path twice
  # even with a virtual loss
  probs[18] = 0.999
  root = MCTSNode(go.Position())
  incorporate_results!(root, probs, 0, root)
  leaf1 = select_leaf(root)
  @test leaf1.fmove == 18
  add_virtual_loss!(leaf1, root)
  # the second select_leaf pick should return the same thing, since the child
  # hasn't yet been sent to neural net for eval + result incorporation
  leaf2 = select_leaf(root)
  @test leaf1 == leaf2
end
