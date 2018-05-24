include("../src/board.jl")
include("../src/utils.jl")
include("test_utils.jl")
using Base.Test: @test, @test_throws
set_board_size(9)

EMPTY_ROW = repeat(".", N) * '\n'
TEST_BOARD = load_board("""
                        .X.....OO
                        X........
                        """ * repeat(EMPTY_ROW, 7))

function pc_set(string)
  return Set(map(parse_kgs_coords, split(string)))
end

function test_load_board()
  @test assertEqualArray(EMPTY_BOARD, zeros(N, N))
  @test assertEqualArray(EMPTY_BOARD, load_board(repeat(". \n", N ^ 2)))
end

function test_parsing()
  @test parse_kgs_coords("A9") == (1, 1)
  @test parse_sgf_coords("aa") == (1, 1)
  @test parse_kgs_coords("A3") == (7, 1)
  @test parse_sgf_coords("ac") == (3, 1)
  @test parse_kgs_coords("D4") == parse_sgf_coords("df")
end

function test_neighbors()
  corner = parse_kgs_coords("A1")
  neighbors = [EMPTY_BOARD[c...] for c in NEIGHBORS[corner...]]
  @test length(neighbors) == 2

  side = parse_kgs_coords("A2")
  side_neighbors = [EMPTY_BOARD[c...] for c in NEIGHBORS[side...]]
  @test length(side_neighbors) == 3
end

function test_is_koish()
  @test is_koish(TEST_BOARD, parse_kgs_coords("A9")) == BLACK
  @test is_koish(TEST_BOARD, parse_kgs_coords("B8")) == nothing
  @test is_koish(TEST_BOARD, parse_kgs_coords("B9")) == nothing
  @test is_koish(TEST_BOARD, parse_kgs_coords("E5")) == nothing
end

function test_is_eyeish()
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
    is_eyeish(board, be) == BLACK ? nothing : throw(AssertionError(string(be)))
  end
  for we in W_eyes
    is_eyeish(board, we) == WHITE ? nothing : throw(AssertionError(string(we)))
  end
  for ne in not_eyes
    is_eyeish(board, ne) == nothing ? nothing : throw(AssertionError(string(ne)))
  end
end

function test_lib_tracker_init()
  board = load_board("X........" * repeat(EMPTY_ROW, 8))

  lib_tracker = from_board(board)
  @test length(lib_tracker.groups) == 1
  @test lib_tracker.group_index[parse_kgs_coords("A9")...] != MISSING_GROUP_ID
  @test lib_tracker.liberty_cache[parse_kgs_coords("A9")...] == 2
  sole_group = lib_tracker.groups[lib_tracker.group_index[parse_kgs_coords("A9")...]]
  @test sole_group.stones == pc_set("A9")
  @test sole_group.liberties == pc_set("B9 A8")
  @test sole_group.color == BLACK
end

function test_place_stone()
  board = load_board("X........" * repeat(EMPTY_ROW, 8))
  lib_tracker = from_board(board)
  add_stone!(lib_tracker, BLACK, parse_kgs_coords("B9"))
  @test length(lib_tracker.groups) == 1
  @test lib_tracker.group_index[parse_kgs_coords("A9")...] != MISSING_GROUP_ID
  @test lib_tracker.liberty_cache[parse_kgs_coords("A9")...] == 3
  @test lib_tracker.liberty_cache[parse_kgs_coords("B9")...] == 3
  sole_group = lib_tracker.groups[lib_tracker.group_index[parse_kgs_coords("A9")...]]
  @test sole_group.stones == pc_set("A9 B9")
  @test sole_group.liberties == pc_set("C9 A8 B8")
  @test sole_group.color == BLACK
end

