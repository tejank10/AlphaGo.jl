# do this :
# Pkg.checkout("WebIO", "s/asset-registry")
# Pkg.checkout("Mux", "s/asset-registry")

using AlphaGo
using AlphaGo: go
using WebIO
using JSExpr
using Blink

controller = Dict()
controller["playing"] = false
controller["model"] = nothing

assets = "$(@__DIR__)/assets"

files=[
    "$(assets)/css/style.css"
    "$(assets)/css/wgo.player.css"
    "$(assets)/js/wgo.min.js"
    "$(assets)/js/script.js"]

w = Scope(imports=files)
userAction = Observable(w, "user-action", Dict{String,Any}())
env__ = Observable(w, "env-details", Dict{String,Any}())
msg = Observable(w, "message", "")

board_size = 9

onimport(w, JSExpr.@js () -> begin
    # function to communicate user action to julia
    function action(str)
        $userAction[] = str
    end
    game.action = action

    __init__();

    # set board size
    game.setBoardSize($(board_size));
end)

# function to display state-action pair ( and other details)
onjs(env__, JSExpr.@js x -> begin
    console.log("env change")
    game.update(x)
end)

# function to display messages, eg: Illegal move, YOu won..., not your turn yet etc
onjs(msg, JSExpr.@js x-> begin
    console.log("message: " + x)
    game.showMsg(x)
end)

on(userAction) do x
    controller["playing"] && return msg[] = "computer's turn!"

    isIllegalMove(x) && return

    controller["playing"] = true

    move = playMove(x) # user action
    println("user action...")
    updateEnv__(x)

    sleep(1) # otherwise, it's fast .
    move = playMove()  # computer action
    println("computer action...")
    updateEnv__(stringToAction(go.to_kgs(move), -1))

    controller["playing"] = false

    is_done(controller["model"]) && msg[] = "Game over! " * controller["model"].result_string
end



function startGame()
    # load neural net
    # @load ....

    set_all_params(9)
    agz_nn = NeuralNet(;tower_height=1)
    agz = MCTSPlayer(agz_nn, num_readouts = 64, two_player_mode = true)

    initialize_game!(agz)


    controller["playing"] = false
    controller["model"] = agz


    w(dom"div#demo_wrapper"(
        dom"div#controls"(
            dom"button.pass"("Pass")
        ),
        dom"div#playground"(),
        dom"div.hidden#msg"()))

end

function playMove()
    move = AlphaGo.suggest_move(controller["model"])
    println(go.to_kgs(move))
    play_move!(controller["model"], move)
    return move
end

function playMove(x)
    move = actionToString(x)
    @show move
    play_move!(controller["model"], go.from_kgs(move))
    return move
end

function actionToString(a)
    t = (a["y"], a["x"]) .+ 1
    go.to_kgs(t)
end

function stringToAction(s, c)
    (y, x) = go.from_kgs(s) .- 1
    Dict("x"=>x,"y"=>y,"c"=>c)
end

function updateEnv__(move)
    # js needs { objects:  Array[9*9] } , arrayEle -> empty || {x ,y, c }
    env = Dict()
    pos = AlphaGo.get_position(controller["model"])
    board = []
    if ( pos.board == nothing )
        board = map(i -> map(j-> [], 1:9), 1:9)
    else
        for i=1:board_size
            row = []
            for j=1:board_size
                cont = []
                if pos.board[j, i] == 1 || pos.board[j, i] == -1
                    push!(cont, Dict("x"=>(i - 1),"y"=>(j - 1),"c"=>pos.board[j, i], "type"=>"NORMAL"))
                end
                push!(row, cont)
            end
            push!(board, row)
        end
    end
    env["state"] = Dict("objects"=>board)
    env["action"] = move

    env__[] = env
end

colorDict = Dict(1=>"BLACK",-1=>"WHITE")

function isIllegalMove(x)
    AlphaGo.get_position(controller["model"]) == nothing && return true
    !AlphaGo.go.is_move_legal(AlphaGo.get_position(controller["model"]), go.from_kgs(actionToString(x)))
end

startGame()
