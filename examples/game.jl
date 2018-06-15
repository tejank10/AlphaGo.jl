using AlphaGo
using AlphaGo: go
using Flux
using BSON: @load

# Note:
# do Pkg.checkout("WebIO", "s/asset-registry")
# and Pkg.checkout("Mux", "s/asset-registry")
include("../src/interface.jl")
include("./helpers.jl")

set_all_params(9)

assets = "$(@__DIR__)/assets"
files=[
    "$(@__DIR__)/../lib/interface.js"
    "$(@__DIR__)/../lib/interface.css"
    "$(assets)/css/go.css"
    "$(assets)/css/wgo.player.css"
    "$(assets)/js/wgo.min.js"
    "$(assets)/js/go.js"]

gw = GameWindow(files; config=Dict("boardSize"=>9))
setup(gw) # default setup

# agz_nn = loadNeuralNet()
agz_nn = NeuralNet(;tower_height=1)
agz = MCTSPlayer(agz_nn, num_readouts = 64, two_player_mode = true)

playing = false
isPlaying() = playing
setPlaying(p=true) = (playing = p)

# game play
oninput(gw) do x
    println("js sent $x")
    is_done(agz) && ( return gw.msg[] = "Game over! " * agz.result_string )
    isPlaying() && return gw.msg[] = "computer's turn!"
    isIllegalMove(x) && return gw.msg[] = "Illegal Move"
    setPlaying()

    move = playMove(x) # user action
    println("user action...")
    updateBoard(x)   # this happens kinda late ( along with the next update )
    move = playMove()  # computer action
    println("computer action...")
    updateBoard(stringToAction(go.to_kgs(move), -1))

    setPlaying(false)
    is_done(agz) && ( return gw.msg[] = "Game over! " * agz.result_string )
end

function startGame()
    initialize_game!(agz)
    gw(dom"div#demo_wrapper"(
        dom"div#controls"(
            dom"h1"("Go game"),
            dom"button.pass"("Pass")
        ),
        dom"div#playground"()))
end

startGame()
