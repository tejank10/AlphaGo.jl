include("../src/go.jl")
include("../src/mcts.jl")
include("../src/mcts_play.jl")
include("../src/features.jl")
include("test_utils.jl")
using Base.Test: @test, @test_throws

go.set_board_size(9);
set_mcts_params()

# Tromp taylor means black can win if we hit the move limit.
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

TT_FTW_BOARD = load_board("""
                          .XXOOOOOO
                          X.XOO...O
                          .XXOO...O
                          X.XOO...O
                          .XXOO..OO
                          X.XOOOOOO
                          .XXOOOOOO
                          X.XXXXXXX
                          XXXXXXXXX
                          """)

SEND_TWO_RETURN_ONE = go.Position(
    board = ALMOST_DONE_BOARD,
    n = 70,
    komi = 2.5,
    caps = (1, 4),
    ko = nothing,
    recent = [go.PlayerMove(go.BLACK, (1, 2)),
    go.PlayerMove(go.WHITE, (1, 9))],
    to_play = go.BLACK
    );

struct DummyNet
  fake_priors
  fake_value

  function  DummyNet(; fake_priors = nothing, fake_value = 0)
    if fake_priors == nothing
      fake_priors = ones(go.N ^ 2 + 1) / (go.N ^ 2 + 1)
    end
    new(fake_priors, fake_value)
  end
end

(dn::DummyNet)(position::go.Position) = dn.fake_priors, dn.fake_value

function (dn::DummyNet)(positions = nothing)
  if positions == nothing || length(positions) == 0
    throw(ArgumentError("No positions passed!"))
  end
  len = length(positions)
  return repeat(dn.fake_priors, outer = [1, len]), repmat([dn.fake_value], len)
end

function initialize_basic_player()
  player = MCTSPlayer(DummyNet())
  initialize_game!(player)
  first_node = select_leaf(player.root)
  incorporate_results!(first_node, player.network(player.root.position)..., player.root)
  return player
end

function initialize_almost_done_player()
  probs = ones(go.N * go.N + 1) * 0.001
  probs[3:5] = 0.2  # some legal moves along the top.
  probs[end] = 0.2  # passing is also ok
  net = DummyNet(probs)
  player = MCTSPlayer(net)
  # root position is white to play with no history == white passed.
  initialize_game!(player, SEND_TWO_RETURN_ONE)
  return player
end

function test_inject_noise()
  player = initialize_basic_player()
  sum_priors = sum(player.root.child_prior)
  # dummyNet should return normalized priors.
  @test sum_priors ≈ 1
  u = child_U(player.root)
  @test all(u .== u[1])

  inject_noise!(player.root)
  new_sum_priors = sum(player.root.child_prior)
  # priors should still be normalized after injecting noise
  @test sum_priors ≈ new_sum_priors

  # With dirichelet noise, majority of density should be in one node.
  max_p = maximum(player.root.child_prior)
  @test max_p > 3 / (go.N ^ 2 + 1)
end

function test_pick_moves()
  player = initialize_basic_player()
  root = player.root
  root.child_N[go.to_flat((3, 1))] = 10
  root.child_N[go.to_flat((2, 1))] = 5
  root.child_N[go.to_flat((4, 1))] = 1

  root.position.n = go.N ^ 2  # move 81, or 361, or... Endgame.

  # Assert we're picking deterministically
  @test root.position.n > player.τ_threshold
  move = pick_move(player)
  @test move == (3, 1)

  # But if we're in the early part of the game, pick randomly
  root.position.n = 3
  @test player.root.position.n ≤ player.τ_threshold

  #TODO: complete this test
  #with mock.patch('random.random', lambda: .5)
  move = pick_move(player)
  #@test move == (3, 1)

  #with mock.patch('random.random', lambda: .99):
  move = pick_move(player)
  #@test move == (4, 1)
end

function test_dont_pass_if_losing()
  player = initialize_almost_done_player()

  # check -- white is losing.
  @test go.score(player.root.position) == -0.5

  for i = 1:20
    tree_search!(player)
  end

  # uncomment to debug this test
  #println(describe(player.root))

  # Search should converge on D9 as only winning move.
  flattened = go.to_flat(go.from_kgs("D9"))
  best_move = findmax(player.root.child_N)[2]
  @test best_move == flattened
  # D9 should have a positive value
  @test Q(player.root.children[flattened]) > 0
  @test N(player.root) ≥ 20
  # passing should be ineffective.
  @test child_Q(player.root)[end] < 0
  # no virtual losses should be pending
  assertNoPendingVirtualLosses(player.root)
  # uncomment to debug this test
  #println(describe(player.root))
end

