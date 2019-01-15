using AlphaGo.Game
using AlphaGo.Game: from_kgs, from_sgf, from_flat, GoPosition, is_koish,
                    is_eyeish, PlayerMove, is_move_legal, is_move_suicidal,
                    score, from_board, flip_playerturn!, add_stone!,
                    legal_moves, pass_move!, play_move!, neighbors

include("test_utils.jl")

pc_set(string::String, N::UInt8) = Set(map(from_kgs,
                            split(string), repeat([N], length(split(string)))))

@testset "go" begin
  N::UInt8 = 9
  MISSING_GROUP_ID = -1

  env = Go(N)
  EMPTY_ROW = repeat(".", N) * "\n"
  EMPTY_BOARD = zeros(Int8, N, N)
  TEST_BOARD = load_board("""
                          .X.....OO
                          X........
                          """ * repeat(EMPTY_ROW, 7), N)

  @testset "load_board" begin
    @test assertEqualArray(EMPTY_BOARD, zeros(N, N))
    @test assertEqualArray(EMPTY_BOARD, load_board(repeat(". \n", N ^ 2), N))
  end

  @testset "parsing" begin
    @test from_kgs("A9", N) == (1, 1)
    @test from_sgf("aa") == (1, 1)
    @test from_kgs("A3", N) == (7, 1)
    @test from_sgf("ac") == (3, 1)
    @test from_kgs("D4", N) == from_sgf("df")
  end

  @testset "neighbors" begin
    corner = from_kgs("A1", N)
    neighs = neighbors(corner, N)
    neighs = [EMPTY_BOARD[c...] for c in neighs]
    @test length(neighs) == 2

    side = from_kgs("A2", N)
    neighs = neighbors(side, N)
    side_neighbors = [EMPTY_BOARD[c...] for c in neighs]
    @test length(side_neighbors) == 3
  end

  @testset "is_koish" begin
    @test is_koish(TEST_BOARD, from_kgs("A9", N)) ==  env.colors["BLACK"]
    @test is_koish(TEST_BOARD, from_kgs("B8", N)) === nothing
    @test is_koish(TEST_BOARD, from_kgs("B9", N)) === nothing
    @test is_koish(TEST_BOARD, from_kgs("E5", N)) === nothing
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
          """, N)
    B_eyes = pc_set("A2 A9 B8 J7 H8", N)
    W_eyes = pc_set("H2 J1 J3", N)
    not_eyes = pc_set("B3 E5", N)

    for be in B_eyes
      @test is_eyeish(board, be) == env.colors["BLACK"] ? true : throw(AssertionError(string(be)))
    end

    for we in W_eyes
      @test is_eyeish(board, we) == env.colors["WHITE"] ? true : throw(AssertionError(string(we)))
    end

    for ne in not_eyes
      @test is_eyeish(board, ne) === nothing ? true : throw(AssertionError(string(ne)))
    end
  end

  @testset "lib_tracker_init" begin
    board = load_board("X........" * repeat(EMPTY_ROW, 8), N)

    lib_tracker = from_board(board)
    @test length(lib_tracker.groups) == 1
    @test lib_tracker.group_index[from_kgs("A9", N)...] != MISSING_GROUP_ID
    @test lib_tracker.liberty_cache[from_kgs("A9", N)...] == 2
    sole_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("A9", N)...]]
    @test sole_group.stones == pc_set("A9", N)
    @test sole_group.liberties == pc_set("B9 A8", N)
    @test sole_group.color == env.colors["BLACK"]
  end

  @testset "place_stone" begin
    board = load_board("X........" * repeat(EMPTY_ROW, 8), N)
    lib_tracker = from_board(board)
    add_stone!(lib_tracker, env.colors["BLACK"], from_kgs("B9", N))
    @test length(lib_tracker.groups) == 1
    @test lib_tracker.group_index[from_kgs("A9", N)...] != MISSING_GROUP_ID
    @test lib_tracker.liberty_cache[from_kgs("A9", N)...] == 3
    @test lib_tracker.liberty_cache[from_kgs("B9", N)...] == 3
    sole_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("A9", N)...]]
    @test sole_group.stones == pc_set("A9 B9", N)
    @test sole_group.liberties == pc_set("C9 A8 B8", N)
    @test sole_group.color == env.colors["BLACK"]
  end

  @testset "place_stone_opposite_color" begin
    board = load_board("X........" * repeat(EMPTY_ROW, 8), N)
    lib_tracker = from_board(board)
    add_stone!(lib_tracker, env.colors["WHITE"], from_kgs("B9", N))
    @test length(lib_tracker.groups) == 2
    @test lib_tracker.group_index[from_kgs("A9", N)...] != MISSING_GROUP_ID
    @test lib_tracker.group_index[from_kgs("B9", N)...] != MISSING_GROUP_ID
    @test lib_tracker.liberty_cache[from_kgs("A9", N)...] == 1
    @test lib_tracker.liberty_cache[from_kgs("B9", N)...] == 2
    black_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("A9", N)...]]
    white_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("B9", N)...]]
    @test black_group.stones == pc_set("A9", N)
    @test black_group.liberties == pc_set("A8", N)
    @test black_group.color == env.colors["BLACK"]
    @test white_group.stones == pc_set("B9", N)
    @test white_group.liberties == pc_set("C9 B8", N)
    @test white_group.color == env.colors["WHITE"]
  end

  @testset "merge_multiple_groups" begin
    board = load_board("""
        .X.......
        X.X......
        .X.......
    """ * repeat(EMPTY_ROW, 6), N)
    lib_tracker = from_board(board)
    add_stone!(lib_tracker, env.colors["BLACK"], from_kgs("B8", N))
    @test length(lib_tracker.groups) == 1
    @test lib_tracker.group_index[from_kgs("B8", N)...] != MISSING_GROUP_ID
    sole_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("B8", N)...]]
    @test sole_group.stones == pc_set("B9 A8 B8 C8 B7", N)
    @test sole_group.liberties == pc_set("A9 C9 D8 A7 C7 B6", N)
    @test sole_group.color == env.colors["BLACK"]

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
    """ * repeat(EMPTY_ROW, 6), N)
    lib_tracker = from_board(board)
    captured = add_stone!(lib_tracker, env.colors["BLACK"], from_kgs("C8", N))
    @test length(lib_tracker.groups) == 4
    @test lib_tracker.group_index[from_kgs("B8", N)...] == MISSING_GROUP_ID
    @test captured == pc_set("B8", N)
  end

  @testset "capture_many" begin
    board = load_board("""
        .XX......
        XOO......
        .XX......
    """ * repeat(EMPTY_ROW, 6), N)
    lib_tracker = from_board(board)
    captured = add_stone!(lib_tracker, env.colors["BLACK"], from_kgs("D8", N))
    @test length(lib_tracker.groups) == 4
    @test lib_tracker.group_index[from_kgs("B8", N)...] == MISSING_GROUP_ID
    @test captured == pc_set("B8 C8", N)

    left_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("A8", N)...]]
    @test left_group.stones == pc_set("A8", N)
    @test left_group.liberties == pc_set("A9 B8 A7", N)

    right_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("D8", N)...]]
    @test right_group.stones == pc_set("D8", N)
    @test right_group.liberties == pc_set("D9 C8 E8 D7", N)

    top_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("B9", N)...]]
    @test top_group.stones == pc_set("B9 C9", N)
    @test top_group.liberties == pc_set("A9 D9 B8 C8", N)

    bottom_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("B7", N)...]]
    @test bottom_group.stones == pc_set("B7 C7", N)
    @test bottom_group.liberties == pc_set("B8 C8 A7 D7 B6 C6", N)

    liberty_cache = lib_tracker.liberty_cache
    for stone in top_group.stones
      @test liberty_cache[stone...] == 4 ? true : throw(AssertionError(string(stone)))
    end

    for stone in left_group.stones
      @test liberty_cache[stone...] == 3 ? true : throw(AssertionError(string(stone)))
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
    """ * repeat(EMPTY_ROW, 6), N)
    lib_tracker = from_board(board)
    captured = add_stone!(lib_tracker, env.colors["BLACK"], from_kgs("A9", N))
    @test length(lib_tracker.groups) == 2
    @test captured == pc_set("B9 A8", N)

    corner_stone = lib_tracker.groups[lib_tracker.group_index[from_kgs("A9", N)...]]
    @test corner_stone.stones == pc_set("A9", N)
    @test corner_stone.liberties == pc_set("B9 A8", N)

    surrounding_stones = lib_tracker.groups[lib_tracker.group_index[from_kgs("C9", N)...]]
    @test surrounding_stones.stones == pc_set("C9 B8 C8 A7 B7", N)
    @test surrounding_stones.liberties == pc_set("B9 D9 A8 D8 C7 A6 B6", N)

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
    """ * repeat(EMPTY_ROW, 7), N)

    lib_tracker = from_board(board)
    captured = add_stone!(lib_tracker, env.colors["BLACK"], from_kgs("B8", N))
    @test length(lib_tracker.groups) == 1
    sole_group_id = lib_tracker.group_index[from_kgs("A9", N)...]
    sole_group = lib_tracker.groups[sole_group_id]
    @test sole_group.stones == pc_set("A9 B9 A8 B8", N)
    @test sole_group.liberties == pc_set("C9 C8 A7 B7", N)
    @test captured == Set()
  end

  @testset "same_opponent_group_neighboring_twice" begin
    board = load_board("""
        XX.......
        X........
    """ * repeat(EMPTY_ROW, 7), N)

    lib_tracker = from_board(board)
    captured = add_stone!(lib_tracker, env.colors["WHITE"], from_kgs("B8", N))
    @test length(lib_tracker.groups) == 2
    black_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("A9", N)...]]
    @test black_group.stones == pc_set("A9 B9 A8", N)
    @test black_group.liberties == pc_set("C9 A7", N)

    white_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("B8", N)...]]
    @test white_group.stones == pc_set("B8", N)
    @test white_group.liberties == pc_set("C8 B7", N)

    @test captured == Set()
  end

  @testset "passing" begin
    start_position = GoPosition(N;
        board = TEST_BOARD,
        n = 0,
        komi = 6.5,
        caps = (1, 2),
        ko = PlayerMove(from_kgs("A1", N)...),
        recent = Vector{PlayerMove}(),
        to_play = env.colors["BLACK"]
    )
    expected_position = GoPosition(N;
        board = TEST_BOARD,
        n = 1,
        komi = 6.5,
        caps = (1, 2),
        ko = nothing,
        recent = [PlayerMove(env.colors["BLACK"], nothing)],
        to_play = env.colors["WHITE"]
    )
    pass_position = pass_move!(start_position)
    @test assertEqualPositions(pass_position, expected_position)
  end

  @testset "flipturn" begin
    start_position = GoPosition(N;
        board = TEST_BOARD,
        n = 0,
        komi = 6.5,
        caps = (1, 2),
        ko = PlayerMove(from_kgs("A1", N)...),
        recent = Vector{PlayerMove}(),
        to_play = env.colors["BLACK"]
    )
    expected_position = GoPosition(N;
        board = TEST_BOARD,
        n = 0,
        komi = 6.5,
        caps = (1, 2),
        ko = nothing,
        recent = Vector{PlayerMove}(),
        to_play = env.colors["WHITE"]
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
    """, N)
    position = GoPosition(N;
        board = board,
        to_play = env.colors["BLACK"]
    )
    suicidal_moves = pc_set("E9 H5", N)
    nonsuicidal_moves = pc_set("B5 J1 A9", N)

    for move in suicidal_moves
      @test position.board[move...] == env.colors["EMPTY"] #sanity check my coordinate input
      @test is_move_suicidal(position, move) ? true : throw(AssertionError(string(move)))
    end

    for move in nonsuicidal_moves
      @test position.board[move...] == env.colors["EMPTY"] # sanity check my coordinate input
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
    """, N)

    position = GoPosition(N;
        board = board,
        to_play = env.colors["BLACK"])

    illegal_mvs = pc_set("A9 E9 J9", N)
    legal_mvs = pc_set("A4 G1 J1 H7", N)

    for move in illegal_mvs
      @test !is_move_legal(position, move)
    end

    for move in legal_mvs
      @test is_move_legal(position, move)
    end
    # check that the bulk legal test agrees with move-by-move illegal test.
    bulk_legality = legal_moves(position)
    for (i, bulk_legal) in enumerate(bulk_legality)
      @test is_move_legal(position, from_flat(i, position)) == bulk_legal
    end

    # flip the colors and check that everything is still (il)legal
    position = GoPosition(N; board = -board, to_play = env.colors["WHITE"])

    for move in illegal_mvs
      @test !is_move_legal(position, move)
    end

    for move in legal_mvs
      @test is_move_legal(position, move)
    end

    bulk_legality = legal_moves(position)
    for (i, bulk_legal) in enumerate(bulk_legality)
      @test is_move_legal(position, from_flat(i, position)) == bulk_legal
    end
  end

  @testset "move" begin
    start_position = GoPosition(N;
        board=TEST_BOARD,
        n = 0,
        komi = 6.5,
        caps =(1, 2),
        ko = nothing,
        recent = Vector{PlayerMove}(),
        to_play = env.colors["BLACK"]
    )

    expected_board = load_board("""
        .XX....OO
        X........
    """ * repeat(EMPTY_ROW, 7), N)

    expected_position = GoPosition(N;
        board = expected_board,
        n = 1,
        komi = 6.5,
        caps = (1, 2),
        ko = nothing,
        recent=[PlayerMove(env.colors["BLACK"], from_kgs("C9", N))],
        to_play = env.colors["WHITE"]
    )
    actual_position = play_move!(start_position, from_kgs("C9", N))
    @test assertEqualPositions(actual_position, expected_position)

    expected_board2 = load_board("""
        .XX....OO
        X.......O
    """ * repeat(EMPTY_ROW, 7), N)

    expected_position2 = GoPosition(N;
        board = expected_board2,
        n = 2,
        komi = 6.5,
        caps = (1, 2),
        ko = nothing,
        recent = [PlayerMove(env.colors["BLACK"], from_kgs("C9", N)), PlayerMove(env.colors["WHITE"], from_kgs("J8", N))],
        to_play = env.colors["BLACK"]
    )

    actual_position2 = play_move!(actual_position, from_kgs("J8", N))
    @test assertEqualPositions(actual_position2, expected_position2)
  end

  @testset "move_with_capture" begin
    start_board = load_board(repeat(EMPTY_ROW, 5) * """
        XXXX.....
        XOOX.....
        O.OX.....
        OOXX.....
    """, N)

    start_position = GoPosition(N;
        board = start_board,
        n = 0,
        komi = 6.5,
        caps = (1, 2),
        ko = nothing,
        recent = Vector{PlayerMove}(),
        to_play = env.colors["BLACK"]
    )
    expected_board = load_board(repeat(EMPTY_ROW, 5) * """
        XXXX.....
        X..X.....
        .X.X.....
        ..XX.....
    """, N)

    expected_position = GoPosition(N;
        board = expected_board,
        n = 1,
        komi = 6.5,
        caps = (7, 2),
        ko = nothing,
        recent = Vector{PlayerMove}([PlayerMove(env.colors["BLACK"], from_kgs("B2", N))]),
        to_play = env.colors["WHITE"]
    )
    actual_position = play_move!(start_position, from_kgs("B2", N))
    @test assertEqualPositions(actual_position, expected_position)
  end

  @testset "ko_move" begin
    start_board = load_board("""
        .OX......
        OX.......
    """ * repeat(EMPTY_ROW, 7), N)

    start_position = GoPosition(N;
        board = start_board,
        n = 0,
        komi = 6.5,
        caps = (1, 2),
        ko = nothing,
        recent = Vector{PlayerMove}(),
        to_play = env.colors["BLACK"]
    )
    expected_board = load_board("""
        X.X......
        OX.......
    """ * repeat(EMPTY_ROW, 7), N)
    expected_position = GoPosition(N;
        board = expected_board,
        n = 1,
        komi = 6.5,
        caps = (2, 2),
        ko = from_kgs("B9", N),
        recent = Vector{PlayerMove}([PlayerMove(env.colors["BLACK"], from_kgs("A9", N))]),
        to_play = env.colors["WHITE"]
    )
    actual_position = play_move!(start_position, from_kgs("A9", N))
    @test assertEqualPositions(actual_position, expected_position)

    # Check that retaking ko is illegal until two intervening moves
    @test_throws IllegalMove play_move!(actual_position, from_kgs("B9", N))
    pass_twice = pass_move!(pass_move!(actual_position))
    ko_delayed_retake = play_move!(pass_twice, from_kgs("B9", N))
    expected_position = GoPosition(N;
        board = start_board,
        n = 4,
        komi = 6.5,
        caps = (2, 3),
        ko = from_kgs("A9", N),
        recent = Vector{PlayerMove}([
            PlayerMove(env.colors["BLACK"], from_kgs("A9", N)),
            PlayerMove(env.colors["WHITE"], nothing),
            PlayerMove(env.colors["BLACK"], nothing),
            PlayerMove(env.colors["WHITE"], from_kgs("B9", N))]),
        to_play = env.colors["BLACK"]
        )

    @test assertEqualPositions(ko_delayed_retake, expected_position)
  end

  @testset "is_game_over" begin
    root = GoPosition(N)
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
    """, N)
    position = GoPosition(N;
        board = board,
        n = 54,
        komi = 6.5,
        caps = (2, 5),
        ko = nothing,
        recent = Vector{PlayerMove}(),
        to_play = env.colors["BLACK"]
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
      """, N)

    position = GoPosition(N;
        board = board,
        n = 55,
        komi = 6.5,
        caps = (2, 5),
        ko = nothing,
        recent = Vector{PlayerMove}(),
        to_play = env.colors["WHITE"]
    )
    expected_score = 2.5
    @test score(position) == expected_score
  end
end