function test_place_stone_opposite_color()
  board = load_board("X........" * repeat(EMPTY_ROW, 8))
  lib_tracker = from_board(board)
  add_stone!(lib_tracker, WHITE, parse_kgs_coords("B9"))
  @test length(lib_tracker.groups) == 2
  @test lib_tracker.group_index[parse_kgs_coords("A9")...] != MISSING_GROUP_ID
  @test lib_tracker.group_index[parse_kgs_coords("B9")...] != MISSING_GROUP_ID
  @test lib_tracker.liberty_cache[parse_kgs_coords("A9")...] == 1
  @test lib_tracker.liberty_cache[parse_kgs_coords("B9")...] == 2
  black_group = lib_tracker.groups[lib_tracker.group_index[parse_kgs_coords("A9")...]]
  white_group = lib_tracker.groups[lib_tracker.group_index[parse_kgs_coords("B9")...]]
  @test black_group.stones == pc_set("A9")
  @test black_group.liberties == pc_set("A8")
  @test black_group.color == BLACK
  @test white_group.stones == pc_set("B9")
  @test white_group.liberties == pc_set("C9 B8")
  @test white_group.color == WHITE
end

function test_merge_multiple_groups()
  board = load_board("""
      .X.......
      X.X......
      .X.......
  """ * repeat(EMPTY_ROW, 6))
  lib_tracker = from_board(board)
  add_stone!(lib_tracker, BLACK, parse_kgs_coords("B8"))
  @test length(lib_tracker.groups) == 1
  @test lib_tracker.group_index[parse_kgs_coords("B8")...] != MISSING_GROUP_ID
  sole_group = lib_tracker.groups[lib_tracker.group_index[parse_kgs_coords("B8")...]]
  @test sole_group.stones == pc_set("B9 A8 B8 C8 B7")
  @test sole_group.liberties == pc_set("A9 C9 D8 A7 C7 B6")
  @test sole_group.color == BLACK

  liberty_cache = lib_tracker.liberty_cache
  for stone in sole_group.stones
    liberty_cache[stone...] == 6 ? nothing : throw(AssertionError(string(stone)))
  end
end

function test_capture_stone()
  board = load_board("""
      .X.......
      XO.......
      .X.......
  """ * repeat(EMPTY_ROW, 6))
  lib_tracker = from_board(board)
  captured = add_stone!(lib_tracker, BLACK, parse_kgs_coords("C8"))
  @test length(lib_tracker.groups) == 4
  @test lib_tracker.group_index[parse_kgs_coords("B8")...] == MISSING_GROUP_ID
  @test captured == pc_set("B8")
end

function test_capture_many()
  board = load_board("""
      .XX......
      XOO......
      .XX......
  """ * repeat(EMPTY_ROW, 6))
  lib_tracker = from_board(board)
  captured = add_stone!(lib_tracker, BLACK, parse_kgs_coords("D8"))
  @test length(lib_tracker.groups) == 4
  @test lib_tracker.group_index[parse_kgs_coords("B8")...] == MISSING_GROUP_ID
  @test captured == pc_set("B8 C8")

  left_group = lib_tracker.groups[lib_tracker.group_index[parse_kgs_coords("A8")...]]
  @test left_group.stones == pc_set("A8")
  @test left_group.liberties == pc_set("A9 B8 A7")

  right_group = lib_tracker.groups[lib_tracker.group_index[parse_kgs_coords("D8")...]]
  @test right_group.stones == pc_set("D8")
  @test right_group.liberties == pc_set("D9 C8 E8 D7")

  top_group = lib_tracker.groups[lib_tracker.group_index[parse_kgs_coords("B9")...]]
  @test top_group.stones == pc_set("B9 C9")
  @test top_group.liberties == pc_set("A9 D9 B8 C8")

  bottom_group = lib_tracker.groups[lib_tracker.group_index[parse_kgs_coords("B7")...]]
  @test bottom_group.stones == pc_set("B7 C7")
  @test bottom_group.liberties == pc_set("B8 C8 A7 D7 B6 C6")

  liberty_cache = lib_tracker.liberty_cache
  for stone in top_group.stones
    liberty_cache[stone...] == 4 ? nothing : throw(AssertionError(string(stone)))
  end
  for stone in left_group.stones
    liberty_cache[stone...] == 3 ? nothing: throw(AssertionError(string(stone)))
  end
  for stone in right_group.stones
    liberty_cache[stone...] == 4 ? nothing : throw(AssertionError(string(stone)))
  end
  for stone in bottom_group.stones
    liberty_cache[stone...] == 6 ? nothing : throw(AssertionError(string(stone)))
  end
  for stone in captured
    liberty_cache[stone...] == 0 ? nothing : throw(AssertionError(string(stone)))
  end