function test_parallel_tree_search()
  player = initialize_almost_done_player()
  # check -- white is losing.
  @test go.score(player.root.position) == -0.5
  # initialize the tree so that the root node has populated children.
  tree_search!(player, 1)
  # virtual losses should enable multiple searches to happen simultaneously
  # without throwing an error...
  for i = 1:5
    tree_search!(player, 4)
  end
  # uncomment to debug this test
  # print(player.root.describe())

  # Search should converge on D9 as only winning move.
  flattened = go.to_flat(go.from_kgs("D9"))
  best_moves = find(x -> x .== maximum(player.root.child_N), player.root.child_N)
  @test flattened ∈ best_moves
  # D9 should have a positive value
  @test Q(player.root.children[flattened]) > 0
  @test N(player.root) ≥ 20
  # passing should be ineffective.
  child_Q(player.root)[end] < 0
  # no virtual losses should be pending
  assertNoPendingVirtualLosses(player.root)
end

function test_ridiculously_parallel_tree_search()
  player = initialize_almost_done_player()
  # Test that an almost complete game
  # will tree search with # parallelism > # legal moves.
  for i = 1:10
    tree_search!(player, 50)
  end
  assertNoPendingVirtualLosses(player.root)
end

function test_long_game_tree_search()
  player = MCTSPlayer(DummyNet())
  endgame = go.Position(
      board = TT_FTW_BOARD,
      n = max_game_length - 2,
      komi = 2.5,
      ko = nothing,
      recent = [go.PlayerMove(go.BLACK, (1, 2)),
              go.PlayerMove(go.WHITE, (1, 9))],
      to_play = go.BLACK
  )
  initialize_game!(player, endgame)

  # Test that MCTS can deduce that B wins because of TT-scoring
  # triggered by move limit.
  for i = 1:10
    tree_search!(player, 8)
  end
  assertNoPendingVirtualLosses(player.root)
  @test Q(player.root) > 0
end

function test_cold_start_parallel_tree_search()
  # Test that parallel tree search doesn't trip on an empty tree
  player = MCTSPlayer(DummyNet(fake_value = 0.17))
  initialize_game!(player)
  @test N(player.root) == 0
  @test !player.root.is_expanded
  tree_search!(player, 4)
  assertNoPendingVirtualLosses(player.root)
  # Even though the root gets selected 4 times by tree search, its
  # final visit count should just be 1.
  N(player.root) == 1
  # 0.085 = average(0, 0.17), since 0 is the prior on the root.
  @test Q(player.root) ≈ 0.085
end

function test_tree_search_failsafe()
  # Test that the failsafe works correctly. It can trigger if the MCTS
  # repeatedly visits a finished game state.
  probs = ones(go.N * go.N + 1) * 0.001
  probs[end] = 1  # Make the dummy net always want to pass
  player = MCTSPlayer(DummyNet(fake_priors = probs))
  pass_position = go.pass_move!(go.Position())
  initialize_game!(player, pass_position)
  tree_search!(player, 1)
  assertNoPendingVirtualLosses(player.root)
end

function test_only_check_game_end_once()
  # When presented with a situation where the last move was a pass,
  # and we have to decide whether to pass, it should be the first thing
  # we check, but not more than that.

  white_passed_pos = go.pass_move!(
                      go.play_move!(
                        go.play_move!(
                          go.play_move!(
                            go.Position(), (4,4) # b plays
                              ), (4,5)  # w plays
                            ), (5,4)  # b plays
                          ) # w passes - if B passes too, B would lose by komi.
                        )

  player = MCTSPlayer(DummyNet())
  initialize_game!(player, white_passed_pos)
  # initialize the root
  tree_search!(player)
  # explore a child - should be a pass move.
  tree_search!(player)
  pass_move = go.N * go.N + 1
  @test N(player.root.children[pass_move]) == 1
  @test player.root.child_N[pass_move] == 1
  tree_search!(player)
  # check that we didn't visit the pass node any more times.
  @test player.root.child_N[pass_move] == 1
end

function test_extract_data_normal_end()
  player = MCTSPlayer(DummyNet())
  initialize_game!(player)
  tree_search!(player)
  play_move!(player, nothing)
  tree_search!(player)
  play_move!(player, nothing)
  @test is_done(player.root)
  set_result!(player, go.result(player.root.position), false)

  positions, πs, results = extract_data(player)
  @test length(positions) == size(πs, 2) == length(results) == 2
  position, pi, result = positions[1], πs[:, 1], results[1]
  # White wins by komi
  @test result == go.WHITE
  @test player.result_string == "W+$(player.root.position.komi)"
end

function test_extract_data_resign_end()
  player = MCTSPlayer(DummyNet())
  initialize_game!(player)
  tree_search!(player)
  play_move!(player, (1, 1))
  tree_search!(player)
  play_move!(player, nothing)
  tree_search!(player)
  # Black is winning on the board
  @test go.result(player.root.position) == go.BLACK
  # But if Black resigns
  set_result!(player, go.WHITE, true)

  data = extract_data(player)
  position, pi, result = data[1], data[2], data[3]
  # Result should say White is the winner
  @test result[1] == go.WHITE
  @test player.result_string == "W+R"
end
