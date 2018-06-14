using AlphaGo


function translate_gtp_color(gtp_color)
  if lowercase(gtp_color) ∈ ["b", "black"] return go.BLACK end
  if lowercase(gtp_color) ∈ ["w", "white"] return go.WHITE end
  throw(error("invalid color $gtp_color")
end


# GTP command handler for basic play commands
mutable struct GTPHandler
  _komi
  _player
  _courtesy_pass

  function GTPHandler(player, courtesy_pass = false)
    new(6.5, player, courtesy_pass)
  end
end

function cmd_boardsize(gtp_handler::GTPHandler, n::Int)
  n == go.N ? nothing : throw(AssertionError("unsupported board size: $n"))
end

cmd_clear_board(gtp_handler::GTPHandler) =
          initialize_game!(gtp_handler._player, go.Position(komi = self._komi))

cmd_komi(gtp_handler::GTPHandler, komi::Float32)
  gtp_handler._komi = komi
  get_position(gtp_handler._player).komi = komi

function cmd_play(gtp_handler::GTPHandler, arg0::String, arg1 = nothing)
  if arg1 == nothing
    move = arg0
  else
    _accomodate_out_of_turn(gtp_handler, translate_gtp_color(arg0))
    move = arg1
  end
  return play_move!(gtp_handler._player, go.from_kgs(move))
end

function cmd_genmove(gtp_handler::GTPHandler, color = nothing)
  if color is not None:
    self._accomodate_out_of_turn(color)
  end

  if gtp_handler._courtesy_pass
    # If courtesy pass is True and the previous move was a pass, we'll
    # pass too, regardless of score or our opinion on the game.
    pos = get_position(gtp_handler._player)
    if pos.recent && position.recent[end].move == nothing
      return "pass"
    end
  end

  move = suggest_move(gtp_handler._player)
  if gtp_handler._player.should_resign()
    set_result!(gtp_handler._player, -get_position(gtp_handler._player).to_play,
                            was_resign = true)
    return "resign"
  end

  play_move(gtp_handler._player, move)
  if gtp_handler._player.root.is_done()
    set_result!(result(get_position(gtp_handler._player)), was_resign = false)
  end
  return go.to_kgs(move)
end

cmd_undo(get_position(gtp_handler) = throw(error("Not Implemented"))

cmd_final_score(gtp_handler) = gtp_handler._player.result_string

function _accomodate_out_of_turn(gtp_handler::GTPHandler, color::String)
  pos = get_position(gtp_handler._player)
  if translate_gtp_color(color) != pos.to_play
    flip_playerturn!(pos; mutate = true)
  end
end

mutable struct KGSHandler
  _player
end

function cmd_showboard(kgs_handler::KGSHandler)
  println("\n\n" * string(get_position(kgs_handler._player)) * "\n\n")
  return true
end
