# columns for Go
_KGS_COLUMNS = "ABCDEFGHJKLMNOPQRST"
_SGF_COLUMNS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

# Converts from a board coordinate to a flattened coordinate
to_flat(coord, pos::Position) = to_flat(coord, board_size(pos))
to_flat(coord, N::Int) = coord === nothing ? N * N + 1 :
                                                   N * (coord[2] - 1) + coord[1]

# Converts from a flattened coordinate to a board coordinate
from_flat(f::Integer, pos::Position) = from_flat(f, board_size(pos))
from_flat(f::Integer, N::Int) = f == N ^ 2 + 1 ? nothing :
                        tuple([i + 1 for i in reverse(divrem(f - 1, N))]...)

function from_sgf(sgfc)
  # Interprets coords. aa is top left corner; sa is top right corner
  (sgfc === nothing || sgfc == "") && return nothing

  return (findfirst(isequal(sgfc[2]), _SGF_COLUMNS),
          findfirst(isequal(sgfc[1]), _SGF_COLUMNS))
end

# Converts from a board coordinate to an SGF coordinate
to_sgf(coord) =  coord ===  nothing ? "" :
                                 _SGF_COLUMNS[coord[2]] * _SGF_COLUMNS[coord[1]]

from_kgs(kgsc, pos::Position) = from_kgs(kgsc, board_size(pos))

function from_kgs(kgsc, N)
  # Interprets coords. A1 is bottom left; A9 is top left.
  kgsc == "pass" && return nothing

  kgsc = uppercase(kgsc)
  col = findfirst(isequal(kgsc[1]), _KGS_COLUMNS)
  row_from_bottom = parse(Int, kgsc[2:end])

  return (N - row_from_bottom + 1, col)
end

# Converts from a board coordinate to a KGS coordinate.
to_kgs(coord) = coord === nothing ? "pass" :
                              "$(_KGS_COLUMNS[coord[2]])$(env.N - coord[1] + 1)"
