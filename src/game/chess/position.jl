# position.jl

"Return piece type KING, PAWN on square, or NONE if empty"
@inline function piece_type_on_sqr(b::Board, sqr::UInt64)
    if (b.kings   & sqr)>0  return KING    end
    if (b.queens  & sqr)>0  return QUEEN   end
    if (b.rooks   & sqr)>0  return ROOK    end
    if (b.bishops & sqr)>0  return BISHOP  end
    if (b.knights & sqr)>0  return KNIGHT  end
    if (b.pawns   & sqr)>0  return PAWN    end
    return NONE
end

"Return color of piece on square, or NONE if empty"
@inline function piece_color_on_sqr(b::Board, sqr::UInt64)
    if (b.white_pieces & sqr)>0  return WHITE  end
    if (b.black_pieces & sqr)>0  return BLACK  end
    return NONE
end

@inline function clear_for_castling(b::Board, sqr::UInt64)
    (b.bishops & sqr)==0 && (b.knights & sqr)==0 && (b.queens & sqr)==0
end


# handle adding sliding moves of QUEEN, ROOK, BISHOP
#  which end by being BLOCKED or capturing an enemy piece
const UNBLOCKED = UInt8(0)
const BLOCKED = UInt8(1)
const CAPTURE = UInt8(2)
@inline function add_move!(b::Board,
                           my_color::UInt8, my_piece::UInt8,
                           src_sqr::UInt64, dest_sqr::UInt64;
                           promotion_to::UInt8=NONE,
                           en_passant_sqr::UInt64=UInt64(0))
    # move is off the board
    if dest_sqr==0
        return BLOCKED
    end

    o = piece_color_on_sqr(b,dest_sqr)

    # move is blocked by one of my own pieces
    if o==my_color
        return BLOCKED
    end

    # move is a capturing move
    move = get_move(b.game_movelist)
    if o!=NONE
        if my_color == b.side_to_move
            increment_move_count(b.game_movelist)
        else  # put the move on the attacking moves list from the opponent
            move = get_attacking_move(b.game_movelist)
            increment_attacking_move_count(b.game_movelist)
        end
        move.color_moving = my_color
        move.piece_moving = my_piece
        move.sqr_src = src_sqr
        move.sqr_dest = dest_sqr
        move.piece_taken = piece_type_on_sqr(b,dest_sqr)
        move.castling = CASTLING_NONE
        move.sqr_ep = UInt64(0)
        move.promotion_to = promotion_to
        return BLOCKED
    end

    # move to an empty square
    if my_color == b.side_to_move
        increment_move_count(b.game_movelist)
    else  # put the move on the attacking moves list from the opponent
        move = get_attacking_move(b.game_movelist)
        increment_attacking_move_count(b.game_movelist)
    end
    move.color_moving = my_color
    move.piece_moving = my_piece
    move.sqr_src = src_sqr
    move.sqr_dest = dest_sqr
    move.piece_taken = NONE
    move.castling = CASTLING_NONE
    move.sqr_ep = en_passant_sqr
    move.promotion_to = promotion_to

    return UNBLOCKED
end

@inline function add_king_moves!(sqr, b, my_color)
    new_sqr = (sqr>>9) & ~FILE_H
    add_move!(b, my_color, KING, sqr, new_sqr)

    new_sqr = (sqr>>8)
    add_move!(b, my_color, KING, sqr, new_sqr)

    new_sqr = (sqr>>7) & ~FILE_A
    add_move!(b, my_color, KING, sqr, new_sqr)

    new_sqr = (sqr>>1) & ~FILE_H
    add_move!(b, my_color, KING, sqr, new_sqr)

    new_sqr = (sqr<<1) & ~FILE_A
    add_move!(b, my_color, KING, sqr, new_sqr)

    new_sqr = (sqr<<7) & ~FILE_H
    add_move!(b, my_color, KING, sqr, new_sqr)

    new_sqr = (sqr<<8)
    add_move!(b, my_color, KING, sqr, new_sqr)

    new_sqr = (sqr<<9) & ~FILE_A
    add_move!(b, my_color, KING, sqr, new_sqr)
end