end

function test_capture_multiple_groups()
  board = load_board("""
      .OX......
      OXX......
      XX.......
  """ * repeat(EMPTY_ROW, 6))
  lib_tracker = from_board(board)
  captured = add_stone!(lib_tracker, BLACK, parse_kgs_coords("A9"))
  @test length(lib_tracker.groups) == 2
  @test captured == pc_set("B9 A8")

  corner_stone = lib_tracker.groups[lib_tracker.group_index[parse_kgs_coords("A9")...]]
  @test corner_stone.stones == pc_set("A9")
  @test corner_stone.liberties == pc_set("B9 A8")

  surrounding_stones = lib_tracker.groups[lib_tracker.group_index[parse_kgs_coords("C9")...]]
  @test surrounding_stones.stones == pc_set("C9 B8 C8 A7 B7")
  @test surrounding_stones.liberties == pc_set("B9 D9 A8 D8 C7 A6 B6")

  liberty_cache = lib_tracker.liberty_cache
  for stone in corner_stone.stones
    liberty_cache[stone...] == 2 ? nothing : throw(AssertionError(string(stone)))
  end
  for stone in surrounding_stones.stones
    liberty_cache[stone...] == 7 ? nothing : throw(AssertionError(string(stone)))
  end
end

function test_same_friendly_group_neighboring_twice()
  board = load_board("""
      XX.......
      X........
  """ * repeat(EMPTY_ROW, 7))

  lib_tracker = from_board(board)
  captured = add_stone!(lib_tracker, BLACK, parse_kgs_coords("B8"))
  @test length(lib_tracker.groups) == 1
  sole_group_id = lib_tracker.group_index[parse_kgs_coords("A9")...]
  sole_group = lib_tracker.groups[sole_group_id]
  @test sole_group.stones == pc_set("A9 B9 A8 B8")
  @test sole_group.liberties == pc_set("C9 C8 A7 B7")
  @test captured == Set()
end

function test_same_opponent_group_neighboring_twice()
  board = load_board("""
      XX.......
      X........
  """ * repeat(EMPTY_ROW, 7))

  lib_tracker = from_board(board)
  captured = add_stone!(lib_tracker, WHITE, parse_kgs_coords("B8"))
  @test length(lib_tracker.groups) == 2
  black_group = lib_tracker.groups[lib_tracker.group_index[parse_kgs_coords("A9")...]]
  @test black_group.stones == pc_set("A9 B9 A8")
  @test black_group.liberties == pc_set("C9 A7")

  white_group = lib_tracker.groups[lib_tracker.group_index[parse_kgs_coords("B8")...]]
  @test white_group.stones == pc_set("B8")
  @test white_group.liberties == pc_set("C8 B7")

  @test captured == Set()
end

