# board.jl


mutable struct Board   # known as "dense Board representation"
    white_pieces::UInt64
    black_pieces::UInt64
    kings::UInt64
    queens::UInt64
    rooks::UInt64
    bishops::UInt64
    knights::UInt64
    pawns::UInt64
    side_to_move::UInt8
    castling_rights::UInt8
    last_move_pawn_double_push::UInt64

    game_chess960::Bool
    game_kings_starting_column::UInt8
    game_queen_rook_starting_column::UInt8
    game_king_rook_starting_column::UInt8
    game_zobrist::ZobristHash
    game_movelist::Movelist
end
Board() = Board(0,0, 0,0,0, 0,0,0, NONE, 0x0F,0, false, 5, 1, 8, ZobristHash(), Movelist())

import Base.deepcopy
Base.deepcopy(b::Board) = Board(b.white_pieces, b.black_pieces,
                                b.kings, b.queens, b.rooks,
                                b.bishops, b.knights, b.pawns,
                                b.side_to_move,
                                b.castling_rights,
                                b.last_move_pawn_double_push,
                                b.game_chess960,
                                b.game_kings_starting_column,
                                b.game_queen_rook_starting_column,
                                b.game_king_rook_starting_column,
                                b.game_zobrist,
                                b.game_movelist)

function Base.show(io::IO, b::Board)
    print(io, "\n")
    printbd(b, io)

    print(io, "\n")
    print(io, "white pieces\n")
    for r in 8:-1:1
        for c in 1:8
            sqr = square(c,r)
            print(io, "$((b.white_pieces & sqr)>0?1:0) ")
        end
        print(io, "\n")
    end
    print(io, "\n")

    print(io, "black pieces\n")
    for r in 8:-1:1
        for c in 1:8
            sqr = square(c,r)
            print(io, "$((b.black_pieces & sqr)>0?1:0) ")
        end
        print(io, "\n")
    end
    print(io, "\n")

    print(io, "kings\n")
    for r in 8:-1:1
        for c in 1:8
            sqr = square(c,r)
            print(io, "$((b.kings & sqr)>0?1:0) ")
        end
        print(io, "\n")
    end
    print(io, "\n")

    print(io, "queens\n")
    for r in 8:-1:1
        for c in 1:8
            sqr = square(c,r)
            print(io, "$((b.queens & sqr)>0?1:0) ")
        end
        print(io, "\n")
    end
    print(io, "\n")


    print(io, "rooks\n")
    for r in 8:-1:1
        for c in 1:8
            sqr = square(c,r)
            print(io, "$((b.rooks & sqr)>0?1:0) ")
        end
        print(io, "\n")
    end
    print(io, "\n")

    print(io, "bishops\n")
    for r in 8:-1:1
        for c in 1:8
            sqr = square(c,r)
            print(io, "$((b.bishops & sqr)>0?1:0) ")
        end
        print(io, "\n")
    end
    print(io, "\n")

    print(io, "knights\n")
    for r in 8:-1:1
        for c in 1:8
            sqr = square(c,r)
            print(io, "$((b.knights & sqr)>0?1:0) ")
        end
        print(io, "\n")
    end
    print(io, "\n")

    print(io, "pawns\n")
    for r in 8:-1:1
        for c in 1:8
            sqr = square(c,r)
            print(io, "$((b.pawns & sqr)>0?1:0) ")
        end
        print(io, "\n")
    end
    print(io, "\n")
end

"Remove any pieces from this column,row square"
function clear_square(b::Board, c, r)
    sqr = square(c, r)
    b.white_pieces = b.white_pieces & ~sqr
    b.black_pieces = b.black_pieces & ~sqr
    b.kings = b.kings & ~sqr
    b.queens = b.queens & ~sqr
    b.rooks = b.rooks & ~sqr
    b.bishops = b.bishops & ~sqr
    b.knights = b.knights & ~sqr
    b.pawns = b.pawns & ~sqr
end

"Place defined color of piece on square"
function set!(b::Board, color, p, c, r)
    clear_square(b, c, r) # insure all prior information is cleared out
    sqr = square(c, r)
    if p==KING    b.kings|=sqr    end
    if p==QUEEN   b.queens|=sqr   end
    if p==ROOK    b.rooks|=sqr    end
    if p==BISHOP  b.bishops|=sqr  end
    if p==KNIGHT  b.knights|=sqr  end
    if p==PAWN    b.pawns|=sqr    end
    if color==WHITE  b.white_pieces|=sqr   end
    if color==BLACK  b.black_pieces|=sqr   end
    nothing
end