@inline function add_rook_moves!(sqr, b, my_color, my_piece)
    for i in 1:7
        new_sqr = sqr>>i
        if new_sqr & FILE_H > 0
            break
        end
        if add_move!(b, my_color, my_piece, sqr, new_sqr) == BLOCKED
            break
        end
    end
    for i in 1:7
        new_sqr = sqr<<i
        if new_sqr & FILE_A > 0
            break
        end
        if add_move!(b, my_color, my_piece, sqr, new_sqr) == BLOCKED
            break
        end
    end
    for i in 1:7
        new_sqr = sqr>>(i*8)
        if add_move!(b, my_color, my_piece, sqr, new_sqr) == BLOCKED
            break
        end
    end
    for i in 1:7
        new_sqr = sqr<<(i*8)
        if add_move!(b, my_color, my_piece, sqr, new_sqr) == BLOCKED
            break
        end
    end
end

@inline function add_bishop_moves!(sqr, b, my_color, my_piece)
    for i in 1:7
        new_sqr = sqr>>(i*9)
        if new_sqr & FILE_H > 0
            break
        end
        if add_move!(b, my_color, my_piece, sqr, new_sqr) == BLOCKED
            break
        end
    end
    for i in 1:7
        new_sqr = sqr>>(i*7)
        if new_sqr & FILE_A > 0
            break
        end
        if add_move!(b, my_color, my_piece, sqr, new_sqr) == BLOCKED
            break
        end
    end
    for i in 1:7
        new_sqr = sqr<<(i*7)
        if new_sqr & FILE_H > 0
            break
        end
        if add_move!(b, my_color, my_piece, sqr, new_sqr) == BLOCKED
            break
        end
    end
    for i in 1:7
        new_sqr = sqr<<(i*9)
        if new_sqr & FILE_A > 0
            break
        end
        if add_move!(b, my_color, my_piece, sqr, new_sqr) == BLOCKED
            break
        end
    end
end

@inline function add_knight_moves!(sqr, b, my_color)
    add_move!(b, my_color, KNIGHT, sqr, (sqr & ~FILE_A)>>17)
    add_move!(b, my_color, KNIGHT, sqr, (sqr & ~FILE_AB)>>10)
    add_move!(b, my_color, KNIGHT, sqr, (sqr & ~FILE_AB)<<6)
    add_move!(b, my_color, KNIGHT, sqr, (sqr & ~FILE_A)<<15)

    add_move!(b, my_color, KNIGHT, sqr, (sqr & ~FILE_H)>>15)
    add_move!(b, my_color, KNIGHT, sqr, (sqr & ~FILE_GH)<<10)
    add_move!(b, my_color, KNIGHT, sqr, (sqr & ~FILE_GH)>>6)
    add_move!(b, my_color, KNIGHT, sqr, (sqr & ~FILE_H)<<17)
end

