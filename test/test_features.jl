include("../src/go.jl")
using go
include("../src/mcts.jl")
include("../src/mcts_play.jl")
include("test_utils.jl")
include("../src/features.jl")
using Base.Test: @test, @test_throws

go.set_board_size(9);
set_mcts_params()

EMPTY_ROW = repeat(".", go.N) * "\n"
TEST_BOARD = load_board("""
                        .X.....OO
                        X........
                        XXXXXXXXX
                        """ * repeat(EMPTY_ROW, 6))

TEST_POSITION = go.Position(
    board = TEST_BOARD,
    n = 3,
    komi = 6.5,
    caps = (1, 2),
    ko = nothing,
    recent = [go.PlayerMove(go.BLACK, (1, 2)),
            go.PlayerMove(go.WHITE, (1, 9)),
            go.PlayerMove(go.BLACK, (2, 1))],
    to_play = go.BLACK);

TEST_BOARD2 = load_board("""
                        .XOXXOO..
                        XO.OXOX..
                        XXO..X...
                        """ * repeat(EMPTY_ROW, 6))

TEST_POSITION2 = go.Position(
    board = TEST_BOARD2,
    n = 0,
    komi = 6.5,
    caps = (0, 0),
    ko = nothing,
    recent = Vector{go.PlayerMove}(),
    to_play = go.BLACK);

TEST_POSITION3 = go.Position();
for coord in ((1, 1), (1, 2), (1, 3), (1, 4), (2, 2))
  go.play_move!(TEST_POSITION3, coord, mutate = true)
end
# resulting position should look like this:
# X.XO.....
# .X.......
# .........

function test_stone_features()
  f = stone_features(TEST_POSITION3)
  @test TEST_POSITION3.to_play == go.WHITE
  @test size(f) == (9, 9, 16)
  assertEqualArray(f[:, :, 1], load_board("""
                                            ...X.....
                                            .........""" * repeat(EMPTY_ROW, 7)))

  assertEqualArray(f[:, :, 2], load_board("""
                                            X.X......
                                            .X.......""" * repeat(EMPTY_ROW, 7)))

  assertEqualArray(f[:, :, 3], load_board("""
                                            .X.X.....
                                            .........""" * repeat(EMPTY_ROW, 7)))

  assertEqualArray(f[:, :, 4], load_board("""
                                            X.X......
                                            .........""" * repeat(EMPTY_ROW, 7)))

  assertEqualArray(f[:, :, 5], load_board("""
                                            .X.......
                                            .........""" * repeat(EMPTY_ROW, 7)))

  assertEqualArray(f[:, :, 6], load_board("""
                                            X.X......
                                            .........""" * repeat(EMPTY_ROW, 7)))

  for i = 11:16
    assertEqualArray(f[:, :, i], zeros(go.N, go.N))
  end
end
