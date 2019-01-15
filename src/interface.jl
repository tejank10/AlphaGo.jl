# TODO: Update this file according to the Game branch
using WebIO
using JSExpr

abstract type AbstractGameWindow end

# general gui for event based games like go, chess etc
# use interface.js and interface.css as well
mutable struct GameWindow <: AbstractGameWindow
 w::WebIO.Scope
 action::WebIO.Observable
 board::WebIO.Observable
 message::WebIO.Observable
 config
end

function GameWindow(imports; actionInit=Dict(), boardInit=Dict(), messageInit="", config=Dict())
 w = Scope(imports=imports)
 action = Observable(w, "action", actionInit)
 board = Observable(w, "board", boardInit)
 message = Observable(w, "message", messageInit)

 GameWindow(w, action, board, message, config)
end

# setup
WebIO.onimport(g::AbstractGameWindow, f = @js () -> begin
 game.config = $(g.config)

 function action(a)
  $(g.action)[] = a
 end
 game.action = action

 __init__()

end) = WebIO.onimport(g.w, f)

# for rendering
(g::GameWindow)(h) = (g.w)(h)
WebIO.render(g::AbstractGameWindow) =
 WebIO.render(g.w)

# input(g) do x -> ... end
# ( to get user input after game.action is invoked )
oninput(f, g::AbstractGameWindow) =
 on(f, g.action)

# to update screen
function update!(g::AbstractGameWindow, x)
 g.board[] = x
end

# to set message
function message(g::AbstractGameWindow, x)
 g.message[] = x
end

# to setup js subscribers and the script to call init
function setup(g::AbstractGameWindow)
 onjs(g.board, @js x -> begin
  game.update(x)
 end)

 onjs(g.message, @js x-> begin
  game.showMsg(x)
 end)

 onimport(g)
end