"Generate all legal moves on the board"
function generate_moves(b::Board; no_checking_for_pins=false)
    clear_current_movelist!(b.game_movelist)

    # create a list of moves by all pieces (both black and white)
    for square_index in 1:64
        sqr = UInt64(1) << (square_index-1)

        # skip empty squares, else determine piece color
        moving_pieces_color = piece_color_on_sqr(b,sqr)
        if moving_pieces_color==NONE
            continue
        elseif moving_pieces_color==b.side_to_move
            my_color = b.side_to_move
            enemy_color = opposite_color(b.side_to_move)
        else
            my_color = opposite_color(b.side_to_move)
            enemy_color = b.side_to_move
        end

        # note: ÷ gives integer quotient, a.k.a. div()
        row = (square_index-1)÷8 + 1

        # kings moves
        king = sqr & b.kings
        if king > 0
            add_king_moves!(sqr, b, my_color)
        end # king

        # rook moves
        queen = sqr & b.queens
        rook = sqr & b.rooks
        my_piece = queen > 0 ? QUEEN : ROOK
        if rook > 0 || queen > 0
            add_rook_moves!(sqr, b, my_color, my_piece)
        end

        # bishop moves
        bishop = sqr & b.bishops
        my_piece = queen > 0 ? QUEEN : BISHOP
        if bishop > 0 || queen > 0
            add_bishop_moves!(sqr, b, my_color, my_piece)
        end

        # knight moves
        knight = sqr & b.knights
        if knight > 0
            add_knight_moves!(sqr, b, my_color)
        end

        # pawn moves
        pawn = sqr & b.pawns
        my_piece = PAWN
        if pawn > 0
            ONE_SQUARE_FORWARD = 8
            TWO_SQUARE_FORWARD = 16
            TAKE_LEFT = 7
            TAKE_RIGHT = 9
            START_RANK = 2
            LAST_RANK = 7
            bitshift_direction = <<
            if my_color==BLACK
                TAKE_LEFT = 9
                TAKE_RIGHT = 7
                START_RANK = 7
                LAST_RANK = 2
                bitshift_direction = >>
            end

            # step one or two squares forward onto empty square
            new_sqr = bitshift_direction(sqr, ONE_SQUARE_FORWARD)
            if piece_color_on_sqr(b, new_sqr) == NONE
                if row == LAST_RANK
                    add_move!(b, my_color, PAWN, sqr, new_sqr, promotion_to=QUEEN)
                    add_move!(b, my_color, PAWN, sqr, new_sqr, promotion_to=KNIGHT)
                    add_move!(b, my_color, PAWN, sqr, new_sqr, promotion_to=ROOK)
                    add_move!(b, my_color, PAWN, sqr, new_sqr, promotion_to=BISHOP)
                else
                    add_move!(b, my_color, PAWN, sqr, new_sqr)
                end
                if row == START_RANK
                    new_sqr = bitshift_direction(sqr, TWO_SQUARE_FORWARD)
                    if piece_color_on_sqr(b, new_sqr) == NONE
                        add_move!(b, my_color, PAWN, sqr, new_sqr)
                    end
                end
            end

            # take a piece forward left
            new_sqr = bitshift_direction(sqr, TAKE_LEFT) & ~FILE_H
            new_sqr_piece_color = piece_color_on_sqr(b, new_sqr)
            if new_sqr_piece_color == enemy_color
                if row == LAST_RANK
                    add_move!(b, my_color, PAWN, sqr, new_sqr, promotion_to=QUEEN)
                    add_move!(b, my_color, PAWN, sqr, new_sqr, promotion_to=KNIGHT)
                    add_move!(b, my_color, PAWN, sqr, new_sqr, promotion_to=ROOK)
                    add_move!(b, my_color, PAWN, sqr, new_sqr, promotion_to=BISHOP)
                else
                    add_move!(b, my_color, PAWN, sqr, new_sqr)
                end
            end
            # add enemy pawn threat to list for "attacking" moves
            if new_sqr_piece_color == NONE && moving_pieces_color != b.side_to_move
                add_move!(b, my_color, PAWN, sqr, new_sqr)
            end
            # en passant to left
            if b.last_move_pawn_double_push > 0 &&
                new_sqr == bitshift_direction(b.last_move_pawn_double_push, ONE_SQUARE_FORWARD) &&
                !no_checking_for_pins
                add_move!(b, my_color, PAWN, sqr, new_sqr, en_passant_sqr=b.last_move_pawn_double_push)
            end

            # take a piece forward right
            new_sqr = bitshift_direction(sqr, TAKE_RIGHT) & ~FILE_A
            new_sqr_piece_color = piece_color_on_sqr(b, new_sqr)
            if new_sqr_piece_color == enemy_color
                if row == LAST_RANK
                    add_move!(b, my_color, PAWN, sqr, new_sqr, promotion_to=QUEEN)
                    add_move!(b, my_color, PAWN, sqr, new_sqr, promotion_to=KNIGHT)
                    add_move!(b, my_color, PAWN, sqr, new_sqr, promotion_to=ROOK)
                    add_move!(b, my_color, PAWN, sqr, new_sqr, promotion_to=BISHOP)
                else
                    add_move!(b, my_color, PAWN, sqr, new_sqr)
                end
            end
            # add enemy pawn threat to list for "attacking" moves
            if new_sqr_piece_color == NONE && moving_pieces_color != b.side_to_move
                add_move!(b, my_color, PAWN, sqr, new_sqr)
            end
            # en passant to right
            if b.last_move_pawn_double_push > 0 &&
                new_sqr == bitshift_direction(b.last_move_pawn_double_push, ONE_SQUARE_FORWARD) &&
                !no_checking_for_pins
                add_move!(b, my_color, PAWN, sqr, new_sqr, en_passant_sqr=b.last_move_pawn_double_push)
            end
        end  #  if pawn > 0
    end # for square_index in 1:64

    my_color = b.side_to_move
    enemy_color = opposite_color(my_color)

    # is king in check?
    kings_square = b.kings & (b.side_to_move==WHITE ? b.white_pieces : b.black_pieces)
    if kings_square == UInt64(0)
        #warn("$(COLOR_NAMES[my_color]) king missing from board.")
        # king can be missing due to quiescence search...
        return get_list_of_moves(b.game_movelist) # empty list
    end

    record_attacked_squares(b.game_movelist)

    king_in_check = is_square_attacked(b.game_movelist, kings_square)

    # castling kingside (allows for chess960 castling too)
    if !king_in_check
        kings_travel_sqrs = []
        rooks_travel_sqrs = []

        #  first figure out what squares the pieces move through
        castling_type = (my_color == WHITE ? CASTLING_RIGHTS_WHITE_KINGSIDE : CASTLING_RIGHTS_BLACK_KINGSIDE)
        if b.castling_rights & castling_type > 0
            r = (my_color == WHITE ? 1 : 8)
            # to accomodate chess960, we check the games setup
            c1 = min(b.game_kings_starting_column, G)
            c2 = max(b.game_kings_starting_column, G)
            rng = c1:c2
            kings_travel_sqrs = UInt64[square(c,r) for c in rng]
            # remove the kings own square from travel path
            filter!(e->e∉square(b.game_kings_starting_column,r),kings_travel_sqrs)

            c1 = min(b.game_king_rook_starting_column, F)
            c2 = max(b.game_king_rook_starting_column, F)
            rng = c1:c2
            rooks_travel_sqrs = UInt64[square(c,r) for c in rng]
            # remove the rooks own square from travel path
            filter!(e->e∉square(b.game_king_rook_starting_column,r),rooks_travel_sqrs)
        end

        # add kingside castling if it is allowed
        if length(kings_travel_sqrs)>0 &&
            # check that the king's travel squares are empty
            reduce(&, Bool[clear_for_castling(b, s) for s in kings_travel_sqrs]) &&
            # check that the rook's travel squares are empty
            reduce(&, Bool[clear_for_castling(b, s) for s in rooks_travel_sqrs]) &&
            # check that king's traversal squares are not attacked
            reduce(&, Bool[!is_square_attacked(b.game_movelist, s) for s in kings_travel_sqrs])
                # add kingside castling move
                move = get_move(b.game_movelist)
                move.color_moving = my_color
                move.piece_moving = KING
                move.sqr_src = square(b.game_kings_starting_column,r)
                move.sqr_dest = square(G,r)
                move.piece_taken = NONE
                move.castling = castling_type
                move.sqr_ep = UInt64(0)
                move.promotion_to = NONE
                increment_move_count(b.game_movelist)
        end

        kings_travel_sqrs = []  # must now reset this array!

        # castling queenside (allows for chess960 castling too)
        castling_type = (my_color == WHITE ? CASTLING_RIGHTS_WHITE_QUEENSIDE : CASTLING_RIGHTS_BLACK_QUEENSIDE)
        if b.castling_rights & castling_type > 0
            r = (my_color == WHITE ? 1 : 8)
            # to accomodate chess960, we check the games setup
            c1 = min(b.game_kings_starting_column, C)
            c2 = max(b.game_kings_starting_column, C)
            rng = c1:c2
            kings_travel_sqrs = UInt64[square(c,r) for c in rng]
            # remove the kings own square from travel path
            filter!(e->e∉square(b.game_kings_starting_column,r),kings_travel_sqrs)

            c1 = min(b.game_queen_rook_starting_column, D)
            c2 = max(b.game_queen_rook_starting_column, D)
            rng = c1:c2
            rooks_travel_sqrs = UInt64[square(c,r) for c in rng]
            # remove the rooks own square from travel path
            filter!(e->e∉square(b.game_queen_rook_starting_column,r),rooks_travel_sqrs)
        end

        # add queenside castling if it is allowed
        if length(kings_travel_sqrs)>0 &&
            # check that the kings travel squares are empty
            reduce(&, Bool[clear_for_castling(b, s) for s in kings_travel_sqrs]) &&
            # check that the rook's travel squares are empty
            reduce(&, Bool[clear_for_castling(b, s) for s in rooks_travel_sqrs]) &&
            # check that king's traversal squares are not attacked
            reduce(&, Bool[!is_square_attacked(b.game_movelist, s) for s in kings_travel_sqrs])
                # add kingside castling move
                move = get_move(b.game_movelist)
                move.color_moving = my_color
                move.piece_moving = KING
                move.sqr_src = square(b.game_kings_starting_column,r)
                move.sqr_dest = square(C,r)
                move.piece_taken = NONE
                move.castling = castling_type
                move.sqr_ep = UInt64(0)
                move.promotion_to = NONE
                increment_move_count(b.game_movelist)
        end
    end # castling moves





    if(no_checking_for_pins==false)
        # PINNED pieces
        # check for pieces pinned to the king
        #   and remove any moves by them
        # PLAN: find king's unique square
        #       find any enemy queens,rooks,bishops on same file/columm/diagonal as king
        #       check if there is only an interposing mycolor piece
        #       remove any moves by that piece away from that file/columm/diagonal
        # OR, (implemented)
        #       simply run the ply, make each move, and if the enemy response allows king capture,
        #       remove it from the list
        prior_castling_rights = b.castling_rights
        prior_last_move_pawn_double_push = b.last_move_pawn_double_push
        illegal_moves = []
        for (i,move) in enumerate(get_list_of_moves(b.game_movelist))
            if i > number_of_moves(b.game_movelist)
                break
            end
            make_move!(b,move)
            kings_new_square = b.kings & (my_color==WHITE ? b.white_pieces : b.black_pieces)

            # TODO: this seems un-necessary
            if move.piece_moving==KING
                kings_new_square = move.sqr_dest
            end

            #println("Checking $(m) for pins against KING on $(square_name(kings_new_square))")
            #increment_ply_count(b.game_movelist)
            reply_moves = generate_moves(b, no_checking_for_pins=true)
            #decrement_ply_count(b.game_movelist)
            unmake_move!(b, move, prior_castling_rights, prior_last_move_pawn_double_push)
            for reply_move in reply_moves
                #@show reply_move
                if reply_move.sqr_dest == kings_new_square
                    #println("  move $(algebraic_format(move)) illegal because of reply $(algebraic_format(reply_move))")
                    push!(illegal_moves, move)
                    break
                end
            end
        end
        filter_illegal_moves_out!(b.game_movelist, illegal_moves)
    end


    # order moves by biggest captures first
    sort_moves_by_captures!(b.game_movelist)

    # TODO: generate_moves() order moves so that a capture of last moved piece is first

    # TODO: caller must now iterate correctly over movelist structure
    get_list_of_moves(b.game_movelist)
