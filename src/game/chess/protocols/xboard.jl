# xboard.jl - protocol

"Reads string from STDIN"
function xboard_readline()
    r = readline()
    #=
    io = open("Chess.readline.txt", "a")
    print(io, r)
    close(io)
    =#
    r
end

"Writes string to STDOUT"
function xboard_writeline(msg::String)
    nchar = write(STDOUT, String(msg*"\n"))
    flush(STDOUT)
    #=
    io = open("Chess.writeline.txt", "a")
    print(io, "$nchar\t$msg\n")
    close(io)
    =#
end

"Plays a game over xboard protocol"
function xboard_loop()
    chess_engine_debug_mode = true
    chess_engine_show_thinking = true
    opponent_is_computer = false
    force_mode = false
    my_time = Inf
    opp_time = Inf
    ply = 2

    board = new_game()
    while true
        r = xboard_readline()
        tokens = split(r)

        if "xboard" ∈ tokens
            xboard_writeline("")
        end

        if "protover" ∈ tokens
            xboard_writeline("tellics say     $version")
            xboard_writeline("tellics say     by $author")
            xboard_writeline("feature myname=\"$(version)\"")
            xboard_readline()
            # request xboard send moves to the engine with the command "usermove MOVE"
            xboard_writeline("feature usermove=1")
            xboard_readline()
            # use the protocol's new "setboard" command to set up positions
            xboard_writeline("feature setboard=1")
            xboard_readline()
            # tell xboard we are not gnuchess (section 8 of ref), don't kill us
            xboard_writeline("feature sigint=0")
            xboard_readline()
            # allow xboard to synchronize with us
            xboard_writeline("feature ping=1")
            xboard_readline()
            # don't use obsolete "colors" command
            xboard_writeline("feature colors=0")
            xboard_readline()
            # specify options that we can change in the user interface
            xboard_writeline("feature option=\"Depth -spin $ply 0 4\"")
            xboard_readline()
            # specify that we can play chess960
            xboard_writeline("feature variants=fischerandom")
            xboard_readline()
            # done sending commands
            xboard_writeline("feature done=1")
            xboard_readline()
        end

        if "new" ∈ tokens
            board = new_game()
        end

        if "quit" ∈ tokens
            quit() # the julia REPL
        end

        if "post" ∈ tokens
            chess_engine_show_thinking = true
        end

        if "ping" ∈ tokens
            xboard_writeline("pong $(tokens[2])")
        end

        if "computer" ∈ tokens
            opponent_is_computer = true
        end

        if "nopost" ∈ tokens
            chess_engine_show_thinking = false
        end

        if "time" ∈ tokens
            my_time = parse(tokens[2])
        end

        if "otim" ∈ tokens
            opp_time = parse(tokens[2])
        end

        if "force" ∈ tokens
            force_mode = true
        end

        if "go" ∈ tokens
            force_mode = false
            # send xboard reply move
            score, move, pv, nodes, time_s = best_move_search(board, ply)
            if chess_engine_show_thinking
                score = evaluate(board)
                xboard_writeline("\t $ply\t $score\t $time_s\t $nodes\t $(long_algebraic_format(pv))")
            end
            if move!=nothing
                bestmovestr = long_algebraic_format(move)
                xboard_writeline("move $bestmovestr")
                make_move!(board, move)
            end
        end

        if "usermove" ∈ tokens
            # translate and make user's move
            movestr = tokens[2]
            make_move!(board, String(movestr))

            if force_mode==false
                # think of best reply
                score, move, pv, nodes, time_s = best_move_search(board, ply)
                if chess_engine_show_thinking
                    xboard_writeline("\t $ply\t $score\t $time_s\t $nodes\t $(long_algebraic_format(pv))")
                end
                if move!=nothing
                    bestmovestr = long_algebraic_format(move)
                    xboard_writeline("move $bestmovestr")
                    make_move!(board, move)
                end
            end
        end

        if "option" ∈ tokens
            if startswith(tokens[2], "Depth=")
                ply = parse(tokens[2][7:end])
            end
        end
    end
end
