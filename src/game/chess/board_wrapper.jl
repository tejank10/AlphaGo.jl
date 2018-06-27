import Base: -

function -(b1::Board, b2::Board)
  white_pieces = b1.white_pieces - b2.white_pieces
  black_pieces = b1.black_pieces - b2.black_pieces
  kings = b1.kings - b2.kings
  queens = b1.queens - b2.queens
  rooks = b1.rooks - b2.rooks
  bishops = b1.bishops - b2.bishops
  knights = b1.knights - b2.knights
  pawns = b1.pawns - b2.pawns
  side_to_move = b1.side_to_move - b2.side_to_move
  castling_rights = b1.castling_moves - b2.castling_rights
  last_move_pawn_double_push = b1.last_move_pawn_double_push - b2.last_move_pawn_double_push

  game_chess960 = b1.game_chess960 $ b2.game_chess960
  game_kings_starting_column = b1.game_kings_starting_column - b2.game_kings_starting_column
  game_queen_rook_starting_column = b1.game_queen_rook_starting_column - b2.game_queen_rook_starting_column
  game_king_rook_starting_column = b1.game_king_rook_starting_column - b2.game_king_rook_starting_column
  game_zobrist = b1.game_zobrist - b2.game_zobrist
  game_movelist = b1.game_movelist - b2.game_movelist

  Board(white_pieces, black_pieces, kings, queens, rooks, bishops, knights, pawns,
   side_to_move, castling_rights, last_move_pawn_double_push, game_chess960,
   game_kings_starting_column, game_queen_rook_starting_column,
   game_king_rook_starting_column, game_zobrist, game_movelist)
end

mutable ChessPosition <: Position
  env::ChessEnv
  board::Board
  n::Int
  score::Float32
  recent::Vector{PlayerMove}
  board_deltas::Array{Board, 3}
  to_play::UInt8
  done::Bool

  function ChessPosition(env::ChessEnv; board = nothing, n = 0,
    recent = Vector{PlayerMove}(), board_deltas = nothing, to_play = NONE)

    b = board != nothing ? board : Board()
    bd = board_deltas != nothing ? board_deltas : zeros(Int8, env.N, env.N, 0)
    new(env, b, n, komi, caps, lib_trac, ko, recent, bd, to_play, false)
  end
end

function all_legal_moves(pos::ChessPosition)
  moves = generate_moves(pos)
  flat_moves = zeros(pos.env.action_space)
  for move in moves
    flat_moves[to_flat(move)] = 1
  end
  return flat_moves
end
