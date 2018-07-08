using AlphaGo
using AlphaGo: from_kgs, from_sgf, BLACK, WHITE, EMPTY, MISSING_GROUP_ID,
              GoPosition, is_koish, is_eyeish, PlayerMove, is_move_legal,
              is_move_suicidal, score, from_board, flip_playerturn!, add_stone!,
              all_legal_moves, IllegalMove, from_flat, pass_move!, play_move!
using Base.Test

include("test_utils.jl")

pc_set(string, env::GoEnv) = Set(map(from_kgs, split(string),
                                        repmat([env], length(split(string)))))

@testset "go" begin
  env = GoEnv(9)
  EMPTY_ROW = repeat(".", env.N) * "\n"
  TEST_BOARD = load_board("""
                          .X.....OO
                          X........
                          """ * repeat(EMPTY_ROW, 7), env)
    @testset "load_board" begin
    @test assertEqualArray(env.EMPTY_BOARD, zeros(env.N, env.N))
    @test assertEqualArray(env.EMPTY_BOARD, load_board(repeat(". \n", env.N ^ 2), env))
  end

  @testset "parsing" begin
    @test from_kgs("A9", env) == (1, 1)
    @test from_sgf("aa") == (1, 1)
    @test from_kgs("A3", env) == (7, 1)
    @test from_sgf("ac") == (3, 1)
    @test from_kgs("D4", env) == from_sgf("df")
  end

  @testset "neighbors" begin
    corner = from_kgs("A1", env)
    neighbors = [env.EMPTY_BOARD[c...] for c in env.NEIGHBORS[corner...]]
    @test length(neighbors) == 2

    side = from_kgs("A2", env)
    side_neighbors = [env.EMPTY_BOARD[c...] for c in env.NEIGHBORS[side...]]
    @test length(side_neighbors) == 3
  end

  @testset "is_koish" begin
    @test is_koish(TEST_BOARD, from_kgs("A9", env), env) == BLACK
    @test is_koish(TEST_BOARD, from_kgs("B8", env), env) == nothing
    @test is_koish(TEST_BOARD, from_kgs("B9", env), env) == nothing
    @test is_koish(TEST_BOARD, from_kgs("E5", env), env) == nothing
  end

  @testset "is_eyeish" begin
    board = load_board("""
              .XX...XXX
              X.X...X.X
              XX.....X.
              ........X
              XXXX.....
              OOOX....O
              X.OXX.OO.
              .XO.X.O.O
              XXO.X.OO.
          """, env)
    B_eyes = pc_set("A2 A9 B8 J7 H8", env)
    W_eyes = pc_set("H2 J1 J3", env)
    not_eyes = pc_set("B3 E5", env)
    for be in B_eyes
      @test is_eyeish(board, be, env) == BLACK ? true : throw(AssertionError(string(be)))
    end
    for we in W_eyes
      @test is_eyeish(board, we, env) == WHITE ? true : throw(AssertionError(string(we)))
    end
    for ne in not_eyes
      @test is_eyeish(board, ne, env) == nothing ? true : throw(AssertionError(string(ne)))
    end
  end
  @testset "lib_tracker_init" begin
    board = load_board("X........" * repeat(EMPTY_ROW, 8), env)

    lib_tracker = from_board(board, env)
    @test length(lib_tracker.groups) == 1
    @test lib_tracker.group_index[from_kgs("A9", env)...] != MISSING_GROUP_ID
    @test lib_tracker.liberty_cache[from_kgs("A9", env)...] == 2
    sole_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("A9", env)...]]
    @test sole_group.stones == pc_set("A9", env)
    @test sole_group.liberties == pc_set("B9 A8", env)
    @test sole_group.color == BLACK
  end

  @testset "place_stone" begin
    board = load_board("X........" * repeat(EMPTY_ROW, 8), env)
    lib_tracker = from_board(board, env)
    add_stone!(lib_tracker, BLACK, from_kgs("B9", env), env)
    @test length(lib_tracker.groups) == 1
    @test lib_tracker.group_index[from_kgs("A9", env)...] != MISSING_GROUP_ID
    @test lib_tracker.liberty_cache[from_kgs("A9", env)...] == 3
    @test lib_tracker.liberty_cache[from_kgs("B9", env)...] == 3
    sole_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("A9", env)...]]
    @test sole_group.stones == pc_set("A9 B9", env)
    @test sole_group.liberties == pc_set("C9 A8 B8", env)
    @test sole_group.color == BLACK
  end

  @testset "place_stone_opposite_color" begin
    board = load_board("X........" * repeat(EMPTY_ROW, 8), env)
    lib_tracker = from_board(board, env)
    add_stone!(lib_tracker, WHITE, from_kgs("B9", env), env)
    @test length(lib_tracker.groups) == 2
    @test lib_tracker.group_index[from_kgs("A9", env)...] != MISSING_GROUP_ID
    @test lib_tracker.group_index[from_kgs("B9", env)...] != MISSING_GROUP_ID
    @test lib_tracker.liberty_cache[from_kgs("A9", env)...] == 1
    @test lib_tracker.liberty_cache[from_kgs("B9", env)...] == 2
    black_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("A9", env)...]]
    white_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("B9", env)...]]
    @test black_group.stones == pc_set("A9", env)
    @test black_group.liberties == pc_set("A8", env)
    @test black_group.color == BLACK
    @test white_group.stones == pc_set("B9", env)
    @test white_group.liberties == pc_set("C9 B8", env)
    @test white_group.color == WHITE
  end

  @testset "merge_multiple_groups" begin
    board = load_board("""
        .X.......
        X.X......
        .X.......
    """ * repeat(EMPTY_ROW, 6), env)
    lib_tracker = from_board(board,env)
    add_stone!(lib_tracker, BLACK, from_kgs("B8", env), env)
    @test length(lib_tracker.groups) == 1
    @test lib_tracker.group_index[from_kgs("B8", env)...] != MISSING_GROUP_ID
    sole_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("B8", env)...]]
    @test sole_group.stones == pc_set("B9 A8 B8 C8 B7", env)
    @test sole_group.liberties == pc_set("A9 C9 D8 A7 C7 B6", env)
    @test sole_group.color == BLACK

    liberty_cache = lib_tracker.liberty_cache
    for stone in sole_group.stones
      @test liberty_cache[stone...] == 6 ? true : throw(AssertionError(string(stone)))
    end
  end

  @testset "capture_stone" begin
    board = load_board("""
        .X.......
        XO.......
        .X.......
    """ * repeat(EMPTY_ROW, 6), env)
    lib_tracker = from_board(board, env)
    captured = add_stone!(lib_tracker, BLACK, from_kgs("C8", env), env)
    @test length(lib_tracker.groups) == 4
    @test lib_tracker.group_index[from_kgs("B8", env)...] == MISSING_GROUP_ID
    @test captured == pc_set("B8", env)
  end

  @testset "capture_many" begin
    board = load_board("""
        .XX......
        XOO......
        .XX......
    """ * repeat(EMPTY_ROW, 6), env)
    lib_tracker = from_board(board, env)
    captured = add_stone!(lib_tracker, BLACK, from_kgs("D8", env), env)
    @test length(lib_tracker.groups) == 4
    @test lib_tracker.group_index[from_kgs("B8", env)...] == MISSING_GROUP_ID
    @test captured == pc_set("B8 C8", env)

    left_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("A8", env)...]]
    @test left_group.stones == pc_set("A8", env)
    @test left_group.liberties == pc_set("A9 B8 A7", env)

    right_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("D8", env)...]]
    @test right_group.stones == pc_set("D8", env)
    @test right_group.liberties == pc_set("D9 C8 E8 D7", env)

    top_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("B9", env)...]]
    @test top_group.stones == pc_set("B9 C9", env)
    @test top_group.liberties == pc_set("A9 D9 B8 C8", env)

    bottom_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("B7", env)...]]
    @test bottom_group.stones == pc_set("B7 C7", env)
    @test bottom_group.liberties == pc_set("B8 C8 A7 D7 B6 C6", env)

    liberty_cache = lib_tracker.liberty_cache
    for stone in top_group.stones
      @test liberty_cache[stone...] == 4 ? true : throw(AssertionError(string(stone)))
    end
    for stone in left_group.stones
      @test liberty_cache[stone...] == 3 ? true: throw(AssertionError(string(stone)))
    end
    for stone in right_group.stones
      @test liberty_cache[stone...] == 4 ? true : throw(AssertionError(string(stone)))
    end
    for stone in bottom_group.stones
      @test liberty_cache[stone...] == 6 ? true : throw(AssertionError(string(stone)))
    end
    for stone in captured
      @test liberty_cache[stone...] == 0 ? true : throw(AssertionError(string(stone)))
    end
  end

  @testset "capture_multiple_groups" begin
    board = load_board("""
        .OX......
        OXX......
        XX.......
    """ * repeat(EMPTY_ROW, 6), env)
    lib_tracker = from_board(board, env)
    captured = add_stone!(lib_tracker, BLACK, from_kgs("A9", env), env)
    @test length(lib_tracker.groups) == 2
    @test captured == pc_set("B9 A8", env)

    corner_stone = lib_tracker.groups[lib_tracker.group_index[from_kgs("A9", env)...]]
    @test corner_stone.stones == pc_set("A9", env)
    @test corner_stone.liberties == pc_set("B9 A8", env)

    surrounding_stones = lib_tracker.groups[lib_tracker.group_index[from_kgs("C9", env)...]]
    @test surrounding_stones.stones == pc_set("C9 B8 C8 A7 B7", env)
    @test surrounding_stones.liberties == pc_set("B9 D9 A8 D8 C7 A6 B6", env)

    liberty_cache = lib_tracker.liberty_cache
    for stone in corner_stone.stones
      @test liberty_cache[stone...] == 2 ? true : throw(AssertionError(string(stone)))
    end
    for stone in surrounding_stones.stones
      @test liberty_cache[stone...] == 7 ? true : throw(AssertionError(string(stone)))
    end
  end

  @testset "same_friendly_group_neighboring_twice" begin
    board = load_board("""
        XX.......
        X........
    """ * repeat(EMPTY_ROW, 7), env)

    lib_tracker = from_board(board, env)
    captured = add_stone!(lib_tracker, BLACK, from_kgs("B8", env), env)
    @test length(lib_tracker.groups) == 1
    sole_group_id = lib_tracker.group_index[from_kgs("A9", env)...]
    sole_group = lib_tracker.groups[sole_group_id]
    @test sole_group.stones == pc_set("A9 B9 A8 B8", env)
    @test sole_group.liberties == pc_set("C9 C8 A7 B7", env)
    @test captured == Set()
  end

  @testset "same_opponent_group_neighboring_twice" begin
    board = load_board("""
        XX.......
        X........
    """ * repeat(EMPTY_ROW, 7), env)

    lib_tracker = from_board(board, env)
    captured = add_stone!(lib_tracker, WHITE, from_kgs("B8", env), env)
    @test length(lib_tracker.groups) == 2
    black_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("A9", env)...]]
    @test black_group.stones == pc_set("A9 B9 A8", env)
    @test black_group.liberties == pc_set("C9 A7", env)

    white_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("B8", env)...]]
    @test white_group.stones == pc_set("B8", env)
    @test white_group.liberties == pc_set("C8 B7", env)

    @test captured == Set()
  end

  @testset "passing" begin
    start_position = GoPosition(env,
        board = TEST_BOARD,
        n = 0,
        komi = 6.5,
        caps = (1, 2),
        ko = PlayerMove(from_kgs("A1", env)...),
        recent = Vector{PlayerMove}(),
        to_play = BLACK
    )
    expected_position = GoPosition(env,
        board = TEST_BOARD,
        n = 1,
        komi = 6.5,
        caps = (1, 2),
        ko = nothing,
        recent = [PlayerMove(BLACK, nothing)],
        to_play = WHITE
    )
    pass_position = pass_move!(start_position)
    @test assertEqualPositions(pass_position, expected_position)
  end

  @testset "flipturn" begin
    start_position = GoPosition(env,
        board = TEST_BOARD,
        n = 0,
        komi = 6.5,
        caps = (1, 2),
        ko = PlayerMove(from_kgs("A1", env)...),
        recent = Vector{PlayerMove}(),
        to_play = BLACK
    )
    expected_position = GoPosition(env,
        board = TEST_BOARD,
        n = 0,
        komi = 6.5,
        caps = (1, 2),
        ko = nothing,
        recent = Vector{PlayerMove}(),
        to_play = WHITE
    )
    flip_position = flip_playerturn!(start_position)
    @test assertEqualPositions(flip_position, expected_position)
  end

  @testset "is_move_suicidal" begin
    board = load_board("""
        ...O.O...
        ....O....
        XO.....O.
        OXO...OXO
        O.XO.OX.O
        OXO...OOX
        XO.......
        ......XXO
        .....XOO.
    """, env)
    position = GoPosition(env,
        board = board,
        to_play = BLACK
    )
    suicidal_moves = pc_set("E9 H5", env)
    nonsuicidal_moves = pc_set("B5 J1 A9", env)
    for move in suicidal_moves
      @test position.board[move...] == EMPTY #sanity check my coordinate input
      @test is_move_suicidal(position, move) ? true : throw(AssertionError(string(move)))
    end
    for move in nonsuicidal_moves
      @test position.board[move...] == EMPTY # sanity check my coordinate input
      @test !is_move_suicidal(position, move) ? true : throw(AssertionError(string(move)))
    end
  end

  @testset "legal_moves" begin
    board = load_board("""
        .O.O.XOX.
        O..OOOOOX
        ......O.O
        OO.....OX
        XO.....X.
        .O.......
        OX.....OO
        XX...OOOX
        .....O.X.
    """, env)
    position = GoPosition(env,
        board = board,
        to_play = BLACK)
    illegal_moves = pc_set("A9 E9 J9", env)
    legal_moves = pc_set("A4 G1 J1 H7", env)
    for move in illegal_moves
      @test !is_move_legal(position, move)
    end
    for move in legal_moves
      @test is_move_legal(position, move)
    end
    # check that the bulk legal test agrees with move-by-move illegal test.
    bulk_legality = all_legal_moves(position)
    for (i, bulk_legal) in enumerate(bulk_legality)
      @test is_move_legal(position, from_flat(i, position)) == bulk_legal
    end
    # flip the colors and check that everything is still (il)legal
    position = GoPosition(env,board = -board, to_play = WHITE)
    for move in illegal_moves
      @test !is_move_legal(position, move)
    end
    for move in legal_moves
      @test is_move_legal(position, move)
    end
    bulk_legality = all_legal_moves(position)
    for (i, bulk_legal) in enumerate(bulk_legality)
      @test is_move_legal(position, from_flat(i, position)) == bulk_legal
    end
  end

  @testset "move" begin
    start_position = GoPosition(env,
        board=TEST_BOARD,
        n = 0,
        komi = 6.5,
        caps =(1, 2),
        ko = nothing,
        recent = Vector{PlayerMove}(),
        to_play = BLACK
    )
    expected_board = load_board("""
        .XX....OO
        X........
    """ * repeat(EMPTY_ROW, 7), env)
    expected_position = GoPosition(env,
        board = expected_board,
        n = 1,
        komi = 6.5,
        caps = (1, 2),
        ko = nothing,
        recent=[PlayerMove(BLACK, from_kgs("C9", env))],
        to_play = WHITE
    )
    actual_position = play_move!(start_position, from_kgs("C9", env))
    @test assertEqualPositions(actual_position, expected_position)

    expected_board2 = load_board("""
        .XX....OO
        X.......O
    """ * repeat(EMPTY_ROW, 7), env)
    expected_position2 = GoPosition(env,
        board = expected_board2,
        n = 2,
        komi = 6.5,
        caps = (1, 2),
        ko = nothing,
        recent = [PlayerMove(BLACK, from_kgs("C9", env)), PlayerMove(WHITE, from_kgs("J8", env))],
        to_play = BLACK
    )
    actual_position2 = play_move!(actual_position, from_kgs("J8", env))
    @test assertEqualPositions(actual_position2, expected_position2)
  end

  @testset "move_with_capture" begin
    start_board = load_board(repeat(EMPTY_ROW, 5) * """
        XXXX.....
        XOOX.....
        O.OX.....
        OOXX.....
    """, env)
    start_position = GoPosition(env,
        board = start_board,
        n = 0,
        komi = 6.5,
        caps = (1, 2),
        ko = nothing,
        recent = Vector{PlayerMove}(),
        to_play = BLACK
    )
    expected_board = load_board(repeat(EMPTY_ROW, 5) * """
        XXXX.....
        X..X.....
        .X.X.....
        ..XX.....
    """, env)
    expected_position = GoPosition(env,
        board = expected_board,
        n = 1,
        komi = 6.5,
        caps = (7, 2),
        ko = nothing,
        recent = Vector{PlayerMove}([PlayerMove(BLACK, from_kgs("B2", env))]),
        to_play = WHITE
    )
    actual_position = play_move!(start_position, from_kgs("B2", env))
    @test assertEqualPositions(actual_position, expected_position)
  end

  @testset "ko_move" begin
    start_board = load_board("""
        .OX......
        OX.......
    """ * repeat(EMPTY_ROW, 7), env)
    start_position = GoPosition(env,
        board = start_board,
        n = 0,
        komi = 6.5,
        caps = (1, 2),
        ko = nothing,
        recent = Vector{PlayerMove}(),
        to_play = BLACK
    )
    expected_board = load_board("""
        X.X......
        OX.......
    """ * repeat(EMPTY_ROW, 7), env)
    expected_position = GoPosition(env,
        board = expected_board,
        n = 1,
        komi = 6.5,
        caps = (2, 2),
        ko = from_kgs("B9", env),
        recent = Vector{PlayerMove}([PlayerMove(BLACK, from_kgs("A9", env))]),
        to_play = WHITE
    )
    actual_position = play_move!(start_position, from_kgs("A9", env))
    @test assertEqualPositions(actual_position, expected_position)

    # Check that retaking ko is illegal until two intervening moves
    @test_throws IllegalMove play_move!(actual_position, from_kgs("B9", env))
    pass_twice = pass_move!(pass_move!(actual_position))
    ko_delayed_retake = play_move!(pass_twice, from_kgs("B9", env))
    expected_position = GoPosition(env,
        board = start_board,
        n = 4,
        komi = 6.5,
        caps = (2, 3),
        ko = from_kgs("A9", env),
        recent = Vector{PlayerMove}([
            PlayerMove(BLACK, from_kgs("A9", env)),
            PlayerMove(WHITE, nothing),
            PlayerMove(BLACK, nothing),
            PlayerMove(WHITE, from_kgs("B9", env))]),
        to_play = BLACK
        )

    @test assertEqualPositions(ko_delayed_retake, expected_position)
  end

  @testset "is_game_over" begin
    root = GoPosition(env)
    @test !root.done
    first_pass = play_move!(root, nothing)
    @test !first_pass.done
    second_pass = play_move!(first_pass, nothing)
    @test second_pass.done
  end

  @testset "scoring" begin
    board = load_board("""
        .XX......
        OOXX.....
        OOOX...X.
        OXX......
        OOXXXXXX.
        OOOXOXOXX
        .O.OOXOOX
        .O.O.OOXX
        ......OOO
    """, env)
    position = GoPosition(env,
        board = board,
        n = 54,
        komi = 6.5,
        caps = (2, 5),
        ko = nothing,
        recent = Vector{PlayerMove}(),
        to_play = BLACK
    )
    expected_score = 1.5
    @test score(position) == expected_score

    board = load_board("""
        XXX......
        OOXX.....
        OOOX...X.
        OXX......
        OOXXXXXX.
        OOOXOXOXX
        .O.OOXOOX
        .O.O.OOXX
        ......OOO
      """, env)
    position = GoPosition(env,
        board = board,
        n = 55,
        komi = 6.5,
        caps = (2, 5),
        ko = nothing,
        recent = Vector{PlayerMove}(),
        to_play = WHITE
    )
    expected_score = 2.5
    @test score(position) == expected_score
  end
end
