# move.jl


mutable struct Move
    color_moving::UInt8
    piece_moving::UInt8
    sqr_src::UInt64
    sqr_dest::UInt64
    piece_taken::UInt8
    castling::UInt8
    sqr_ep::UInt64
    promotion_to::UInt8

    #details::UInt64  # could compress this
    # move_type
    #   bits 0-2 : type of piece moving
    #   bits 3-5 : type of piece captured
    #   bits 6-8 : type of piece promotion
    #   bits 9-10: castling
end

Move(color::UInt8, piece_moving::UInt8, src::UInt64, dest::UInt64;
     piece_taken::UInt8=UInt8(0),
     castling::UInt8=UInt8(0),
     sqr_ep::UInt64=UInt64(0),
     promotion_to::UInt8=UInt8(0)) = Move(color, piece_moving, src, dest,
                                          piece_taken,
                                          castling,
                                          sqr_ep,
                                          promotion_to)

import Base.deepcopy
Base.deepcopy(m::Move) = Move(m.color_moving,
                              m.piece_moving,
                              m.sqr_src,
                              m.sqr_dest,
                              m.piece_taken,
                              m.castling,
                              m.sqr_ep,
                              m.promotion_to)

function Base.show(io::IO, move::Move)
    print(io, algebraic_format(move))
end

"Generate a verbose readable string for move, `pawn on e2 to e4`"
function verbose_format(m::Move)
    movestr = piece_name(m.piece_moving) * " on "
    movestr *= square_name(m.sqr_src) * " to "
    movestr *= square_name(m.sqr_dest)
    if m.promotion_to==QUEEN   movestr *= "q"  end
    if m.promotion_to==KNIGHT  movestr *= "n"  end
    if m.promotion_to==BISHOP  movestr *= "b"  end
    if m.promotion_to==ROOK    movestr *= "r"  end
    if m.piece_taken==KING     movestr *= " capturing king"   end
    if m.piece_taken==QUEEN    movestr *= " capturing queen"  end
    if m.piece_taken==ROOK     movestr *= " capturing rook"   end
    if m.piece_taken==BISHOP   movestr *= " capturing bishop" end
    if m.piece_taken==KNIGHT   movestr *= " capturing knight" end
    if m.piece_taken==PAWN     movestr *= " capturing pawn"   end
    movestr
end

"Generate a verbose readable string for moves, `pawn on e2 to e4`"
function verbose_format(moves::Array{Move,1})
    moves_str = ""
    for m in moves
        moves_str = moves_str * verbose_format(m) * "\t "
    end
    moves_str
end

"Generate an ascii string for move, e2e4, or h7h8q, for xboard and UCI protocols"
function long_algebraic_format(m::Move)
    uci_move = square_name(m.sqr_src)
    uci_move *= square_name(m.sqr_dest)
    if m.promotion_to==QUEEN   uci_move *= "q"  end
    if m.promotion_to==KNIGHT  uci_move *= "n"  end
    if m.promotion_to==BISHOP  uci_move *= "b"  end
    if m.promotion_to==ROOK    uci_move *= "r"  end
    uci_move
end

"Generate an ascii string for moves, e2e4, or h7h8q, for xboard and UCI protocols"
function long_algebraic_format(moves::Array{Move,1})
    moves_str = ""
    for m in moves
        moves_str = moves_str * long_algebraic_format(m) * " "
    end
    moves_str
end

"Generate a unicode string, ♘c6"
function algebraic_format(m::Move)
    if m.castling & CASTLING_RIGHTS_WHITE_KINGSIDE > 0 ||
       m.castling & CASTLING_RIGHTS_BLACK_KINGSIDE > 0
        return "⚬-⚬ " #"○-○" #"o-o"
    end

    if m.castling & CASTLING_RIGHTS_WHITE_QUEENSIDE > 0 ||
       m.castling & CASTLING_RIGHTS_BLACK_QUEENSIDE > 0
        return "⚬-⚬-⚬" #"○-○-○" #"o-o-o"
    end

    piece_character = character_for_piece(m.color_moving, m.piece_moving)

    sqr_name = square_name(m.sqr_dest)

    optionally_promoted_to = ""
    if m.promotion_to!=NONE
        optionally_promoted_to = "($(character_for_piece(m.color_moving, m.promotion_to)) )"
    end

    "$piece_character $sqr_name$optionally_promoted_to"
end

"Generate a unicode string, ♘c6"
function algebraic_format(moves::Array{Move,1})
    moves_str = ""
    for m in moves
        moves_str = moves_str * algebraic_format(m) * " "
    end
    moves_str
end
