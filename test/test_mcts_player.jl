using Flux: param
using AlphaGo, AlphaGo.Game
using AlphaGo: select_leaf, incorporate_results!, child_U, inject_noise!,
                Q, N, child_Q, initialize_game!, tree_search!, MCTSRules,
                get_position, extract_data, num_moves, board_size
using AlphaGo.Game: pass_move!, play_move!, PlayerMove, to_kgs, score, from_kgs,
                    to_flat, result

include("test_utils.jl")

struct DummyNet
  fake_priors
  fake_value
end

function DummyNet(env::AbstractEnv; fake_priors = nothing, fake_value = 0)
  if fake_priors === nothing
    len = length(env.board_data.action_space)
    fake_priors = ones(len) / len
  end
  DummyNet(fake_priors, fake_value)
end

(dn::DummyNet)(position::Position) = param(dn.fake_priors),
                                      param(dn.fake_value)

function (dn::DummyNet)(positions = nothing)
  if positions === nothing || isempty(positions)
    throw(ArgumentError("No positions passed!"))
  end
  len = length(positions)
  param(repeat(dn.fake_priors, outer = [1, len])),
          param(repeat([dn.fake_value], len))
end

board_sz = 9
env = Go(board_sz)
planes = 8

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
                              """, board_sz)

SEND_TWO_RETURN_ONE = GoPosition(board_sz, planes,
    board = ALMOST_DONE_BOARD,
    n = 70,
    komi = 2.5,
    caps = (1, 4),
    ko = nothing,
    recent = [PlayerMove(env.colors["BLACK"], (1, 2)),
    PlayerMove(env.colors["WHITE"], (1, 9))],
    to_play = env.colors["BLACK"]
    )

function initialize_basic_player(env::AbstractEnv)
  player = MCTSPlayer(env, DummyNet(env))
  initialize_game!(player, env)
  first_node = select_leaf(player.root)
  p, v = player.network(get_position(player.root))
  incorporate_results!(first_node, p.data, v.data, player.root)
  return player
end

function initialize_almost_done_player(env)
  probs = ones(length(env.board_data.action_space)) * 0.001
  probs[3:5] .= 0.2  # some legal moves along the top.
  probs[end] = 0.2  # passing is also ok
  net = DummyNet(env; fake_priors = probs)
  player = MCTSPlayer(env, net)
  # root position is white to play with no history == white passed.
  initialize_game!(player, SEND_TWO_RETURN_ONE)
  return player
end

@testset "MCTSPlayer" begin
  # Tromp taylor means black can win if we hit the move limit.
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
                            """, board_sz)

  @testset "inject_noise" begin
    player = initialize_basic_player(env)
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
    @test max_p > 3 / (length(env.board_data.action_space))
  end

  @testset "pick_moves" begin
    player = initialize_basic_player(env)
    root = player.root
    root.child_N[to_flat((3, 1), root.position)] = 10
    root.child_N[to_flat((2, 1), root.position)] = 5
    root.child_N[to_flat((4, 1), root.position)] = 1

    root.position.n = length(env.board_data.action_space)  # move 81, or 361, or... Endgame.

    # Assert we're picking deterministically
    @test num_moves(get_position(root)) > player.τ_threshold
    move = pick_move(player)
    @test move == (3, 1)

    # But if we're in the early part of the game, pick randomly
    root.position.n = 3
    @test num_moves(get_position(player)) ≤ player.τ_threshold

    #TODO: complete this test
    #with mock.patch('random.random', lambda: .5)
    #move = pick_move(player)
    #@test move == (3, 1)

    #with mock.patch('random.random', lambda: .99):
    #move = pick_move(player)
    #@test move == (4, 1)
  end

 @testset "dont_pass_if_losing" begin
    player = initialize_almost_done_player(env)

    # check -- white is losing.
    @test score(get_position(player)) == -0.5

    for i = 1:10
      tree_search!(player)
    end

    # uncomment to debug this test
    #println(describe(player.root))

    # Search should converge on D9 as only winning move.
    board_sz = board_size(get_position(player))
    flattened = to_flat(from_kgs("D9", board_sz), board_sz)
    best_move = findmax(player.root.child_N)[2]
    @test best_move == flattened
    # D9 should have a positive value
    @test Q(player.root.children[flattened]) > 0
    @test N(player.root) ≥ 20
    # passing should be ineffective.
    @test child_Q(player.root)[end] < 0
    # no virtual losses should be pending
    @test assertNoPendingVirtualLosses(player.root)
  end

  @testset "parallel_tree_search" begin
    player = initialize_almost_done_player(env)
    # check -- white is losing.
    @assert score(player.root.position) == -0.5
    # initialize the tree so that the root node has populated children.
    tree_search!(player, 1)
    # virtual losses should enable multiple searches to happen simultaneously
    # without throwing an error...
    for i = 1:5
      tree_search!(player, 4)
    end
    # uncomment to debug this test
    # print(player.root.describe())
    pos = get_position(player)
    # Search should converge on D9 as only winning move.
    flattened = to_flat(from_kgs("D9", pos), pos)
    best_moves = findall(x -> x .== maximum(player.root.child_N), player.root.child_N)

    @test flattened ∈ best_moves
    # D9 should have a positive value
    @test Q(player.root.children[flattened]) > 0
    @test N(player.root) ≥ 20
    # passing should be ineffective.
    child_Q(player.root)[end] < 0
    # no virtual losses should be pending
    @test assertNoPendingVirtualLosses(player.root)
  end

  @testset "ridiculously_parallel_tree_search" begin
    player = initialize_almost_done_player(env)
    # Test that an almost complete game
    # will tree search with # parallelism > # legal moves.
    for i = 1:10
      tree_search!(player, 50)
    end
    @test assertNoPendingVirtualLosses(player.root)
  end

  @testset "long_game_tree_search" begin
    mcts_rules = MCTSRules(env)
    player = MCTSPlayer(env, DummyNet(env))
    endgame = GoPosition(board_sz, planes,
        board = TT_FTW_BOARD,
        n = mcts_rules.max_game_length - 2,
        komi = 2.5,
        ko = nothing,
        recent = [PlayerMove(env.colors["BLACK"], (1, 2)),
                PlayerMove(env.colors["WHITE"], (1, 9))],
        to_play = env.colors["BLACK"]
    )
    initialize_game!(player, endgame)

    # Test that MCTS can deduce that B wins because of TT-scoring
    # triggered by move limit.
    for i = 1:10
      tree_search!(player)
    end

    @test assertNoPendingVirtualLosses(player.root)
    @test Q(player.root) > 0
  end

  @testset "cold_start_parallel_tree_search" begin
    # Test that parallel tree search doesn't trip on an empty tree
    player = MCTSPlayer(env, DummyNet(env, fake_value = 0.17))
    initialize_game!(player, env)
    @test N(player.root) == 0
    @test !player.root.is_expanded
    tree_search!(player, 4)
    @test assertNoPendingVirtualLosses(player.root)
    # Even though the root gets selected 4 times by tree search, its
    # final visit count should just be 1.
    N(player.root) == 1
    # 0.085 = average(0, 0.17), since 0 is the prior on the root.
    @test Q(player.root) ≈ 0.085
  end

  @testset "tree_search_failsafe" begin
    # Test that the failsafe works correctly. It can trigger if the MCTS
    # repeatedly visits a finished game state.
    probs = ones(board_sz ^ 2 + 1) * 0.001
    probs[end] = 1  # Make the dummy net always want to pass
    player = MCTSPlayer(env, DummyNet(env, fake_priors = probs))
    pass_position = pass_move!(GoPosition(board_sz, planes))
    initialize_game!(player, pass_position)
    tree_search!(player, 1)
    @test assertNoPendingVirtualLosses(player.root)
  end

  @testset "only_check_game_end_once" begin
    # When presented with a situation where the last move was a pass,
    # and we have to decide whether to pass, it should be the first thing
    # we check, but not more than that.

    white_passed_pos = pass_move!(
                        play_move!(
                          play_move!(
                            play_move!(
                              GoPosition(board_sz, planes), (4,4) # b plays
                                ), (4,5)  # w plays
                              ), (5,4)  # b plays
                            ) # w passes - if B passes too, B would lose by komi.
                          )

    player = MCTSPlayer(env, DummyNet(env))
    initialize_game!(player, white_passed_pos)
    # initialize the root
    for i = 1:15
      tree_search!(player)
    end
    # explore a child - should be a pass move.
    #tree_search!(player, 10)
    pass_move = board_sz ^ 2 + 1
    @test N(player.root.children[pass_move]) == 1
    @test player.root.child_N[pass_move] == 1
    tree_search!(player)
    # check that we didn't visit the pass node any more times.
    @test player.root.child_N[pass_move] == 1
  end

  @testset "extract_data_normal_end" begin
    player = MCTSPlayer(env, DummyNet(env))
    initialize_game!(player, env)
    tree_search!(player)
    play_move!(player, nothing)
    tree_search!(player)
    play_move!(player, nothing)
    @test is_done(player.root)

    pos = get_position(player)
    set_result!(player, result(pos), false)
    positions, πs, res = extract_data(player)
    @test length(positions) == length(πs) == length(res) == 2
    position, pi, res = positions[1], πs[1], res[1]

    # White wins by komi
    @test res == env.colors["WHITE"]
    @test player.result_string == "W+$(pos.komi)"
  end

  @testset "extract_data_resign_end" begin
    player = MCTSPlayer(env, DummyNet(env))
    initialize_game!(player, env)
    tree_search!(player)
    play_move!(player, (1, 1))
    tree_search!(player)
    play_move!(player, nothing)
    tree_search!(player)
    # Black is winning on the board
    @test result(get_position(player)) == env.colors["BLACK"]
    # But if Black resigns
    set_result!(player, env.colors["WHITE"], true)

    data = extract_data(player)
    position, pi, res = data[1], data[2], data[3]
    # Result should say White is the winner
    @test res[1] == env.colors["WHITE"]
    @test player.result_string == "W+R"
  end
end
