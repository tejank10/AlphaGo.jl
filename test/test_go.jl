using AlphaGo.go
using AlphaGo.go: from_kgs, Position, PlayerMove, BLACK, WHITE, EMPTY
using Base.Test

include("test_utils.jl")

go.set_board_size(9)

pc_set(string) = Set(map(from_kgs, split(string)))

@testset "go" begin
  EMPTY_ROW = repeat(".", AlphaGo.go.N) * '\n'
  TEST_BOARD = load_board("""
                          .X.....OO
                          X........
                          """ * repeat(EMPTY_ROW, 7))
    @testset "load_board" begin
    @test assertEqualArray(go.EMPTY_BOARD, zeros(go.N, go.N))
    @test assertEqualArray(go.EMPTY_BOARD, load_board(repeat(". \n", go.N ^ 2)))
  end

  @testset "parsing" begin
    @test from_kgs("A9") == (1, 1)
    @test go.from_sgf("aa") == (1, 1)
    @test from_kgs("A3") == (7, 1)
    @test go.from_sgf("ac") == (3, 1)
    @test from_kgs("D4") == go.from_sgf("df")
  end

  @testset "neighbors" begin
    corner = from_kgs("A1")
    neighbors = [go.EMPTY_BOARD[c...] for c in go.NEIGHBORS[corner...]]
    @test length(neighbors) == 2

    side = from_kgs("A2")
    side_neighbors = [go.EMPTY_BOARD[c...] for c in go.NEIGHBORS[side...]]
    @test length(side_neighbors) == 3
  end

  @testset "is_koish" begin
    @test go.is_koish(TEST_BOARD, from_kgs("A9")) == BLACK
    @test go.is_koish(TEST_BOARD, from_kgs("B8")) == nothing
    @test go.is_koish(TEST_BOARD, from_kgs("B9")) == nothing
    @test go.is_koish(TEST_BOARD, from_kgs("E5")) == nothing
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
          """)
    B_eyes = pc_set("A2 A9 B8 J7 H8")
    W_eyes = pc_set("H2 J1 J3")
    not_eyes = pc_set("B3 E5")
    for be in B_eyes
      @test go.is_eyeish(board, be) == BLACK ? true : throw(AssertionError(string(be)))
    end
    for we in W_eyes
      @test go.is_eyeish(board, we) == WHITE ? true : throw(AssertionError(string(we)))
    end
    for ne in not_eyes
      @test go.is_eyeish(board, ne) == nothing ? true : throw(AssertionError(string(ne)))
    end
  end
  @testset "lib_tracker_init" begin
    board = load_board("X........" * repeat(EMPTY_ROW, 8))

    lib_tracker = go.from_board(board)
    @test length(lib_tracker.groups) == 1
    @test lib_tracker.group_index[from_kgs("A9")...] != go.MISSING_GROUP_ID
    @test lib_tracker.liberty_cache[from_kgs("A9")...] == 2
    sole_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("A9")...]]
    @test sole_group.stones == pc_set("A9")
    @test sole_group.liberties == pc_set("B9 A8")
    @test sole_group.color == BLACK
  end

  @testset "place_stone" begin
    board = load_board("X........" * repeat(EMPTY_ROW, 8))
    lib_tracker = go.from_board(board)
    go.add_stone!(lib_tracker, BLACK, from_kgs("B9"))
    @test length(lib_tracker.groups) == 1
    @test lib_tracker.group_index[from_kgs("A9")...] != go.MISSING_GROUP_ID
    @test lib_tracker.liberty_cache[from_kgs("A9")...] == 3
    @test lib_tracker.liberty_cache[from_kgs("B9")...] == 3
    sole_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("A9")...]]
    @test sole_group.stones == pc_set("A9 B9")
    @test sole_group.liberties == pc_set("C9 A8 B8")
    @test sole_group.color == BLACK
  end

  @testset "place_stone_opposite_color" begin
    board = load_board("X........" * repeat(EMPTY_ROW, 8))
    lib_tracker = go.from_board(board)
    go.add_stone!(lib_tracker, WHITE, from_kgs("B9"))
    @test length(lib_tracker.groups) == 2
    @test lib_tracker.group_index[from_kgs("A9")...] != go.MISSING_GROUP_ID
    @test lib_tracker.group_index[from_kgs("B9")...] != go.MISSING_GROUP_ID
    @test lib_tracker.liberty_cache[from_kgs("A9")...] == 1
    @test lib_tracker.liberty_cache[from_kgs("B9")...] == 2
    black_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("A9")...]]
    white_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("B9")...]]
    @test black_group.stones == pc_set("A9")
    @test black_group.liberties == pc_set("A8")
    @test black_group.color == BLACK
    @test white_group.stones == pc_set("B9")
    @test white_group.liberties == pc_set("C9 B8")
    @test white_group.color == WHITE
  end

  @testset "merge_multiple_groups" begin
    board = load_board("""
        .X.......
        X.X......
        .X.......
    """ * repeat(EMPTY_ROW, 6))
    lib_tracker = go.from_board(board)
    go.add_stone!(lib_tracker, BLACK, from_kgs("B8"))
    @test length(lib_tracker.groups) == 1
    @test lib_tracker.group_index[from_kgs("B8")...] != go.MISSING_GROUP_ID
    sole_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("B8")...]]
    @test sole_group.stones == pc_set("B9 A8 B8 C8 B7")
    @test sole_group.liberties == pc_set("A9 C9 D8 A7 C7 B6")
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
    """ * repeat(EMPTY_ROW, 6))
    lib_tracker = go.from_board(board)
    captured = go.add_stone!(lib_tracker, BLACK, from_kgs("C8"))
    @test length(lib_tracker.groups) == 4
    @test lib_tracker.group_index[from_kgs("B8")...] == go.MISSING_GROUP_ID
    @test captured == pc_set("B8")
  end

  @testset "capture_many" begin
    board = load_board("""
        .XX......
        XOO......
        .XX......
    """ * repeat(EMPTY_ROW, 6))
    lib_tracker = go.from_board(board)
    captured = go.add_stone!(lib_tracker, BLACK, from_kgs("D8"))
    @test length(lib_tracker.groups) == 4
    @test lib_tracker.group_index[from_kgs("B8")...] == go.MISSING_GROUP_ID
    @test captured == pc_set("B8 C8")

    left_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("A8")...]]
    @test left_group.stones == pc_set("A8")
    @test left_group.liberties == pc_set("A9 B8 A7")

    right_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("D8")...]]
    @test right_group.stones == pc_set("D8")
    @test right_group.liberties == pc_set("D9 C8 E8 D7")

    top_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("B9")...]]
    @test top_group.stones == pc_set("B9 C9")
    @test top_group.liberties == pc_set("A9 D9 B8 C8")

    bottom_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("B7")...]]
    @test bottom_group.stones == pc_set("B7 C7")
    @test bottom_group.liberties == pc_set("B8 C8 A7 D7 B6 C6")

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
    """ * repeat(EMPTY_ROW, 6))
    lib_tracker = go.from_board(board)
    captured = go.add_stone!(lib_tracker, BLACK, from_kgs("A9"))
    @test length(lib_tracker.groups) == 2
    @test captured == pc_set("B9 A8")

    corner_stone = lib_tracker.groups[lib_tracker.group_index[from_kgs("A9")...]]
    @test corner_stone.stones == pc_set("A9")
    @test corner_stone.liberties == pc_set("B9 A8")

    surrounding_stones = lib_tracker.groups[lib_tracker.group_index[from_kgs("C9")...]]
    @test surrounding_stones.stones == pc_set("C9 B8 C8 A7 B7")
    @test surrounding_stones.liberties == pc_set("B9 D9 A8 D8 C7 A6 B6")

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
    """ * repeat(EMPTY_ROW, 7))

    lib_tracker = go.from_board(board)
    captured = go.add_stone!(lib_tracker, BLACK, from_kgs("B8"))
    @test length(lib_tracker.groups) == 1
    sole_group_id = lib_tracker.group_index[from_kgs("A9")...]
    sole_group = lib_tracker.groups[sole_group_id]
    @test sole_group.stones == pc_set("A9 B9 A8 B8")
    @test sole_group.liberties == pc_set("C9 C8 A7 B7")
    @test captured == Set()
  end

  @testset "same_opponent_group_neighboring_twice" begin
    board = load_board("""
        XX.......
        X........
    """ * repeat(EMPTY_ROW, 7))

    lib_tracker = go.from_board(board)
    captured = go.add_stone!(lib_tracker, WHITE, from_kgs("B8"))
    @test length(lib_tracker.groups) == 2
    black_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("A9")...]]
    @test black_group.stones == pc_set("A9 B9 A8")
    @test black_group.liberties == pc_set("C9 A7")

    white_group = lib_tracker.groups[lib_tracker.group_index[from_kgs("B8")...]]
    @test white_group.stones == pc_set("B8")
    @test white_group.liberties == pc_set("C8 B7")

    @test captured == Set()
  end

  @testset "passing" begin
    start_position = Position(
        board = TEST_BOARD,
        n = 0,
        komi = 6.5,
        caps = (1, 2),
        ko = PlayerMove(from_kgs("A1")...),
        recent = Vector{PlayerMove}(),
        to_play = BLACK
    )
    expected_position = Position(
        board = TEST_BOARD,
        n = 1,
        komi = 6.5,
        caps = (1, 2),
        ko = nothing,
        recent = [PlayerMove(BLACK, nothing)],
        to_play = WHITE
    )
    pass_position = go.pass_move!(start_position)
    @test assertEqualPositions(pass_position, expected_position)
  end

  @testset "flipturn" begin
    start_position = Position(
        board = TEST_BOARD,
        n = 0,
        komi = 6.5,
        caps = (1, 2),
        ko = PlayerMove(from_kgs("A1")...),
        recent = Vector{PlayerMove}(),
        to_play = BLACK
    )
    expected_position = Position(
        board = TEST_BOARD,
        n = 0,
        komi = 6.5,
        caps = (1, 2),
        ko = nothing,
        recent = Vector{PlayerMove}(),
        to_play = WHITE
    )
    flip_position = go.flip_playerturn!(start_position)
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
    """)
    position = Position(
        board = board,
        to_play = BLACK
    )
    suicidal_moves = pc_set("E9 H5")
    nonsuicidal_moves = pc_set("B5 J1 A9")
    for move in suicidal_moves
      @test position.board[move...] == EMPTY #sanity check my coordinate input
      @test go.is_move_suicidal(position, move) ? true : throw(AssertionError(string(move)))
    end
    for move in nonsuicidal_moves
      @test position.board[move...] == EMPTY # sanity check my coordinate input
      @test !go.is_move_suicidal(position, move) ? true : throw(AssertionError(string(move)))
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
    """)
    position = Position(
        board = board,
        to_play = BLACK)
    illegal_moves = pc_set("A9 E9 J9")
    legal_moves = pc_set("A4 G1 J1 H7")
    for move in illegal_moves
      @test !go.is_move_legal(position, move)
    end
    for move in legal_moves
      @test go.is_move_legal(position, move)
    end
    # check that the bulk legal test agrees with move-by-move illegal test.
    bulk_legality = go.all_legal_moves(position)
    for (i, bulk_legal) in enumerate(bulk_legality)
      @test go.is_move_legal(position, go.from_flat(i)) == bulk_legal
    end
    # flip the colors and check that everything is still (il)legal
    position = Position(board = -board, to_play = WHITE)
    for move in illegal_moves
      @test !go.is_move_legal(position, move)
    end
    for move in legal_moves
      @test go.is_move_legal(position, move)
    end
    bulk_legality = go.all_legal_moves(position)
    for (i, bulk_legal) in enumerate(bulk_legality)
      @test go.is_move_legal(position, go.from_flat(i)) == bulk_legal
    end
  end

  @testset "move" begin
    start_position = Position(
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
    """ * repeat(EMPTY_ROW, 7))
    expected_position = Position(
        board = expected_board,
        n = 1,
        komi = 6.5,
        caps = (1, 2),
        ko = nothing,
        recent=[PlayerMove(BLACK, from_kgs("C9"))],
        to_play = WHITE
    )
    actual_position = go.play_move!(start_position, from_kgs("C9"))
    @test assertEqualPositions(actual_position, expected_position)

    expected_board2 = load_board("""
        .XX....OO
        X.......O
    """ * repeat(EMPTY_ROW, 7))
    expected_position2 = Position(
        board = expected_board2,
        n = 2,
        komi = 6.5,
        caps = (1, 2),
        ko = nothing,
        recent = [PlayerMove(BLACK, from_kgs("C9")), PlayerMove(WHITE, from_kgs("J8"))],
        to_play = BLACK
    )
    actual_position2 = go.play_move!(actual_position, from_kgs("J8"))
    @test assertEqualPositions(actual_position2, expected_position2)
  end

  @testset "move_with_capture" begin
    start_board = load_board(repeat(EMPTY_ROW, 5) * """
        XXXX.....
        XOOX.....
        O.OX.....
        OOXX.....
    """)
    start_position = Position(
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
    """)
    expected_position = Position(
        board = expected_board,
        n = 1,
        komi = 6.5,
        caps = (7, 2),
        ko = nothing,
        recent = Vector{PlayerMove}([PlayerMove(BLACK, from_kgs("B2"))]),
        to_play = WHITE
    )
    actual_position = go.play_move!(start_position, from_kgs("B2"))
    @test assertEqualPositions(actual_position, expected_position)
  end

  @testset "ko_move" begin
    start_board = load_board("""
        .OX......
        OX.......
    """ * repeat(EMPTY_ROW, 7))
    start_position = Position(
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
    """ * repeat(EMPTY_ROW, 7))
    expected_position = Position(
        board = expected_board,
        n = 1,
        komi = 6.5,
        caps = (2, 2),
        ko = from_kgs("B9"),
        recent = Vector{PlayerMove}([PlayerMove(BLACK, from_kgs("A9"))]),
        to_play = WHITE
    )
    actual_position = go.play_move!(start_position, from_kgs("A9"))
    @test assertEqualPositions(actual_position, expected_position)

    # Check that retaking ko is illegal until two intervening moves
    @test_throws go.IllegalMove go.play_move!(actual_position, from_kgs("B9"))
    pass_twice = go.pass_move!(go.pass_move!(actual_position))
    ko_delayed_retake = go.play_move!(pass_twice, from_kgs("B9"))
    expected_position = Position(
        board = start_board,
        n = 4,
        komi = 6.5,
        caps = (2, 3),
        ko = from_kgs("A9"),
        recent = Vector{PlayerMove}([
            PlayerMove(BLACK, from_kgs("A9")),
            PlayerMove(WHITE, nothing),
            PlayerMove(BLACK, nothing),
            PlayerMove(WHITE, from_kgs("B9"))]),
        to_play = BLACK
        )

    @test assertEqualPositions(ko_delayed_retake, expected_position)
  end

  @testset "is_game_over" begin
    root = Position()
    @test !root.done
    first_pass = go.play_move!(root, nothing)
    @test !first_pass.done
    second_pass = go.play_move!(first_pass, nothing)
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
    """)
    position = Position(
        board = board,
        n = 54,
        komi = 6.5,
        caps = (2, 5),
        ko = nothing,
        recent = Vector{PlayerMove}(),
        to_play = BLACK
    )
    expected_score = 1.5
    @test go.score(position) == expected_score

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
      """)
    position = Position(
        board = board,
        n = 55,
        komi = 6.5,
        caps = (2, 5),
        ko = nothing,
        recent = Vector{PlayerMove}(),
        to_play = WHITE
    )
    expected_score = 2.5
    @test go.score(position) == expected_score
  end
end
