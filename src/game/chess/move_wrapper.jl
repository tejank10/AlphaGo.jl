function to_flat(move::Move)
  flat_move = zeros(8, 8, 73)
  src, dest = nothing, nothing
  for r in 8:-1:1
    for c in 1:8
      sqr = square(c,r)
      src = (move.sqr_src & sqr)>0 ? [c,r]
      dest = (move.sqr_dest & sqr)>0 ? [c,r]
    end
  end

  movement = dest .- src
  # QUEEN MOVES
  if any(movement .== 0)
    dist = abs(sum(movement))
    if movement[2] > 0
      if move.promotion_to == KNIGHT
        flat_move[src[2], src[1], 65] = 1
      elseif move.promotion_to == BISHOP
        flat_move[src[2], src[1], 68] = 1
      elseif move.promotion_to == ROOK
        flat_move[src[2], src[1], 71] = 1
      else
        flat_move[scr[2], src[1], dist] = 1
      end
    elseif movement[2] < 0
      flat_move[src[2], src[1], 4*7+dist] = 1
    elseif movement[1] > 0
      flat_move[src[2], src[1], 2*7+dist] = 1
    elseif movement[1] < 0
      flat_move[src[2], src[1], 6*7+dist] = 1
    end
  elseif abs(movement[1]) == abs(movement[2])
    dist = abs(movement[1])
    if movement[1] > 0 && movement[2] > 0
      if move.promotion_to == KNIGHT
        flat_move[src[2], src[1], 67] = 1
      elseif move.promotion_to == BISHOP
        flat_move[src[2], src[1], 70] = 1
      elseif move.promotion_to == ROOK
        flat_move[src[2], src[1], 73] = 1
      else
        flat_move[scr[2], src[1], 7+dist] = 1
      end
    elseif movement[1] > 0 && movement[2] < 0
      flat_move[src[2], src[1], 3*7+dist] = 1
    elseif movement[1] < 0 && movement[2] < 0
      flat_move[src[2], src[1], 5*7+dist] = 1
    elseif movement[1] < 0 && movement[2] > 0
      if move.promotion_to == KNIGHT
        flat_move[src[2], src[1], 66] = 1
      elseif move.promotion_to == BISHOP
        flat_move[src[2], src[1], 69] = 1
      elseif move.promotion_to == ROOK
        flat_move[src[2], src[1], 72] = 1
      else
        flat_move[scr[2], src[1], 7*7+dist] = 1
      end
    end
  # KNIGHT MOVES
  elseif sum(abs.(movement)) == 3
    if movement[1] == 1 && movement[2] == 2
      flat_move[src[2], src[1], 57] = 1
    elseif movement[1] == 2 && movement[2] == 1
      flat_move[src[2], src[1], 58] = 1
    elseif movement[1] == 2 && movement[2] == -1
      flat_move[src[2], src[1], 59] = 1
    elseif movement[1] == 1 && movement[2] == -2
      flat_move[src[2], src[1], 60] = 1
    elseif movement[1] == -1 && movement[2] == -2
      flat_move[src[2], src[1], 61] = 1
    elseif movement[1] == -2 && movement[2] == -1
      flat_move[src[2], src[1], 62] = 1
    elseif movement[1] == -2 && movement[2] == 1
      flat_move[src[2], src[1], 63] = 1
    elseif movement[1] == -1 && movement[2] == 2
      flat_move[src[2], src[1], 64] = 1
    end
  end

  findmax(flat_move)[2]
end

function to_flat(movestr::string, pos::ChessPosition)
  moves = generate_moves(pos.board)
  users_move = nothing
  for move in moves
    if startswith(movestr,long_algebraic_format(move))
      users_move = move
      break
    end
  end
  to_flat(users_move)
end

function from_flat(move_flat::Int, pos::ChessPosition)
  moves = generate_moves(pos.board)
  for move in moves
    if move_flat == move_encode(move)
      return move
    end
  end
end