"Creates a new standard chess board"
function new_game()
    b = read_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    b.game_chess960 = false
    b.game_kings_starting_column = 5
    b.game_queen_rook_starting_column = 1
    b.game_king_rook_starting_column = 8
    b
end

"""
Creates a new FischerChess 960 chess board
Note that pieces aren't truly random:
  the bishops must be placed on opposite-color squares.
  the king must be placed on a square between the rooks.
"""
function new_game_960()
    b = Board()
    for file in 1:8
        set!(b, WHITE, PAWN, file, 2)
        set!(b, BLACK, PAWN, file, 7)
    end

    open_files = [1,2,3,4,5,6,7,8]

    bishop_color_a_file = rand(1:8)
    set!(b, WHITE, BISHOP, bishop_color_a_file, 1)
    set!(b, BLACK, BISHOP, bishop_color_a_file, 8)
    bishop_color_b_file = 2*rand(1:4) - (bishop_color_a_file%2==0?1:0)
    set!(b, WHITE, BISHOP, bishop_color_b_file, 1)
    set!(b, BLACK, BISHOP, bishop_color_b_file, 8)
    filter!(e->e≠bishop_color_a_file,open_files)
    filter!(e->e≠bishop_color_b_file,open_files)

    queen_file = open_files[rand(1:6)]
    set!(b, WHITE, QUEEN, queen_file, 1)
    set!(b, BLACK, QUEEN, queen_file, 8)
    filter!(e->e≠queen_file,open_files)

    knight_a_file = open_files[rand(1:5)]
    set!(b, WHITE, KNIGHT, knight_a_file, 1)
    set!(b, BLACK, KNIGHT, knight_a_file, 8)
    filter!(e->e≠knight_a_file,open_files)

    knight_b_file = open_files[rand(1:4)]
    set!(b, WHITE, KNIGHT, knight_b_file, 1)
    set!(b, BLACK, KNIGHT, knight_b_file, 8)
    filter!(e->e≠knight_b_file,open_files)

    set!(b, WHITE, ROOK, open_files[1], 1)
    set!(b, BLACK, ROOK, open_files[1], 8)
    set!(b, WHITE, KING, open_files[2], 1)
    set!(b, BLACK, KING, open_files[2], 8)
    set!(b, WHITE, ROOK, open_files[3], 1)
    set!(b, BLACK, ROOK, open_files[3], 8)

    b.game_queen_rook_starting_column = open_files[1]
    b.game_kings_starting_column = open_files[2]
    b.game_king_rook_starting_column = open_files[3]

    b.side_to_move = WHITE
    b.game_chess960 = true
    b.game_zobrist = ZobristHash()
    b
end

"Compute the Zobrish hash on the chess position"
@inline function compute_hash(board::Board)
    hash = UInt64(0)
	for square_index in 1:64
        sqr = UInt64(1) << (square_index-1)

		piece = piece_type_on_sqr(board, sqr)
		if piece == NONE
			continue
		end

		color = piece_color_on_sqr(board, sqr)

		hash = update_hash(board.game_zobrist, hash, piece*color, UInt8(square_index))
	end
	hash
end

