# play.jl


"Count number of legal moves to a given depth"
function perft(board::Board, levels::Integer)
    moves = generate_moves(board)
    if levels<=1
        return length(moves)
    end

    node_count = 0
    prior_castling_rights = board.castling_rights
    prior_last_move_pawn_double_push = board.last_move_pawn_double_push
    for m in moves
        make_move!(board, m)
        node_count = node_count + perft(board, levels-1)
        unmake_move!(board, m, prior_castling_rights, prior_last_move_pawn_double_push)
    end
    return node_count
end

"Print formated move output  1. ♞c3 	♘c6"
function print_move_history(moves::Array{Move,1})
    nmoves = length(moves)
    for (j,move) in enumerate(moves)
        if (j-1)%2==0
            println()
            print("$(floor(Integer,(j+1)/2)). ")
        end
        print(move)
        print(" \t")
    end
end

"Play a random chess game in REPL"
function random_play_both_sides(seed, show_move_history, delay=0.001, board=new_game(), max_number_of_moves=1000)
    srand(seed)
    moves_made = Move[]
    for i in 1:max_number_of_moves
        if show_move_history
            clear_repl()
        end
        println()
        printbd(board)

        if show_move_history
            print_move_history(moves_made)
            println()
        end

        moves = generate_moves(board)
        if length(moves)==0
            break
        end
        r = rand(1:length(moves))
        m = moves[r]

        make_move!(board, m)
        push!(moves_made, m)

        sleep(delay)
    end
end

"Play N random chess games in REPL"
function random_play_both_sides(ngames)
    for random_seed in 1:ngames
        random_play_both_sides(random_seed, true, 0.1)
    end
end

"Start chess game in REPL"
function repl_loop()
    depth = 3          # default, user can change
    board = new_game() # default, user can load FEN, or choose chess960
    game_history = []  # store (move, board) every turn
    moves =
    while true
        clear_repl()
        println()
        printbd(board)
        print_move_history(Move[mb[1] for mb in game_history])
        println()

        moves = generate_moves(board)
        if length(moves)==0
            if is_king_in_check(board)
                println("Checkmate!")
            else
                println("Drawn game.")
            end
            break
        end

        # user chooses next move
        print("Your move (? for help) ")
        movestr = readline()

        if startswith(movestr,"quit") || movestr=="q\n"
            return
        end

        if startswith(movestr,"list") || movestr=="l\n"
            moves = generate_moves(board)
            for (i,m) in enumerate(moves)
                print(algebraic_format(m) * " ")
                if i%10==0
                    println()
                end
            end
            println()
            println("Press <enter> to continue...")
            readline()
            continue
        end

        if startswith(movestr,"go") || movestr=="\n"
            score, move, pv, number_nodes_visited, time_s = best_move_search(board, depth)
            push!(game_history, (move, deepcopy(board)))
            make_move!(board, move)
            continue
        end

        if startswith(movestr,"undo") || movestr=="u\n"
            if length(game_history)==0
                continue
            end
            move, prior_board = pop!(game_history)

            # we could just copy the prior_board, but we use this to test unmake_move!()
            unmake_move!(board, move, prior_board.castling_rights,
                                      prior_board.last_move_pawn_double_push)

            continue
        end

        if startswith(movestr,"new960") || movestr=="n960\n"
            board = new_game_960()
            game_history = []
            continue
        end

        if startswith(movestr,"new") || movestr=="n\n"
            board = new_game()
            game_history = []
            continue
        end

        if startswith(movestr,"fen ")
            fen = movestr[5:end-1]
            @show fen
            board = read_fen(fen)
            game_history = []
            continue
        end

        if startswith(movestr, "divide")
            levels = parse(split(movestr)[2]) - 1
            total_count = 0
            for move in moves
                prior_castling_rights = board.castling_rights
                prior_last_move_pawn_double_push = board.last_move_pawn_double_push
                make_move!(board, move)
                node_count = perft(board, levels)
                unmake_move!(board, move, prior_castling_rights,
                                          prior_last_move_pawn_double_push)

                total_count += node_count
                println("$(long_algebraic_format(move)) $node_count")
            end
            println("Nodes: $total_count")
            println("Moves: $(length(moves))")
            println("Press <enter> to continue...")
            readline()
            continue
        end

        if startswith(movestr, "depth")
            depth = parse(split(movestr)[2])
            println("Depth set to: $depth")
            println("Press <enter> to continue...")
            readline()
            continue
        end

        if startswith(movestr,"analysis") || startswith(movestr,"a ") || startswith(movestr,"a\n")
            function search_and_print(ply)
                score,move,pv,nnodes,time_s = best_move_search(board, ply)
                #println("$ply\t$(round(nnodes/(time_s*1000),2)) kn/s")
                print("$ply\t$(round(nnodes/(time_s*1000),2)) kn/s\t $(round(score,3))\t $(round(time_s,2))\t $nnodes\t $move\t ")
            end
            d = depth
            if length(split(movestr))>1
                d = parse(split(movestr)[2])
            end
            for analysis_depth in 0:d
                @time search_and_print(analysis_depth)
            end
            println("Press <enter> to continue...")
            readline()
            continue
        end

        users_move = nothing
        for move in moves
            if startswith(movestr,long_algebraic_format(move))
                users_move = move
                break
            end
        end

        if users_move==nothing
            println(" type your moves like 'e2e4' or 'h7h8q'")
            println(" type 'list' or 'l' to list legal moves")
            println(" type 'go' or <enter> to have computer move")
            println(" type 'undo' or 'u' to go back a move")
            println(" type 'new' or 'n' to start a new game")
            println(" type 'new960' or 'n960' to start a new chess960 game")
            println(" type 'fen FEN' to load FEN position")
            println(" type 'analysis' or 'a' to analyze position to current depth")
            println(" type 'analysis N' or 'a N' to analyze position to depth N")
            println(" type 'divide N' count nodes from this position")
            println(" type 'depth N' set the plys to look ahead")
            println(" type 'quit' or 'q' to end")
            println()
            println("Press <enter> to continue...")
            readline()
            continue
        end

        push!(game_history, (users_move,deepcopy(board)))
        make_move!(board, users_move)

        # make answering move
        score, move, pv, nodes, time_s = best_move_search(board, depth)
        push!(game_history, (move,deepcopy(board)))
        make_move!(board, move)
    end   # while true
end

"Start chess game in REPL"
function play()   repl_loop()   end
