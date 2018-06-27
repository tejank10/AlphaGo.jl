# uci.jl

"Plays a game over UCI protocol"
function uci_loop()
    board = new_game()
    while true
        tokens = split(readline())

        if "uci" ∈ tokens
            println("id name $version")
            println("id author $author")
            println("option")
            println("uciok")
        end

        if "debug" ∈ tokens
            if "debug off" ∈ tokens
                chess_engine_debug_mode = false
            end
            if "debug on" ∈ tokens
                chess_engine_debug_mode = true
            end
        end

        if "isready" ∈ tokens
            println("readyok")
        end

        if "setoption" ∈ tokens
        end

        if "register" ∈ tokens
        end

        if "ucinewgame" ∈ tokens
             board = new_game()
        end

        if "position" ∈ tokens
            if "startpos" ∈ tokens
                board = new_game()
            end
            if "fen" ∈ tokens
                i = indexin(["fen"], tokens)
                fen = tokens[i+1]
                board = read_fen(fen)
            end
            if "moves" ∈ tokens
                i = indexin(["moves"], tokens)[1]
                n = length(tokens)
                for idx in i:n
                    movestr = tokens[idx]
                    moves = generate_moves(board)
                    for m in moves
                        if long_algebraic_format(m)==movestr
                            make_move!(board,m)
                            break
                        end
                    end
                end
            end
        end

        if "go" ∈ tokens
            prior_castling_rights = b.castling_rights
            prior_last_move_pawn_double_push = b.last_move_pawn_double_push
            moves = generate_moves(board)
            multiplier = (board.side_to_move==WHITE ? 1 : -1)
            best_value = -Inf
            best_move = nothing
            for m in moves
                make_move!(board, m)
                value = multiplier*evaluate(board)
                unmake_move!(board, m, prior_castling_rights, prior_last_move_pawn_double_push)
                if best_value < value
                    best_value = value
                    best_move = m
                end
            end

            bestmovestr = long_algebraic_format(best_move)
            println("bestmove $bestmovestr")
        end

        if "stop" ∈ tokens
        end

        if "ponderhit" ∈ tokens
        end

        if "quit" ∈ tokens
            quit() # the julia REPL
        end
    end
end