end

"Make move described by string, e2e4, on board"
function make_move!(b::Board, movestr::String)
    move = nothing
    moves = generate_moves(b)
    for m in moves
        if long_algebraic_format(m)==movestr
            make_move!(b,m)
            move = m
            break
        end
    end
    move
end

"Make move on board"
function make_move!(b::Board, m::Move)
    #println("make_move($m)")

    assert(m.sqr_src > 0)
    assert(m.sqr_dest > 0)

    sqr_src = m.sqr_src
    sqr_dest = m.sqr_dest
    sqr_move = sqr_src | sqr_dest

    color = piece_color_on_sqr(b,sqr_src)
    #assert(color!=NONE)
    moving_piece = piece_type_on_sqr(b,sqr_src)
    #assert(moving_piece!=NONE)
    taken_piece = piece_type_on_sqr(b,sqr_dest)

    # remove any piece on destination square
    if taken_piece != NONE
        b.kings = b.kings & ~sqr_dest
        b.queens = b.queens & ~sqr_dest
        b.rooks = b.rooks & ~sqr_dest
        b.bishops = b.bishops & ~sqr_dest
        b.knights = b.knights & ~sqr_dest
        b.pawns = b.pawns & ~sqr_dest
        b.white_pieces = b.white_pieces & ~sqr_dest
        b.black_pieces = b.black_pieces & ~sqr_dest
    end

    # move the moving piece (remove from src, add to dest)
    if moving_piece == KING         b.kings = b.kings ⊻ sqr_move
    elseif moving_piece == QUEEN    b.queens = b.queens ⊻ sqr_move
    elseif moving_piece == ROOK     b.rooks = b.rooks ⊻ sqr_move
    elseif moving_piece == BISHOP   b.bishops = b.bishops ⊻ sqr_move
    elseif moving_piece == KNIGHT   b.knights = b.knights ⊻ sqr_move
    elseif moving_piece == PAWN     b.pawns = b.pawns ⊻ sqr_move
    end

    # set en passant marker
    b.last_move_pawn_double_push = UInt64(0)
    if moving_piece == PAWN &&
        (sqr_dest << 16 == sqr_src || sqr_src << 16 == sqr_dest)
        b.last_move_pawn_double_push = sqr_dest
    end

    # update the moving color (remove from src, add to dest)
    if (b.white_pieces & sqr_src) > 0
        b.white_pieces = b.white_pieces ⊻ sqr_move
    end
    if (b.black_pieces & sqr_src) > 0
        b.black_pieces = b.black_pieces ⊻ sqr_move
    end

    # en passant - remove any pawn taken by en passant
    if m.sqr_ep > 0
        b.pawns = b.pawns & ~m.sqr_ep
        b.white_pieces = b.white_pieces & ~m.sqr_ep
        b.black_pieces = b.black_pieces & ~m.sqr_ep
    end

    # pawn promotion
    if m.promotion_to > NONE
        b.pawns = b.pawns & ~sqr_dest
        if m.promotion_to == QUEEN       b.queens = b.queens | sqr_dest
        elseif m.promotion_to == KNIGHT  b.knights = b.knights | sqr_dest
        elseif m.promotion_to == ROOK    b.rooks = b.rooks | sqr_dest
        elseif m.promotion_to == BISHOP  b.bishops = b.bishops | sqr_dest
        end
        if color == WHITE      b.white_pieces = b.white_pieces | sqr_dest
        elseif color == BLACK  b.black_pieces = b.black_pieces | sqr_dest
        end
    end

    # update castling rights
    if moving_piece == KING
        if color == WHITE      b.castling_rights = b.castling_rights & ~CASTLING_RIGHTS_WHITE_ANYSIDE
        elseif color == BLACK  b.castling_rights = b.castling_rights & ~CASTLING_RIGHTS_BLACK_ANYSIDE
        end
    elseif moving_piece == ROOK
        if sqr_src == SQUARE_A1       b.castling_rights = b.castling_rights & ~CASTLING_RIGHTS_WHITE_QUEENSIDE
        elseif sqr_src == SQUARE_H1   b.castling_rights = b.castling_rights & ~CASTLING_RIGHTS_WHITE_KINGSIDE
        elseif sqr_src == SQUARE_A8   b.castling_rights = b.castling_rights & ~CASTLING_RIGHTS_BLACK_QUEENSIDE
        elseif sqr_src == SQUARE_H8   b.castling_rights = b.castling_rights & ~CASTLING_RIGHTS_BLACK_KINGSIDE
        end
    end
    if sqr_dest == SQUARE_A1      b.castling_rights = b.castling_rights & ~CASTLING_RIGHTS_WHITE_QUEENSIDE
    elseif sqr_dest == SQUARE_H1  b.castling_rights = b.castling_rights & ~CASTLING_RIGHTS_WHITE_KINGSIDE
    elseif sqr_dest == SQUARE_A8  b.castling_rights = b.castling_rights & ~CASTLING_RIGHTS_BLACK_QUEENSIDE
    elseif sqr_dest == SQUARE_H8  b.castling_rights = b.castling_rights & ~CASTLING_RIGHTS_BLACK_KINGSIDE
    end

    # castling - move rook in addition to the king
    if m.castling > 0
        if sqr_dest == SQUARE_C1
            rook_sqr_src = ~square(b.game_queen_rook_starting_column, 1)
            rook_sqr_dest = SQUARE_D1  # for both chess and chess960
            b.rooks = (b.rooks & rook_sqr_src) | rook_sqr_dest
            b.white_pieces = (b.white_pieces & rook_sqr_src)  | rook_sqr_dest
        elseif sqr_dest == SQUARE_G1
            rook_sqr_src = ~square(b.game_king_rook_starting_column, 1)
            rook_sqr_dest = SQUARE_F1  # for both chess and chess960
            b.rooks = (b.rooks & rook_sqr_src) | rook_sqr_dest
            b.white_pieces = (b.white_pieces & rook_sqr_src) | rook_sqr_dest
        elseif sqr_dest == SQUARE_C8
            rook_sqr_src = ~square(b.game_queen_rook_starting_column, 8)
            rook_sqr_dest = SQUARE_D8  # for both chess and chess960
            b.rooks = (b.rooks & rook_sqr_src) | rook_sqr_dest
            b.black_pieces = (b.black_pieces & rook_sqr_src) | rook_sqr_dest
        elseif sqr_dest == SQUARE_G8
            rook_sqr_src = ~square(b.game_king_rook_starting_column, 8)
            rook_sqr_dest = SQUARE_F8  # for both chess and chess960
            b.rooks = (b.rooks & rook_sqr_src) | rook_sqr_dest
            b.black_pieces = (b.black_pieces & rook_sqr_src) | rook_sqr_dest
        end
    end

    if b.side_to_move == WHITE
        b.side_to_move = BLACK
    elseif b.side_to_move == BLACK
        b.side_to_move = WHITE
    end

    board_validation_checks(b)

                                    increment_ply_count(b.game_movelist)

    nothing