function test_passing()
  start_position = Position(
      board = TEST_BOARD,
      n = 0,
      komi = 6.5,
      caps = (1, 2),
      ko = PlayerMove(parse_kgs_coords("A1")...),
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
  pass_position = pass_move!(start_position)
  assertEqualPositions(pass_position, expected_position)
end

function test_flipturn()
  start_position = Position(
      board = TEST_BOARD,
      n = 0,
      komi = 6.5,
      caps = (1, 2),
      ko = PlayerMove(parse_kgs_coords("A1")...),
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
  flip_position = flip_playerturn!(start_position)
  assertEqualPositions(flip_position, expected_position)
end

function test_is_move_suicidal()
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
    is_move_suicidal(position, move) ? nothing : throw(AssertionError(string(move)))
  end
  for move in nonsuicidal_moves
    @test position.board[move...] == EMPTY # sanity check my coordinate input
    !is_move_suicidal(position, move) ? nothing : throw(AssertionError(string(move)))
  end
end

function test_legal_moves()
  board = load_board("""
      .XXXXXXXO
      XX.OOOOO.
      OOOOOOOOO
      XXXXXXXX.
      OOOOOOOOO
      XXXXXXXXX
      XXXXXXXXX
      XXXXXXXXX
      XXXXXXXX.
  """)
  position = Position(
      board = board,
      n = 0,
      komi = 6.5,
      caps = (0, 0),
      ko = parse_kgs_coords("J8"),
      recent = Vector{PlayerMove}(),
      to_play = BLACK
  )
  empty_spots = pc_set("A9 C8 J8 J6 J1")
  B_legal_moves = pc_set("A9 C8 J6")
  for move ∈ empty_spots
    if move ∉ B_legal_moves
      @test_throws IllegalMove play_move!(position, move)
    else
      play_move!(position, move)
    end
  end
  # pass should also be legal
  play_move!(position, nothing)

  pass_position = pass_move!(position)
  W_legal_moves = pc_set("C8 J8 J6 J1")
  for move ∈ empty_spots
    if move ∉ W_legal_moves
      @test_throws IllegalMove play_move!(pass_position, move)
    else
      play_move!(pass_position, move)
    end
  end
  # pass should also be legal
  play_move!(pass_position, nothing)
end

function test_move()
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
      recent=[PlayerMove(BLACK, parse_kgs_coords("C9"))],
      to_play = WHITE
  )
  actual_position = play_move!(start_position, parse_kgs_coords("C9"))
  assertEqualPositions(actual_position, expected_position)

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
      recent = [PlayerMove(BLACK, parse_kgs_coords("C9")), PlayerMove(WHITE, parse_kgs_coords("J8"))],
      to_play = BLACK
  )
  actual_position2 = play_move!(actual_position, parse_kgs_coords("J8"))
  assertEqualPositions(actual_position2, expected_position2)
end

function test_move_with_capture()
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
      recent = Vector{PlayerMove}([PlayerMove(BLACK, parse_kgs_coords("B2"))]),
      to_play = WHITE
  )
  actual_position = play_move!(start_position, parse_kgs_coords("B2"))
  assertEqualPositions(actual_position, expected_position)
end

function test_ko_move()
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
      ko = parse_kgs_coords("B9"),
      recent = Vector{PlayerMove}([PlayerMove(BLACK, parse_kgs_coords("A9"))]),
      to_play = WHITE
  )
  actual_position = play_move!(start_position, parse_kgs_coords("A9"))

  assertEqualPositions(actual_position, expected_position)

  # Check that retaking ko is illegal until two intervening moves
  @test_throws IllegalMove play_move!(actual_position, parse_kgs_coords("B9"))
  pass_twice = pass_move!(pass_move!(actual_position))
  ko_delayed_retake = play_move!(pass_twice, parse_kgs_coords("B9"))
  expected_position = Position(
      board = start_board,
      n = 4,
      komi = 6.5,
      caps = (2, 3),
      ko = parse_kgs_coords("A9"),
      recent = Vector{PlayerMove}([
          PlayerMove(BLACK, parse_kgs_coords("A9")),
          PlayerMove(WHITE, nothing),
          PlayerMove(BLACK, nothing),
          PlayerMove(WHITE, parse_kgs_coords("B9"))]),
      to_play = BLACK
      )
      assertEqualPositions(ko_delayed_retake, expected_position)
end

function test_scoring()
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
  @test score(position) == expected_score
end
