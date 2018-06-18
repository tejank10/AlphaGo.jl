include("game/go/go.jl")
using go

abstract type IllegalMove <:Exception end
abstract type Position end
abstract type GameEnv end

Position(env::GoEnv; args...) = GoPosition(env; args...)
