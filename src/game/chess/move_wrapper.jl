function plane_map(movement, promotion)
  direction = (Int(atan2(movement[2], movement[1]) * 180 / π) + 360) % 360 ÷ 45
  dist = sum(abs.(movement)) ÷ (!any(movement .== 0) + 1)
  promo = promotion - 2
  prom_dir = direction - 1
  if 0 ≤ promo ≤ 2 && 0 ≤ prom_dir ≤ 2
    return 65 + promo * 3 + prom_dir
  end
  return direction * 7 + dist
end

function to_flat(move::Move, to_play::Int)
  flat_move = zeros(8, 8, 73)
  knight_plane = Dict([[1,2]=>1, [2,1]=>2, [-1,2]=>3, [-2,1]=>4, [-2,-1]=>5,
                        [-1,-2]=>6, [1,-2]=>7, [2,-1]=>8])
  promotion = move.promotion_to
  src, dest = nothing, nothing
  for r in 8:-1:1
    for c in 1:8
      sqr = square(c,r)

      src = (move.sqr_src & sqr)>0 ? [c,r]:src
      dest = (move.sqr_dest & sqr)>0 ? [c,r]:dest
    end
  end
  movement = -to_play * (dest .- src)
  if to_play == -1
    src[2] = 9 - src[2]
  else
    src[1] = 9 - src[1]
  end
  # QUEEN MOVES
  plane = 0
  if any(movement .== 0) || abs(movement[1]) == abs(movement[2])
    plane = plane_map(movement, promotion)
  # KNIGHT MOVES
  elseif sum(abs.(movement)) == 3
    plane = 56 + knight_plane[movement]
  end
  flat_move[src[2], src[1], plane] = 1
  @assert sum(flat_move) == 1
  findmax(flat_move)[2]
end

to_flat(move::Move, pos::ChessPosition) = to_flat(move::Move, pos.to_play)

function to_flat(movestr::String, pos::ChessPosition)
  users_move = nothing
  for move in pos.moves
    if startswith(movestr,long_algebraic_format(move))
      users_move = move
      break
    end
  end
  to_flat(users_move, pos)
end

function from_flat(move_flat::Int, pos::ChessPosition)
  num_moves = length(pos.moves)
  for move in pos.moves[1:num_moves]
    if move_flat == to_flat(move, pos.to_play)
      return move
    end
  end
  return 0
end