"Pretty print the chess board in the REPL"
function printbd(b::Board, io=STDOUT, moves=nothing)
    println("$(version)")
    println("FEN $(write_fen(b))")
    println("   hash $(hex(compute_hash(b)))")
    print(io, "       ")
    if b.castling_rights & CASTLING_RIGHTS_BLACK_QUEENSIDE > 0
        print(io, CHARACTER_CASTLING_AVAILABLE)
    end
    print(io, "       ")
    if b.castling_rights & CASTLING_RIGHTS_BLACK_KINGSIDE > 0
        print(io, CHARACTER_CASTLING_AVAILABLE)
    end
    if b.side_to_move==WHITE     print("      WHITE to move")
    elseif b.side_to_move==BLACK print("      BLACK to move")
    else                         print("      ????? to move")
    end
    if b.last_move_pawn_double_push > 0
        print(io, "   en passant from $(square_name(b.last_move_pawn_double_push))")
    end
    print(io, "\n")

    for r in 8:-1:1
        print(io, "$(SMALL_NUMBERS[r])   ")
        for c in 1:8
            sqr = square(c, r)
            piece = piece_type_on_sqr(b, sqr)
            color = piece_color_on_sqr(b, sqr)
            s = character_for_piece(color, piece)
            if moves!=nothing
                for m in moves
                    if (m.sqr_dest & sqr)>0
                        if s != CHARACTER_SQUARE_EMPTY && s != CHARACTER_SQUARE_ATTACKED
                            s = CHARACTER_SQUARE_CAPTURE
                        else
                            s = CHARACTER_SQUARE_ATTACKED
                        end
                    end
                end
            end
            print(io, "$s ")
        end
        print(io, "\n")
    end
    print(io, "       ")
    if b.castling_rights & CASTLING_RIGHTS_WHITE_QUEENSIDE > 0
        print(io, CHARACTER_CASTLING_AVAILABLE)
    end
    print(io, "       ")
    if b.castling_rights & CASTLING_RIGHTS_WHITE_KINGSIDE > 0
        print(io, CHARACTER_CASTLING_AVAILABLE)
    end
    print(io, "\n")
    #println("    a b c d e f g h")
    #println("    ᵃ ᵇ ᶜ ᵈ ᵉ ᶠ ᵍ ᴴ")
    #println("    𝑎 𝑏 𝑐 𝑑 𝑒 𝑓 𝑔 h")
    #println("    𝔞 𝔟 𝔠 𝔡 𝔢 𝔣 𝔤 𝔥")
    #println("    𝖠 𝖡 𝖢 𝖣 𝖤 𝖥 𝖦 𝖧")
    #println("    𝕒 𝕓 𝕔 𝕕 𝕖 𝕗 𝕘 𝕙")
    print(io, "    𝖺 𝖻 𝖼 𝖽 𝖾 𝖿 𝗀 𝗁")
    print(io, "   Score $(round(evaluate(b),2)) pawns\n")
end

"Given a square name, e4, return the UInt64 value"
function square(square_name::String)
    assert(length(square_name)==2)
    file = parse(Integer, square_name[1]-48)
    row = parse(Integer, square_name[2])
    square(file, row)
end

"Create a new board from the FEN string"
function read_fen(fen::String)
    b = Board()
    # r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -
    file = 1
    row = 8
    splitfen = split(fen, " ")
    for t in splitfen[1]
        if t=='K' set!(b, WHITE, KING,   file, row)
        elseif t=='Q' set!(b, WHITE, QUEEN,   file, row)
        elseif t=='R' set!(b, WHITE, ROOK,   file, row)
        elseif t=='B' set!(b, WHITE, BISHOP,   file, row)
        elseif t=='N' set!(b, WHITE, KNIGHT,   file, row)
        elseif t=='P' set!(b, WHITE, PAWN,   file, row)
        elseif t=='k' set!(b, BLACK, KING,   file, row)
        elseif t=='q' set!(b, BLACK, QUEEN,   file, row)
        elseif t=='r' set!(b, BLACK, ROOK,   file, row)
        elseif t=='b' set!(b, BLACK, BISHOP,   file, row)
        elseif t=='n' set!(b, BLACK, KNIGHT,   file, row)
        elseif t=='p' set!(b, BLACK, PAWN,   file, row)
        elseif isnumber(t) file += parse(Integer,t)-1
        elseif t=='/'
            row -= 1
            file = 0
        end
        file += 1
    end

    white_to_move = (splitfen[2]=="w")
    if white_to_move
        b.side_to_move = WHITE
    else
        b.side_to_move = BLACK
    end

    b.castling_rights = 0x00
    for t in splitfen[3]
        if t=='K' b.castling_rights = b.castling_rights | CASTLING_RIGHTS_WHITE_KINGSIDE
        elseif t=='Q' b.castling_rights = b.castling_rights | CASTLING_RIGHTS_WHITE_QUEENSIDE
        elseif t=='k' b.castling_rights = b.castling_rights | CASTLING_RIGHTS_BLACK_KINGSIDE
        elseif t=='q' b.castling_rights = b.castling_rights | CASTLING_RIGHTS_BLACK_QUEENSIDE
        end
    end

    if splitfen[4]!="-"
        b.last_move_pawn_double_push = square(splitfen[4])
    end

    b.game_zobrist = ZobristHash()
    b
end

