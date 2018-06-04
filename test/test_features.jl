using AlphaGo: stone_features
using AlphaGo.go: Position, PlayerMove, BLACK, WHITE
using Base.Test

include("test_utils.jl")

@testset "features" begin
  EMPTY_ROW = repeat(".", AlphaGo.go.N) * '\n'
  TEST_BOARD = load_board("""
                          .X.....OO
                          X........
                          """ * repeat(EMPTY_ROW, 7))
  TEST_POSITION = Position(
      board = TEST_BOARD,
      n = 3,
      komi = 6.5,
      caps = (1, 2),
      ko = nothing,
      recent = [PlayerMove(BLACK, (1, 2)),
              PlayerMove(WHITE, (1, 9)),
              PlayerMove(BLACK, (2, 1))],
      to_play = BLACK);

  TEST_BOARD2 = load_board("""
                          .XOXXOO..
                          XO.OXOX..
                          XXO..X...
                          """ * repeat(EMPTY_ROW, 6))

  TEST_POSITION2 = Position(
      board = TEST_BOARD2,
      n = 0,
      komi = 6.5,
      caps = (0, 0),
      ko = nothing,
      recent = Vector{PlayerMove}(),
      to_play = BLACK);

  TEST_POSITION3 = Position();
  for coord in ((1, 1), (1, 2), (1, 3), (1, 4), (2, 2))
    go.play_move!(TEST_POSITION3, coord, mutate = true)
  end
  # resulting position should look like this:
  # X.XO.....
  # .X.......
  # .........

  @testset "stone_features" begin
    f = stone_features(TEST_POSITION3)
    @test TEST_POSITION3.to_play == WHITE
    @test size(f) == (9, 9, 16)
    @test assertEqualArray(f[:, :, 1], load_board("""
                                              ...X.....
                                              .........""" * repeat(EMPTY_ROW, 7)))

    @test assertEqualArray(f[:, :, 2], load_board("""
                                              X.X......
                                              .X.......""" * repeat(EMPTY_ROW, 7)))

    @test assertEqualArray(f[:, :, 3], load_board("""
                                              .X.X.....
                                              .........""" * repeat(EMPTY_ROW, 7)))

    @test assertEqualArray(f[:, :, 4], load_board("""
                                              X.X......
                                              .........""" * repeat(EMPTY_ROW, 7)))

    @test assertEqualArray(f[:, :, 5], load_board("""
                                              .X.......
                                              .........""" * repeat(EMPTY_ROW, 7)))

    @test assertEqualArray(f[:, :, 6], load_board("""
                                              X.X......
                                              .........""" * repeat(EMPTY_ROW, 7)))

    for i = 11:16
      @test assertEqualArray(f[:, :, i], zeros(go.N, go.N))
    end
  end
end
