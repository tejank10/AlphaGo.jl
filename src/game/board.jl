#=
This is Julia implementation of Go Board by Tejan Karmali.
Original Python version of the implementation of Go by
Brian Lee (https://github.com/brilee/MuGo/blob/master/go.py)
=#

WHITE, EMPTY, BLACK, FILL, KO, UNKNOWN = collect(-1:4)

struct IllegalMove <:Exception end

mutable struct Board
  n::Int
  all_coords::Array{NTuple{2, Int}, 1}
  board::Array{Int, 2}
  neighbors::Dict{NTuple{2, Int}, Array{NTuple{2, Int}, 1}}
  diagonals::Dict{NTuple{2, Int}, Array{NTuple{2, Int}, 1}}

  function Board(n::Int = 9)
    n ∈ (9, 13, 17, 19) || error("Illegal board size $n")

    all_coords = [(i, j) for i = 1:n for j = 1:n]
    board = zeros(Int, n, n)

    check_bounds(c) = 1 <= c[1] <= n && 1 <= c[2] <= n

    neighs = Dict((x, y) => filter(k->check_bounds(k), [(x+1, y), (x-1, y), (x, y+1), (x, y-1)]) for (x, y) in all_coords)
    diags = Dict((x, y)=> filter(k->check_bounds(k), [(x+1, y+1), (x+1, y-1), (x-1, y+1), (x-1, y-1)]) for (x, y) in all_coords)

    new(n, all_coords, board, neighs, diags)
  end
end

function place_stones(b::Board, color, stones)
  for s in stones
    b.board[s] = color
  end
end

#TODO: type of c
function find_reached(b::Board, c)
  color = board[c...]
  chain = Set([c])
  reached = Set()
  frontier = [c]
  while frontier
    current = pop!(frontier)
    push!(chain, current)
    for n in b.neighbors[current...]
      if board[n...] == color && n ∉ chain
        push!(frontier, n)
      elseif board[n...] != color
        push!(reached, n)
      end
    end
  end
  return (chain, reached)
end

function is_koish(b::Board, c)
  # Check if c is surrounded on all sides by 1 color, and return that color
  if b.board[c...] != EMPTY return nothing end

  neighs = [b.board[n...] for n in b.neighbours[c...]]
  if length(neighs) == 1 && EMPTY ∉ neighs
    return neighs[1]
  else
    return nothing
  end
end

function is_eyeish(b::Board, c)
  # Check if c is an eye, for the purpose of restricting MC rollouts.
  color = is_koish(board, c)
  if color == nothing
    return nothing
  end

  diag_faults = 0
  diag = b.diagonals[c...]
  if length(diag) < 4
    diag_faults += 1
  end

  for d in diag
    if board[d...] ∉ (color, EMPTY)
      diag_faults += 1
    end
  end
  if diag_faults > 1
    return nothing
  else
    return color
  end
end