"Produce the string FEN of the current board"
function write_fen(b::Board)
    fen = ""
    empty_squares = 0
    for row in 8:-1:1
        for file in 1:8
            sqr = square(file, row)
            if (b.white_pieces & sqr > 0 || b.black_pieces & sqr > 0) && empty_squares > 0
                fen *= string(empty_squares)
                empty_squares = 0
            end
            if b.white_pieces & sqr > 0
                if b.kings & sqr > 0   fen *= "K" end
                if b.queens & sqr > 0  fen *= "Q" end
                if b.rooks & sqr > 0   fen *= "R" end
                if b.bishops & sqr > 0 fen *= "B" end
                if b.knights & sqr > 0 fen *= "N" end
                if b.pawns & sqr > 0   fen *= "P" end
            elseif b.black_pieces & sqr > 0
                if b.kings & sqr > 0   fen *= "k" end
                if b.queens & sqr > 0  fen *= "q" end
                if b.rooks & sqr > 0   fen *= "r" end
                if b.bishops & sqr > 0 fen *= "b" end
                if b.knights & sqr > 0 fen *= "n" end
                if b.pawns & sqr > 0   fen *= "p" end
            else
                empty_squares += 1
            end
        end # for file in 1:8
        if empty_squares > 0
            fen *= string(empty_squares)
        end
        if row>1
            fen *= "/"
        end
        empty_squares = 0
    end
    fen *= " "
    if b.side_to_move==WHITE
        fen *= "w"
    else
        fen *= "b"
    end
    fen *= " "
    if b.castling_rights & CASTLING_RIGHTS_WHITE_KINGSIDE > 0 fen *= "K" end
    if b.castling_rights & CASTLING_RIGHTS_WHITE_QUEENSIDE > 0 fen *= "Q" end
    if b.castling_rights & CASTLING_RIGHTS_BLACK_KINGSIDE > 0 fen *= "k" end
    if b.castling_rights & CASTLING_RIGHTS_BLACK_QUEENSIDE > 0 fen *= "q" end
    fen *= " "
    if b.last_move_pawn_double_push > 0
        sqr = b.last_move_pawn_double_push
        if b.side_to_move==WHITE
            sqr = sqr << 8
        else
            sqr = sqr >> 8
        end
        fen *= square_name(sqr)
    else
        fen *= "-"
    end


    fen
end

"Debugging validation checks for internal consistancy of the board"
function board_validation_checks(b::Board)
    return

    # check no overlap - each square can have one and only one piece
    assert(b.side_to_move!=NONE)

    for i in 0:63
        sqr = UInt64(1) << i

        # a color must have a piece
        if sqr & b.white_pieces > 0
            @assert (sqr & (b.pawns | b.knights | b.bishops | b.rooks | b.queens | b.kings) > 0) "$b\n white nothing at $(square_name(sqr))"
        end
        if sqr & b.black_pieces > 0
            @assert (sqr & (b.pawns | b.knights | b.bishops | b.rooks | b.queens | b.kings) > 0) "$b\n black nothing at $(square_name(sqr))"
        end

        # square can't hold both a black and a white piece simultaneously
        @assert sqr & b.white_pieces & b.black_pieces == 0  "$b\n over occupied at $(square_name(sqr))"

        # a piece must have a color
        if sqr & b.pawns > 0
            @assert (sqr & b.pawns & b.white_pieces > 0) || (sqr & b.pawns & b.black_pieces > 0) "$b\n colorless pawn at $(square_name(sqr))"
        end
        if sqr & b.knights > 0
            @assert (sqr & b.knights & b.white_pieces > 0) || (sqr & b.knights & b.black_pieces > 0) "$b\n colorless knight at $(square_name(sqr))"
        end
        if sqr & b.bishops > 0
            @assert (sqr & b.bishops & b.white_pieces > 0) || (sqr & b.bishops & b.black_pieces > 0) "$b\n colorless bishop at $(square_name(sqr))"
        end
        if sqr & b.rooks > 0
            @assert (sqr & b.rooks & b.white_pieces > 0) || (sqr & b.rooks & b.black_pieces > 0) "$b\n colorless rook at $(square_name(sqr))"
        end
        if sqr & b.queens > 0
            @assert (sqr & b.queens & b.white_pieces > 0) || (sqr & b.queens & b.black_pieces > 0) "$b\n colorless queen at $(square_name(sqr))"
        end
        if sqr & b.kings > 0
            @assert (sqr & b.kings & b.white_pieces > 0) || (sqr & b.kings & b.black_pieces > 0) "$b\n colorless king at $(square_name(sqr))"
        end
    end

    # s
    @assert b.kings & b.queens & b.rooks & b.bishops & b.knights & b.pawns == 0  "$b"

    # check counts
    n_white_pieces = count(b.white_pieces)
    n_black_pieces = count(b.black_pieces)

    n_kings = count(b.kings)
    n_queens = count(b.queens)
    n_rooks = count(b.rooks)
    n_bishops = count(b.bishops)
    n_knights = count(b.knights)
    n_pawns = count(b.pawns)

    t1 = n_white_pieces + n_black_pieces
    t2 = n_kings + n_queens + n_rooks + n_bishops + n_knights + n_pawns
    @assert t1==t2  "$b"
end
