# do this :
# Pkg.checkout("WebIO", "s/asset-registry")
# Pkg.checkout("Mux", "s/asset-registry")

using AlphaGo
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
    game.update(x)
end)

# function to display messages, eg: Illegal move, YOu won..., not your turn yet etc
onjs(msg, JSExpr.@js x-> begin
    game.showMsg(x)
end)

on(userAction) do x
    println("js sent $x")
    controller["playing"] && return msg[] = "computer's turn!"

    isIllegalMove(x) && return msg[] = "Illegal Move!"

    controller["playing"] = true

    move = playMove(x) # user action
    updateEnv__(x)

    move = playMove()  # computer action
    updateEnv__(stringToAction(go.to_kgs(move), -1))

    controller["playing"] = false

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
    move = suggest_move(controller["model"])
    prinln(go.to_kgs(move))
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
    x = Char(Int('A') + a["x"])
    y = 1 + a["y"]
    return "$(x)$(y)"
end

function stringToAction(s, c)
    a, b = collect(s)
    x = Int(a) - Int('A')
    y = parse(Int, b) - 1
    Dict("x"=>x,"y"=>y,"c"=>c)
end

function updateEnv__(move)
    # js needs { objects:  Array[9*9] } , arrayEle -> empty || {x ,y, c }
    env = Dict()
    pos = get_position(controller["model"])
    board = []
    for i=1:N
        row = []
        for j=1:N
            push!(row, Dict("x"=>j,"y"=>i,c=>board[i, j]))
        end
        push!(board, row)
    end
    env["state"] = Dict("objects"=>board)
    env["action"] = s

    env[] = env
end

colorDict = Dict(1=>"BLACK",-1=>"WHITE")

function isIllegalMove(x)
    AlphaGo.get_position(controller["model"]) == nothing && return true
    !AlphaGo.go.is_move_legal(AlphaGo.get_position(controller["model"]), go.from_kgs(actionToString(x)))
end

startGame()
