# search.jl

"""
Find best move, returns:
    score, best move, principal variation,
    number of nodes visited, time in seconds
"""
function best_move_search(board, depth)
    best_move_alphabeta(board, depth)
    #best_move_negamax(board, depth)
end


function best_move_negamax(board, depth)
    tic()
    moves = generate_moves(board)

    best_value = -Inf
    best_move = nothing
    principal_variation = Move[]
    number_nodes_visited = 0
    prior_castling_rights = board.castling_rights
    prior_last_move_pawn_double_push = board.last_move_pawn_double_push
    for m in moves
        make_move!(board, m)

        value, pv, nnodes = negaMax(board, depth)
        value *= -1
        if best_value < value
            best_value = value
            best_move = m
            principal_variation = pv
        end
        number_nodes_visited += nnodes

        unmake_move!(board, m, prior_castling_rights, prior_last_move_pawn_double_push)
    end
    reverse!(principal_variation)
    best_value, best_move, principal_variation, number_nodes_visited, toq()
end

"Called only by best_move_negamax (no quiescence evaluation)"
function negaMax(board, depth)
    if depth == 0
        return (board.side_to_move==WHITE?1:-1)*evaluate(board), Move[], 1
    end
    max_value = -Inf
    max_move = nothing
    principal_variation = Move[]
    number_nodes_visited = 0
    prior_castling_rights = board.castling_rights
    prior_last_move_pawn_double_push = board.last_move_pawn_double_push
    for m in generate_moves(board)
        make_move!(board, m)
        score, pv, nnodes = negaMax(board, depth - 1 )
        unmake_move!(board, m, prior_castling_rights, prior_last_move_pawn_double_push)
        score *= -1
        if( score > max_value )
            max_value = score
            max_move = m
            principal_variation = pv
        end
        number_nodes_visited += nnodes
    end

    if max_move == nothing
        # no moves available - it is either a draw or a mate
        if is_king_in_check(board)
            max_value = MATE_SCORE + depth  # add depth to define mate in N moves
        else
            max_value = DRAW_SCORE
        end
    else
        push!(principal_variation, max_move)
    end
    max_value, principal_variation, number_nodes_visited
end



"Find best move by alpha-beta algorithm"
function best_move_alphabeta(board, depth)
    tic()
    moves = generate_moves(board)

    best_value = -Inf
    best_move = nothing
    principal_variation = Move[]
    number_nodes_visited = 0
    prior_castling_rights = board.castling_rights
    prior_last_move_pawn_double_push = board.last_move_pawn_double_push
    for m in moves
        make_move!(board, m)
        score, pv, nnodes = αβSearch(board, -Inf, Inf, depth)
        score *= -1
        if best_value < score
            best_value = score
            best_move = m
            principal_variation = pv
        end
        number_nodes_visited += nnodes

        unmake_move!(board, m, prior_castling_rights, prior_last_move_pawn_double_push)
    end

    reverse!(principal_variation)
    best_value, best_move, principal_variation, number_nodes_visited, toq()
end

"Called only by best_move_alphabeta"
function αβSearch(board, α, β, depth)
    if depth == 0
        return quiescence(board, α, β), Move[], 1
    end

    max_move = nothing
    principal_variation = Move[]
    number_nodes_visited = 0
    prior_castling_rights = board.castling_rights
    prior_last_move_pawn_double_push = board.last_move_pawn_double_push
    for m in generate_moves(board)
        make_move!(board, m)
        score, pv, nnodes = αβSearch( board, -β, -α, depth - 1 )
        score *= -1
        unmake_move!(board, m, prior_castling_rights, prior_last_move_pawn_double_push)
        # So at all times when searching, you know that you can do no worse than alpha, and that you can do no better than beta.  Anything outside of these bounds you can ignore.
        if( score >= β )
            # beta is the worst-case scenario for the opponent.
            # If the search finds something that returns a score of beta or better, it's too good, so the side to move is not going to get a chance to use this strategy.
            return β, principal_variation, number_nodes_visited   # fail hard β-cutoff
        end
        if( score > α )
            # alpha, which is the best score that can be forced by some means.
            α = score # α acts like max in MiniMax
            max_move = m
            principal_variation = pv
        end
        number_nodes_visited += nnodes
    end

    if max_move == nothing
        # no legal moves available - it is either a draw or a mate
        if is_king_in_check(board)
            α = MATE_SCORE + depth  # add depth to define mate in N moves
        else
            α = DRAW_SCORE
        end
    else
        push!(principal_variation, max_move)
    end

    α, principal_variation, number_nodes_visited
end


function quiescence(board, α, β)
    score = (board.side_to_move==WHITE?1:-1)*evaluate(board)
    if score >= β
        return β
    end
    if score > α
        α = score
    end

    moves = generate_captures(board)
    prior_castling_rights = board.castling_rights
    prior_last_move_pawn_double_push = board.last_move_pawn_double_push
    for m in moves
        make_move!(board, m)
        score = -quiescence(board, -β, -α)
        unmake_move!(board, m, prior_castling_rights, prior_last_move_pawn_double_push)
        if score >= β
            return β
        end
        if score > α
            α = score
        end
    end
    α
end
