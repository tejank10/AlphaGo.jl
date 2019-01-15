using AlphaGo


function translate_gtp_color(gtp_color)
  lowercase(gtp_color) ∈ ["b", "black"] && return 1  # BLACK color in Go env
  lowercase(gtp_color) ∈ ["w", "white"] && return -1 # WHITE color in GO env
  throw(error("Invalid color $gtp_color"))
end


# GTP command handler for basic play commands
mutable struct GTPHandler
  _komi
  _player
  _courtesy_pass
end

GTPHandler(player, courtesy_pass = false) = GTPHandler(6.5, player, courtesy_pass)


function cmd_boardsize(gtp_handler::GTPHandler, n::Int)
  board_sz = board_size(get_position(gtp_handler._player))
  n == board_sz || throw(AssertionError("Supported board size: $board_sz"))
end

function cmd_clear_board(gtp_handler::GTPHandler)
  pos = get_position(gtp_handler._player)
  if pos ===  nothing
    #TODO: How do you know board size is 9? Handle this case
    env = Go(9)
    initialize_game!(gtp_handler._player, env)
  else
    board_sz, planes = board_size(pos), pos.planes
    #TODO: Save SGF
    initialize_game!(gtp_handler._player,
                     GoPosition(board_size, planes; komi = gtp_handler._komi))
  end
end

function cmd_komi(gtp_handler::GTPHandler, komi)
  gtp_handler._komi = komi
  get_position(gtp_handler._player).komi = komi
end

function cmd_play(gtp_handler::GTPHandler, arg0::String, arg1 = nothing)
  if arg1 === nothing
    move = arg0
  else
    #_accomodate_out_of_turn(gtp_handler, translate_gtp_color(arg0))
    move = arg1
  end
  board_sz = board_size(get_position(gtp_handler._player))
  return play_move!(gtp_handler._player, from_kgs(move, board_sz))
end

function cmd_genmove(gtp_handler::GTPHandler, color = nothing)
  if color != nothing
    _accomodate_out_of_turn(color)
  end

  if gtp_handler._courtesy_pass
    # If courtesy pass is True and the previous move was a pass, we'll
    # pass too, regardless of score or our opinion on the game.
    pos = get_position(gtp_handler._player)
    if !isempty(pos.recent) && position.recent[end].move === nothing
      return "pass"
    end
  end

  move = suggest_move(gtp_handler._player)
  if should_resign(gtp_handler._player)
    set_result!(gtp_handler._player, -get_position(gtp_handler._player).to_play;
                was_resign = true)
    return "resign"
  end

  play_move!(gtp_handler._player, move)
  if is_done(gtp_handler._player.root)
    set_result!(result(get_position(gtp_handler._player)), was_resign = false)
  end
  return to_kgs(move)
end

cmd_undo(get_position(gtp_handler) = throw(error("Not Implemented"))

cmd_final_score(gtp_handler) = gtp_handler._player.result_string

function _accomodate_out_of_turn(gtp_handler::GTPHandler, color::String)
  pos = get_position(gtp_handler._player)
  translate_gtp_color(color) != pos.to_play && flip_playerturn!(pos; mutate = true)
end

mutable struct KGSHandler
  _player
end

function cmd_showboard(kgs_handler::KGSHandler)
  println("\n\n" * string(get_position(kgs_handler._player)) * "\n\n")
  return true
end