end

"Return true if side to move's king is in check"
function is_king_in_check_original(b::Board)
    # generate enemies attacking moves
    b.side_to_move = opposite_color(b.side_to_move)
    moves = generate_moves(b, checking_for_pins=false)
    b.side_to_move = opposite_color(b.side_to_move)

    # check if any enemy piece can capture the king
    kings_square = b.kings & (b.side_to_move==WHITE ? b.white_pieces : b.black_pieces)
    for m in moves
        if m.sqr_dest == kings_square
            return true  # king taken!
        end
    end
    return false
end

"Return true if side to move's king is in check"
function is_king_in_check(b::Board)
    # generate enemies attacking moves
    b.side_to_move = opposite_color(b.side_to_move)
    moves = generate_moves(b)
    b.side_to_move = opposite_color(b.side_to_move)

    # check if any enemy piece can capture the king
    kings_square = b.kings & (b.side_to_move==WHITE ? b.white_pieces : b.black_pieces)
    for m in moves
        if m.sqr_dest == kings_square
            return true  # king taken!
        end
    end
    return false
end

"Undo move on board"
function unmake_move!(b::Board, m::Move, prior_castling_rights, prior_last_move_pawn_double_push)
    #println("unmake_move($m)")

    assert(m.sqr_src > 0)
    assert(m.sqr_dest > 0)
    assert(piece_type_on_sqr(b, m.sqr_src)==NONE)
    assert(piece_color_on_sqr(b, m.sqr_src)==NONE)

    decrement_ply_count(b.game_movelist)

    sqr_src = m.sqr_src
    sqr_dest = m.sqr_dest
    color = m.color_moving
    moving_piece = m.piece_moving
    taken_piece = m.piece_taken

    # undo any pawn promotion
    if m.promotion_to != NONE
        b.pawns = b.pawns | sqr_dest
        if m.promotion_to == QUEEN       b.queens = b.queens & ~sqr_dest
        elseif m.promotion_to == KNIGHT  b.knights = b.knights & ~sqr_dest
        elseif m.promotion_to == ROOK    b.rooks = b.rooks & ~sqr_dest
        elseif m.promotion_to == BISHOP  b.bishops = b.bishops & ~sqr_dest
        end
        #if color == WHITE      b.white_pieces = b.white_pieces & ~sqr_dest
        #elseif color == BLACK  b.black_pieces = b.black_pieces & ~sqr_dest
        #end # this is done below
    end

    # move the moving piece (remove from dest, add to src)
    if moving_piece == KING         b.kings =   (b.kings & ~sqr_dest) | sqr_src
    elseif moving_piece == QUEEN    b.queens =  (b.queens & ~sqr_dest) | sqr_src
    elseif moving_piece == ROOK     b.rooks =   (b.rooks & ~sqr_dest) | sqr_src
    elseif moving_piece == BISHOP   b.bishops = (b.bishops & ~sqr_dest) | sqr_src
    elseif moving_piece == KNIGHT   b.knights = (b.knights & ~sqr_dest) | sqr_src
    elseif moving_piece == PAWN     b.pawns =   (b.pawns & ~sqr_dest) | sqr_src
    end
    # update the moving color (remove from dest, add to src)
    if color==WHITE
        b.white_pieces = (b.white_pieces & ~sqr_dest) | sqr_src
    else
        b.black_pieces = (b.black_pieces & ~sqr_dest) | sqr_src
    end

    # TODO: switch to XOR for simplicity? speed   Also calculated src | dest once

    # add back any piece taken square
    if taken_piece != NONE
        if taken_piece == KING    b.kings = b.kings | sqr_dest  end
        if taken_piece == QUEEN   b.queens = b.queens | sqr_dest  end
        if taken_piece == ROOK    b.rooks = b.rooks | sqr_dest  end
        if taken_piece == BISHOP  b.bishops = b.bishops | sqr_dest  end
        if taken_piece == KNIGHT  b.knights = b.knights | sqr_dest  end
        if taken_piece == PAWN && m.sqr_ep == 0  b.pawns = b.pawns | sqr_dest  end
        if color==WHITE           b.black_pieces = b.black_pieces | sqr_dest
        else                      b.white_pieces = b.white_pieces | sqr_dest
        end
    end

    # restore en passant marker
    b.last_move_pawn_double_push = prior_last_move_pawn_double_push

    # en passant - replace any pawn taken by en passant
    if m.sqr_ep != 0
        b.pawns = b.pawns | m.sqr_ep
        if color==WHITE  b.black_pieces = b.black_pieces | m.sqr_ep
        else             b.white_pieces = b.white_pieces | m.sqr_ep
        end
    end

    # castling - move rook in addition to the king
    if m.castling > 0
        if sqr_dest == SQUARE_C1
            rook_sqr_src = square(b.game_queen_rook_starting_column, 1)
            b.rooks = (b.rooks | rook_sqr_src) & ~SQUARE_D1
            b.white_pieces = (b.white_pieces | rook_sqr_src) & ~SQUARE_D1
        elseif sqr_dest == SQUARE_G1
            rook_sqr_src = square(b.game_king_rook_starting_column, 1)
            b.rooks = (b.rooks | rook_sqr_src) & ~SQUARE_F1
            b.white_pieces = (b.white_pieces | rook_sqr_src) & ~SQUARE_F1
        elseif sqr_dest == SQUARE_C8
            rook_sqr_src = square(b.game_queen_rook_starting_column, 8)
            b.rooks = (b.rooks | rook_sqr_src) & ~SQUARE_D8
            b.black_pieces = (b.black_pieces | rook_sqr_src) & ~SQUARE_D8
        elseif sqr_dest == SQUARE_G8
            rook_sqr_src = square(b.game_king_rook_starting_column, 8)
            b.rooks = (b.rooks | rook_sqr_src) & ~SQUARE_F8
            b.black_pieces = (b.black_pieces | rook_sqr_src) & ~SQUARE_F8
        end
    end

    # restore castling rights
    b.castling_rights = prior_castling_rights

    # change back the side to move
    b.side_to_move = opposite_color(b.side_to_move)

    board_validation_checks(b)

    nothing
end
