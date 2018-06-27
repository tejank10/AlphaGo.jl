# constants.jl

# Symbols for drawing chess board in REPL
#const CHARACTERS = ['k','q','r','b','n','p']
const CHARACTERS = ['♙','♘','♗','♖','♕','♔']
const PIECE_NAMES = ["pawn", "knight", "bishop", "rook", "queen", "king"]
const COLOR_NAMES = ["white", "black"]
const CHARACTER_SQUARE_ATTACKED = '•'
const CHARACTER_SQUARE_CAPTURE = 'x'  #'∘'
#const CHARACTER_SQUARE_EMPTY = '⋅', '–', '⋯', '_', ' ', '▓'
const CHARACTER_SQUARE_EMPTY = '.'
#const CHARACTER_CASTLING_AVAILABLE = "↔", "⇋", "⟷"
const CHARACTER_CASTLING_AVAILABLE = "⇔"
#const SMALL_NUMBERS = ['𝟣','𝟤','𝟥','𝟦','𝟧','𝟨','𝟩','𝟪']
const SMALL_NUMBERS = ['₁','₂','₃','₄','₅','₆','₇','₈']



const NONE = UInt8(0)

const PAWN = UInt8(1)
const KNIGHT = UInt8(2)
const BISHOP = UInt8(3)
const ROOK = UInt8(4)
const QUEEN = UInt8(5)
const KING = UInt8(6)

const WHITE = UInt8(1)
const BLACK = UInt8(2)
@inline function opposite_color(color::UInt8)  color==WHITE ? BLACK : WHITE  end

const A = UInt8(1)
const B = UInt8(2)
const C = UInt8(3)
const D = UInt8(4)
const E = UInt8(5)
const F = UInt8(6)
const G = UInt8(7)
const H = UInt8(8)

const CASTLING_NONE = UInt8(0)
const CASTLING_RIGHTS_WHITE_KINGSIDE = UInt8(1)
const CASTLING_RIGHTS_WHITE_QUEENSIDE = CASTLING_RIGHTS_WHITE_KINGSIDE << 1
const CASTLING_RIGHTS_BLACK_KINGSIDE = CASTLING_RIGHTS_WHITE_KINGSIDE << 2
const CASTLING_RIGHTS_BLACK_QUEENSIDE = CASTLING_RIGHTS_WHITE_KINGSIDE << 3
const CASTLING_RIGHTS_WHITE_ANYSIDE = CASTLING_RIGHTS_WHITE_KINGSIDE | CASTLING_RIGHTS_WHITE_QUEENSIDE
const CASTLING_RIGHTS_BLACK_ANYSIDE = CASTLING_RIGHTS_BLACK_KINGSIDE | CASTLING_RIGHTS_BLACK_QUEENSIDE
const CASTLING_RIGHTS_ALL = CASTLING_RIGHTS_WHITE_ANYSIDE | CASTLING_RIGHTS_BLACK_ANYSIDE

const FILE_A = 0x0101010101010101
const FILE_B = FILE_A << 1
const FILE_C = FILE_A << 2
const FILE_D = FILE_A << 3
const FILE_E = FILE_A << 4
const FILE_F = FILE_A << 5
const FILE_G = FILE_A << 6
const FILE_H = FILE_A << 7
const RANK_1 = 0x00000000000000FF
const RANK_2 = RANK_1 << (8*1)
const RANK_3 = RANK_1 << (8*2)
const RANK_4 = RANK_1 << (8*3)
const RANK_5 = RANK_1 << (8*4)
const RANK_6 = RANK_1 << (8*5)
const RANK_7 = RANK_1 << (8*6)
const RANK_8 = RANK_1 << (8*7)
const FILE_AB = FILE_A | FILE_B
const FILE_GH = FILE_G | FILE_H

const SQUARE_A1 = 0x0000000000000001
const SQUARE_B1 = SQUARE_A1 << 1
const SQUARE_C1 = SQUARE_A1 << 2
const SQUARE_D1 = SQUARE_A1 << 3
const SQUARE_E1 = SQUARE_A1 << 4
const SQUARE_F1 = SQUARE_A1 << 5
const SQUARE_G1 = SQUARE_A1 << 6
const SQUARE_H1 = SQUARE_A1 << 7

const SQUARE_A8 = SQUARE_A1 << 56
const SQUARE_B8 = SQUARE_A1 << 57
const SQUARE_C8 = SQUARE_A1 << 58
const SQUARE_D8 = SQUARE_A1 << 59
const SQUARE_E8 = SQUARE_A1 << 60
const SQUARE_F8 = SQUARE_A1 << 61
const SQUARE_G8 = SQUARE_A1 << 62
const SQUARE_H8 = SQUARE_A1 << 63
