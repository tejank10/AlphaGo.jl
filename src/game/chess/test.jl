# test.jl

# test the memory allocation ideas

include("Zobrist.jl")
include("constants.jl")
include("util.jl")
include("move.jl")
include("movelist.jl")


function test_fast()
    ml = Movelist()

    for j in 1:MAX_MOVES_PER_GAME, k in 1:MAX_MOVES_PER_TURN
        ml.moves[j][k] = Move(BLACK, ROOK, UInt64(999999999), UInt64(999999999))
    end

    #@show ml
end

function test_slower()
    ml = Movelist()

    #for i in 1:10000, j in 1:MAX_MOVES_PER_GAME, k in 1:MAX_MOVES_PER_TURN
    for j in 1:MAX_MOVES_PER_GAME, k in 1:MAX_MOVES_PER_TURN
        #ml.moves[j][k] = Move(WHITE, QUEEN, UInt64(11111), UInt64(11111))
        ml.moves[j][k].color_moving = WHITE
        ml.moves[j][k].piece_moving = QUEEN
        ml.moves[j][k].sqr_src = UInt64(11111)
        ml.moves[j][k].sqr_dest = UInt64(11111)
    end
    #@show ml
end


test_fast()
test_fast()

test_slower()
test_slower()

@time test_slower()
@time test_fast()
