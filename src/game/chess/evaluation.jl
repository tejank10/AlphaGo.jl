# evaluation.jl

const pawn_square_table = [
     0,  0,  0,  0,  0,  0,  0,  0,
     5, 10, 10,-20,-20, 10, 10,  5,
     5, -5,-10,  0,  0,-10, -5,  5,
     0,  0,  0, 20, 20,  0,  0,  0,
     5,  5, 10, 25, 25, 10,  5,  5,
    10, 10, 20, 30, 30, 20, 10, 10,
    50, 50, 50, 50, 50, 50, 50, 50,
     0,  0,  0,  0,  0,  0,  0,  0
     ]

const knight_square_table = [
    -50,-40,-30,-30,-30,-30,-40,-50,
    -40,-20,  0,  5,  5,  0,-20,-40,
    -30,  5, 10, 15, 15, 10,  5,-30,
    -30,  0, 15, 20, 20, 15,  0,-30,
    -30,  5, 15, 20, 20, 15,  5,-30,
    -30,  0, 10, 15, 15, 10,  0,-30,
    -40,-20,  0,  0,  0,  0,-20,-40,
    -50,-40,-30,-30,-30,-30,-40,-50
    ]

const bishop_square_table = [
    -20,-10,-10,-10,-10,-10,-10,-20,
    -10,  5,  0,  0,  0,  0,  5,-10,
    -10, 10, 10, 10, 10, 10, 10,-10,
    -10,  0, 10, 10, 10, 10,  0,-10,
    -10,  5,  5, 10, 10,  5,  5,-10,
    -10,  0,  5, 10, 10,  5,  0,-10,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -20,-10,-10,-10,-10,-10,-10,-20
    ]

const rook_square_table = [
     0,  0,  0,  5,  5,  0,  0,  0,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
     5, 10, 10, 10, 10, 10, 10,  5,
     0,  0,  0,  0,  0,  0,  0,  0
    ]

const queen_square_table = [
    -20,-10,-10, -5, -5,-10,-10,-20,
    -10,  0,  5,  0,  0,  0,  0,-10,
    -10,  5,  5,  5,  5,  5,  0,-10,
      0,  0,  5,  5,  5,  5,  0, -5,
     -5,  0,  5,  5,  5,  5,  0, -5,
    -10,  0,  5,  5,  5,  5,  0,-10,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -20,-10,-10, -5, -5,-10,-10,-20
    ]

const king_square_table = [
     20, 30, 10,  0,  0, 10, 30, 20,
     20, 20,  0,  0,  0,  0, 20, 20,
    -10,-20,-20,-20,-20,-20,-20,-10,
    -20,-30,-30,-40,-40,-30,-30,-20,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30
    ]

const KING_SCORE =   20.0
const QUEEN_SCORE =   9.0
const ROOK_SCORE =    5.0
const BISHOP_SCORE =  3.3
const KNIGHT_SCORE =  3.2
const PAWN_SCORE =    1.0
const DRAW_SCORE =    0.0
const MATE_SCORE = -100.0

"Returns a primitive evaluation of the material and position in centipawns"
function evaluate(b::Board)
    # simplified evaluation as per Tomasz Michniewski
    # https://chessprogramming.wikispaces.com/Simplified+evaluation+function
    material_value =
       KING_SCORE   * count(b.white_pieces & b.kings)   +
       QUEEN_SCORE  * count(b.white_pieces & b.queens)  +
       ROOK_SCORE   * count(b.white_pieces & b.rooks)   +
       BISHOP_SCORE * count(b.white_pieces & b.bishops) +
       KNIGHT_SCORE * count(b.white_pieces & b.knights) +
       PAWN_SCORE   * count(b.white_pieces & b.pawns) -
      (KING_SCORE   * count(b.black_pieces & b.kings)   +
       QUEEN_SCORE  * count(b.black_pieces & b.queens)  +
       ROOK_SCORE   * count(b.black_pieces & b.rooks)   +
       BISHOP_SCORE * count(b.black_pieces & b.bishops) +
       KNIGHT_SCORE * count(b.black_pieces & b.knights) +
       PAWN_SCORE   * count(b.black_pieces & b.pawns))

    position_value = 0
    for square_index in 1:64
        sqr = UInt64(1) << (square_index-1)

        i = square_index
        m = 1
        if b.black_pieces & sqr > 0
            i = 65-square_index
            m = -1
        end

        if b.pawns & sqr > 0        position_value += m * pawn_square_table[i]
        elseif b.rooks & sqr > 0    position_value += m * rook_square_table[i]
        elseif b.bishops & sqr > 0  position_value += m * bishop_square_table[i]
        elseif b.knights & sqr > 0  position_value += m * knight_square_table[i]
        elseif b.queens & sqr > 0   position_value += m * queen_square_table[i]
        elseif b.kings & sqr > 0    position_value += m * king_square_table[i]
        end
    end

    material_value + (position_value/100)
end
