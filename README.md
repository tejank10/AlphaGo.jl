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
Training is done using `train()` method. `train()` method is used by the user to train the model based on the following parameters:
- `env`
- `num_games`: Number of self-play games to be played
Optional arguments:
- `memory_size`: Size of the memory buffer
- `batch_size`
- `epochs`: Number of epochs to train the data on
- `ckp_freq`: Frequecy of saving the model and weights
- `tower_height`: AlphaGo Zero Architecture uses residual networks stacked together. This is called a tower of residual networks. `tower_height` specifies how many residual blocks to be stacked.
- `model`: Object of type `NeuralNet`
- `readouts`: number of readouts by `MCTSPlayer`
- `start_training_after`: Number of games after which training will be started

The network can be tested to play against humans by using the `play()` method. `play()` takes following arguments:
- `env`
- `nn`: an object of type `NeuralNet`
- `tower_height`
- `num_readouts`
- `mode`: It specifies human will play as Black or white. If `mode` is 0 then human is Black, else White.

