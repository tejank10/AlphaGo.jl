# Chess.jl

module Chess

# Why use Julia for a chess engine?
#
# advantages of Julia:
#  1 metaprogramming, ability to reduce repeated code by macros
#  2 mulitiple dispatch, ability to create functs distinguished by signature
#  3 designed for parallelism, multicore
#
#  4 ... at big picture level, experiment with larger ideas easily
#

const version = "Julia Chess, v0.55"
const author = "Alan Bahm"


include("Zobrist.jl")
include("constants.jl")
include("util.jl")
include("move.jl")
include("movelist.jl")
include("board.jl")
#include("position_original.jl")
include("position.jl")
include("evaluation.jl")
#include("search_original.jl")
include("search.jl")
#include("play_original.jl")
include("play.jl")
include("protocols/xboard.jl")
include("protocols/uci.jl")


if "-uci" ∈ ARGS
    # not yet supported...
    uci_loop()
elseif "-xboard" ∈ ARGS
    xboard_loop()
elseif "-repl" ∈ ARGS
    repl_loop()
end



function test_refactor()
    println()
    b = new_game()
    println()
    printbd(b)

    moves = generate_moves(b)
    move = moves[2]
    println(move)

    prior_castling_rights = b.castling_rights
    prior_last_move_pawn_double_push = b.last_move_pawn_double_push
    make_move!(b, move)

    unmake_move!(b, move, prior_castling_rights,
                          prior_last_move_pawn_double_push)

    printbd(b)
end

#test_refactor()

function test_movelist()
    b = new_game()

    m = generate_moves(b)
    println( b.game_movelist )

    r = rand(1:number_of_moves(b.game_movelist))
    make_move!(b, m[1])

    println( b.game_movelist )
    #m = generate_moves(b)
    #println( b.game_movelist )
end

test_movelist()

#export WHITE, BLACK
export KING, QUEEN, ROOK, BISHOP, KNIGHT, PAWN
export A, B, C, D, E, F, G, H
export square
export CASTLING_RIGHTS_ALL
export generate_moves, make_move!, unmake_move!
export number_of_moves
export Move, algebraic_format, long_algebraic_format
export Board, set!, new_game, new_game_960
export read_fen, write_fen, printbd
export play, random_play_both_sides, perft
export best_move_search, best_move_negamax, best_move_alphabeta

end
