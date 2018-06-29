# Orientation of the board matters in chess
get_feats(pos::ChessPosition)

function get_plane(pieces::UInt64)
  plane = zeros(Float32, 8,8)
  for r in 8:-1:1
    for c in 1:8
      sqr = square(c,r)
      plane[9-r, c] = (pieces & sqr) > 0 ? 1 : 0
    end
  end
  return plane
end

function reverse_board!(x::Array{T, 2}) where T
  @assert size(x, 1) == size(x, 2)

  for r = 1:size(x, 1)÷2
    for c = 1:size(x, 2)
      x[r,c], x[9-r,c] = x[9-r,c], x[r,c]
    end
  end
  return x
end

function chess_piece_features(b::Board, to_play)
  white_king = get_plane(b.white_pieces & b.kings)
  white_queen = get_plane(b.white_pieces & b.queens)
  white_knights = get_plane(b.white_pieces & b.knights)
  white_bishops = get_plane(b.white_pieces & b.bishops)
  white_rooks = get_plane(b.white_pieces & b.rooks)
  white_pawns = get_plane(b.white_pieces & b.pawns)
  white_pieces = [white_king, white_queen, white_knights,
                  white_bishops, white_rooks,white_pawns]

  black_king = get_plane(b.black_pieces & b.kings)
  black_queen = get_plane(b.black_pieces & b.queens)
  black_knights = get_plane(b.black_pieces & b.knights)
  black_bishops = get_plane(b.black_pieces & b.bishops)
  black_rooks = get_plane(b.black_pieces & b.rooks)
  black_pawns = get_plane(b.black_pieces & b.pawns)
  black_pieces = [black_king, black_queen, black_knights,
                  black_bishops, black_rooks, black_pawns]

  if to_move == Chess.WHITE
    return vcat(3, white_pieces..., black_pieces...)
  else
    white_pieces = reverse_board.(white_pieces)
    black_pieces = reverse_board.(black_pieces)
    return vcat(3, black_pieces..., white_pieces...)
  end
end

function get_feats(pos::ChessPosition)
  b = deepcopy(pos.board)
  feats = zeros(8,8,97,1)

  for i = 1:8
    feats[:,:,(i-1)*12+1:(i-1)*12+12,1] .= chess_piece_features(b, pos.to_play)
    if i < 8 b = deepcopy(pos.history[i]) end
  end

  feats[:, :, end, 1] .= pos.to_play * ones(8,8)
  return feats  
end
