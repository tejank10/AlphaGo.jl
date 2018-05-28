# AlphaGo.jl
AlphaGo.jl is pure Julia implementation of AlphaGo Zero using Flux.jl.

## Usage
```
include("PATH_TO_AlphaGo.jl/src/go.jl")
using go
```
Making an environment of Go is simple  
`env = make_env(9)`  
Here 9 is the size of board i.e., a 9x9 board is created.   
```
   A B C D E F G H J  
 9 . . . . . . . . . 9  
 8 . . . . . . . . . 8  
 7 . . . . . . . . . 7  
 6 . . . . . . . . . 6  
 5 . . . . . . . . . 5  
 4 . . . . . . . . . 4  
 3 . . . . . . . . . 3  
 2 . . . . . . . . . 2  
 1 . . . . . . . . . 1  
   A B C D E F G H J  
Move: 0. Captures X: 0 O: 0  
To Play: X(BLACK)  
```  
AlphaGo.jl supports KGS and SGF form of coordinates. By default it is KGS. To make a move, use `step!`  
`step!(env, "A9", show_board = true)`
```
   A B C D E F G H J
 9 X<. . . . . . . . 9
 8 . . . . . . . . . 8
 7 . . . . . . . . . 7
 6 . . . . . . . . . 6
 5 . . . . . . . . . 5
 4 . . . . . . . . . 4
 3 . . . . . . . . . 3
 2 . . . . . . . . . 2
 1 . . . . . . . . . 1
   A B C D E F G H J
Move: 1. Captures X: 0 O: 0
To Play: O(WHITE)
```  
`step!` returns a tuple of input state, action, reward, output state and done, where done is a boolean value indicating whether the game is over. The game is over when there are two successive passes.
