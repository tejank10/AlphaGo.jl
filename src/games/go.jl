#=
This is Julia implementation of Go Board by Tejan Karmali.
Reference: Python version of the implementation of Go by
(https://github.com/tensorflow/minigo)
=#

import Base: ==, deepcopy, show
using IterTools.Iterators: flatten
using Printf: @sprintf
# Cell occupants
#@enum CELL_OCC WHITE = -1 EMPTY BLACK  FILL KO UNKNOWN

# Represents "group not found" in the LibertyTracker object
MISSING_GROUP_ID = -1

check_bounds(c, N) = 1 <= c[1] <= N && 1 <= c[2] <= N

function neighbors(c, N)
  x, y = c
  filter(k->check_bounds(k, N), [(x+1, y), (x-1, y), (x, y+1), (x, y-1)])
end

function diagonals(c, N)
  x, y = c
  filter(k->check_bounds(k, N), [(x+1, y+1), (x+1, y-1), (x-1, y+1), (x-1, y-1)])
end

struct PlayerMove
  color::Int8
  move
end

function place_stones!(board::Array{Int8, 2}, color, stones)
  for s in stones
    board[s...] = color
  end
end

board(pos::Position) = pos.board

function find_reached(board::Array{Int8, 2}, c)
  color = board[c...]
  chain, reached, frontier = Set([c]), Set(), [c]
  N = size(board, 1)

  while !isempty(frontier)
    current = pop!(frontier)
    push!(chain, current)
    neighs = neighbors(current, N)
    for n in neighs
      if board[n...] == color && n ∉ chain
        push!(frontier, n)
      elseif board[n...] != color
        push!(reached, n)
      end
    end
  end

  chain, reached
end

function is_koish(board::Array{Int8, 2}, c)
  # Check if c is surrounded on all sides by 1 color, and return that color

  EMPTY = 0
  board[c...] != EMPTY && return nothing

  N = size(board, 1)
  neighs_c = neighbors(c, N)
  neighs = Set(board[n...] for n in neighs_c)

  length(neighs) == 1 && EMPTY ∉ neighs ? collect(neighs)[1] : nothing
end

function is_eyeish(board::Array{Int8, 2}, c)
  # Check if c is an eye, for the purpose of restricting MC rollouts.
  EMPTY = 0
  N = size(board, 1)

  color = is_koish(board, c)
  color === nothing && return nothing

  diag_faults = 0
  diag = diagonals(c, N)
  diag_faults += length(diag) < 4 ? 1 : 0

  for d in diag
    diag_faults += board[d...] ∉ (color, EMPTY) ? 1 : 0
  end

  diag_faults > 1 ? nothing : color
end

# making a (x,y) coordinate for board from flattened index x
coordify(x, N = 19) = (1 + (x - 1) % N, 1 + (x - 1) ÷ N)

# returns first `n` 2D arrays along 3rd dimension
get_first_n(x::Array{Int8, 3}, n) = size(x, 3) < n ? x : x[:, :, 1:n]

struct Group
  id::UInt
  stones::Set{NTuple{2, UInt8}}
  liberties::Set{NTuple{2, UInt8}}
  color::Int8
end

==(g1::Group, g2::Group) =
  g1.stones == g2.stones && g1.liberties == g2.liberties && g1.color == g2.color

mutable struct LibertyTracker
  group_index::Array{Int16, 2}
  groups::Dict{Int, Group}
  liberty_cache::Array{UInt8, 2}
  max_group_id::Int16
end

function LibertyTracker(N)
  # group_index: a NxN array of group_ids. -1 means no group
  # groups: a dict of group_id to groups
  # liberty_cache: a NxN array of liberty counts
  group_index = -ones(Int16, N, N)
  groups = Dict{Int, Group}()
  liberty_cache = zeros(UInt8, N, N)
  max_group_id::Int16 = 1

  LibertyTracker(group_index, groups, liberty_cache, max_group_id)
end


function deepcopy(lib_trac::LibertyTracker)
  new_group_index = deepcopy(lib_trac.group_index)
  new_lib_cache = deepcopy(lib_trac.liberty_cache)
  new_groups = Dict{UInt, Group}(
      group.id => Group(group.id, Set(group.stones), Set(group.liberties), group.color)
      for group in values(lib_trac.groups)
  )

  LibertyTracker(new_group_index, new_groups, new_lib_cache, lib_trac.max_group_id)
end

function from_board(board::Array{Int8, 2})
  WHITE, EMPTY, BLACK, FILL = collect(-1:2)
  N = size(board, 1)

  board = deepcopy(board)
  curr_group_id = 0
  lib_tracker = LibertyTracker(N)

  for color ∈ (WHITE, BLACK)
    while color ∈ board
      curr_group_id += 1
      coord_flat = findfirst(x -> x == color, board[:])
      coord = coordify(coord_flat, N)
      chain, reached = find_reached(board, coord)
      liberties = Set(r for r in reached if board[r...] == EMPTY)
      new_group = Group(curr_group_id, chain, liberties, color)
      lib_tracker.groups[curr_group_id] = new_group

      for s in chain
        lib_tracker.group_index[s...] = curr_group_id
      end

      place_stones!(board, FILL, chain)
    end
  end

  lib_tracker.max_group_id = curr_group_id

  liberty_counts = zeros(UInt8, N, N)
  for group in values(lib_tracker.groups)
    num_libs = length(group.liberties)
    for s in group.stones
      liberty_counts[s...] = num_libs
    end
  end
  lib_tracker.liberty_cache = liberty_counts

  return lib_tracker
end

function _merge_from_played!(lib_trac::LibertyTracker, color, played, libs, other_group_ids)
  stones = Set([played])
  liberties = Set{NTuple{2, Int}}(libs)
  for group_id in other_group_ids
    other = pop!(lib_trac.groups, group_id)
    union!(stones, other.stones)
    union!(liberties, other.liberties)
  end

  !isempty(other_group_ids) && setdiff!(liberties, Set([played]))

  @assert setdiff(stones, liberties) == stones

  lib_trac.max_group_id += 1
  result = Group(lib_trac.max_group_id, stones, liberties, color)
  lib_trac.groups[result.id] = result

  for s in result.stones
    lib_trac.group_index[s...] = result.id
    lib_trac.liberty_cache[s...] = length(result.liberties)
  end

  return result
end

function _update_liberties!(lib_trac::LibertyTracker, group_id;
                            add = Set(), remove = Set())

  group = lib_trac.groups[group_id]
  new_libs = setdiff(group.liberties ∪ add, remove)
  lib_trac.groups[group_id] = Group(group_id, group.stones, new_libs, group.color)

  new_lib_count = length(new_libs)
  for s in lib_trac.groups[group_id].stones
    lib_trac.liberty_cache[s...] = new_lib_count
  end
end

function _capture_group!(lib_trac::LibertyTracker, group_id::UInt)
  dead_group = lib_trac.groups[group_id]
  delete!(lib_trac.groups, group_id)

  for s in dead_group.stones
    lib_trac.group_index[s...] = MISSING_GROUP_ID
    lib_trac.liberty_cache[s...] = 0
  end

  return dead_group.stones
end

board_size(lt::LibertyTracker) = size(lt.group_index, 1)

function _handle_captures!(lib_trac::LibertyTracker, captured_stones)
  N = board_size(lib_trac)
  for s in captured_stones
    neighs = neighbors(s, N)
    for n in neighs
      group_id = lib_trac.group_index[n...]
      group_id != MISSING_GROUP_ID && _update_liberties!(lib_trac, group_id; add = Set([s]))
    end
  end
end

function add_stone!(lib_trac::LibertyTracker, color, c)
  @assert lib_trac.group_index[c...] == MISSING_GROUP_ID

  captured_stones = Set()
  opponent_neighboring_group_ids = Set{UInt}()
  friendly_neighboring_group_ids = Set{UInt}()
  empty_neighbors = Set{NTuple{2, UInt8}}()

  N = board_size(lib_trac)
  neighs = neighbors(c, N)

  for n in neighs
    neighbor_group_id = lib_trac.group_index[n...]
    if neighbor_group_id != MISSING_GROUP_ID
      neighbor_group = lib_trac.groups[neighbor_group_id...]
      if neighbor_group.color == color
        push!(friendly_neighboring_group_ids, neighbor_group_id)
      else
        push!(opponent_neighboring_group_ids, neighbor_group_id)
      end
    else
      push!(empty_neighbors, n)
    end
  end

  new_group = _merge_from_played!(lib_trac, color, c, empty_neighbors,
                                  friendly_neighboring_group_ids)

  # new_group becomes stale as _update_liberties and
  # _handle_captures are called; must refetch with lib_trac.groups[new_group.id]
  for group_id in opponent_neighboring_group_ids
    neighbor_group = lib_trac.groups[group_id]
    if length(neighbor_group.liberties) == 1
      captured = _capture_group!(lib_trac, group_id)
      union!(captured_stones, captured)
    else
      _update_liberties!(lib_trac, group_id; remove = Set([c]))
    end
  end
  _handle_captures!(lib_trac, captured_stones)

  # suicide is illegal
  length(lib_trac.groups[new_group.id].liberties) == 0 && throw(IllegalMove())

  return captured_stones
end

mutable struct GoPosition <: Position
  #=
  board: an array representing board
  planes: Number of planes for neural network training
  n: moves played so far
  komi: points given to the second player.
  caps: captures for B, W.
  lib_tracker: a LibertyTracker object
  ko: a Move
  recent: a tuple of PlayerMoves, such that recent[end] is the last move.
  board_deltas: an array of shape (N, N, n) representing changes
      made to the board at each move (played move and captures).
      Should satisfy next_pos.board - next_pos.board_deltas[:, :, 0] == pos.board
  to_play: BLACK or WHITE
  =#

  board::Array{Int8, 2}
  planes::UInt8
  n::Int
  komi::Float32
  caps::NTuple{2, Int}
  lib_tracker::LibertyTracker
  ko
  recent::Vector{PlayerMove}
  board_deltas::Array{Int8, 3}
  to_play::Int
  done::Bool
end

function GoPosition(N = 19, planes = 8; board = nothing, n = 0, komi = 7.5,
  caps = (0, 0), lib_tracker = nothing, ko = nothing,
  recent = Vector{PlayerMove}(), board_deltas = nothing, to_play = 1)

  board === nothing && (board = zeros(Int8, N, N))
  lib_tracker === nothing && (lib_tracker = from_board(board))
  board_deltas === nothing && (board_deltas = zeros(Int8, N, N, 0))
  done = false

  if length(recent) > 1 && recent[end-1].move==recent[end-1].move &&
     recent[end-1].move === nothing
     done = true
  end

  GoPosition(board, planes, n, komi, caps, lib_tracker, ko,
             recent, board_deltas, to_play, done)
end

function deepcopy(pos::GoPosition)
  new_board = deepcopy(pos.board)
  new_lib_tracker = deepcopy(pos.lib_tracker)
  new_recent = deepcopy.(pos.recent)
  GoPosition(new_board, pos.planes, pos.n, pos.komi, pos.caps, new_lib_tracker,
             pos.ko, new_recent, pos.board_deltas, pos.to_play, pos.done)
end

board_size(pos::GoPosition) = size(pos.board, 1)

function action_space(pos::GoPosition)
  N = board_size(pos)
  return 1:N^2+1
end

max_action_space(pos::GoPosition) = 1:362

function show(io::IO, pos::GoPosition)
  WHITE, EMPTY, BLACK, FILL, KO, UNKNOWN = collect(-1:4)
  pretty_print_map = Dict{Int, String}([
             WHITE => "O",
             EMPTY => ".",
             BLACK => "X",
             FILL  => "#",
             KO    => "*"
        ])
  board = deepcopy(pos.board)
  N = board_size(pos)

  captures = pos.caps
  pos.ko === nothing || place_stones!(board, KO, [pos.ko])

  raw_board_contents = []
  for i = 1:N
    row = []
    for j = 1:N
      appended = !isempty(pos.recent) && (i, j) == pos.recent[end].move ? "<" : " "
      push!(row, pretty_print_map[board[i,j]] * appended)
    end
    push!(raw_board_contents, join(row))
  end

  row_labels_fmt = [@sprintf("%2d ", i) for i = N:-1:1]
  row_labels = [string(i) for i = N:-1:1]
  annotated_board_contents = [join(r) for r in zip(row_labels_fmt, raw_board_contents, row_labels)]
  header_footer_rows = ["   " * join("ABCDEFGHJKLMNOPQRST"[1:N], " ") * "   "]
  annotated_board = join(collect(flatten((header_footer_rows, annotated_board_contents,
                                        header_footer_rows))), "\n")
  details = "\nMove: $(pos.n). Captures X: $(captures[1]) O: $(captures[2])\n"
  turn = pos.done ? "GAME OVER\n" : "To Play: " * (pos.to_play == BLACK ? "X(BLACK)\n" : "O(WHITE)\n")
  print(annotated_board * details * turn)
end

function is_move_suicidal(pos::GoPosition, move)
  potential_libs = Set()
  N = board_size(pos)
  neighs = neighbors(move, N)

  for n in neighs
    neighbor_group_id = pos.lib_tracker.group_index[n...]
    # at least one liberty after playing here, so not a suicide
    neighbor_group_id == MISSING_GROUP_ID && return false

    neighbor_group = pos.lib_tracker.groups[neighbor_group_id...]
    if neighbor_group.color == pos.to_play
      union!(potential_libs, neighbor_group.liberties)
    elseif length(neighbor_group.liberties) == 1
      # would capture an opponent group if they only had one lib.
      return false
    end
  end
  # it's possible to suicide by connecting several friendly groups
  # each of which had one liberty.
  setdiff!(potential_libs, Set([move]))
  return isempty(potential_libs)
end

function is_move_legal(pos::GoPosition, move)
  # Checks that a move is on an empty space, not on ko, and not suicide
  move === nothing && return true
  EMPTY = 0
  pos.board[move...] != EMPTY && return false
  move == pos.ko && return false
  is_move_suicidal(pos, move) && return false
  return true
end

function legal_moves(pos::GoPosition)
  # Returns an array of size N² + 1, with 1 = legal, 0 = illegal
  # by default, every move is legal
  EMPTY = 0
  N = board_size(pos)
  legal_mvs = ones(Int8, N, N)
  # ...unless there is already a stone there
  legal_mvs[pos.board .!= EMPTY] .= 0
  # calculate which spots have 4 stones next to them
  # padding is because the edge always counts as a lost liberty.
  adjacent = ones(Int8, N + 2, N + 2)
  adjacent[2:end - 1, 2:end - 1] = abs.(pos.board)
  num_adjacent_stones = adjacent[1:end - 2, 2:end - 1] .+ adjacent[2:end - 1, 1:end - 2] .+
                        adjacent[3:end, 2:end - 1] .+ adjacent[2:end - 1, 3:end]
  # Surrounded spots are those that are empty and have 4 adjacent stones.
  surrounded_spots = (pos.board .== EMPTY) .* (num_adjacent_stones .== 4)
  # Such spots are possibly illegal, unless they are capturing something.
  # Iterate over and manually check each spot.
  for c in findall(x -> x != 0, surrounded_spots[:])
    coord = coordify(c, N)
    is_move_suicidal(pos, coord) && (legal_mvs[coord...] = 0)
  end

  # ...and retaking ko is always illegal
  pos.ko === nothing || (legal_mvs[pos.ko...] = 0)

  # and pass is always legal
  return vcat(legal_mvs[:], [1])
end

function pass_move!(pos::GoPosition; mutate::Bool = false)
  new_pos = mutate ? pos : deepcopy(pos)
  new_pos.n += 1

  N = board_size(pos)

  push!(new_pos.recent, PlayerMove(new_pos.to_play, nothing))
  new_pos.board_deltas = cat(dims=3, zeros(Int8, N, N, 1),
                        get_first_n(new_pos.board_deltas, new_pos.planes - 2))
  new_pos.to_play *= -1
  new_pos.ko = nothing

  if length(new_pos.recent) > 1 && new_pos.recent[end - 1].move === nothing
    new_pos.done = true
  end

  return new_pos
end

function flip_playerturn!(pos::GoPosition; mutate::Bool = false)
  new_pos = mutate ? pos : deepcopy(pos)
  new_pos.ko = nothing
  new_pos.to_play *= -1
  return new_pos
end

get_liberties(pos::GoPosition) = pos.lib_tracker.liberty_cache

function play_move!(pos::GoPosition, c; color = nothing, mutate::Bool = false)
  # Obeys CGOS Rules of Play. In short:
  # No suicides
  # Chinese/area scoring
  # Positional superko (this is very crudely approximate at the moment.)
  color === nothing && (color = pos.to_play)
  EMPTY, BLACK = 0, 1
  new_pos = mutate ? pos : deepcopy(pos)

  #@assert !new_pos.done

  if c === nothing
    new_pos = pass_move!(new_pos; mutate = mutate)
    return new_pos
  end

  !is_move_legal(pos, c) && throw(IllegalMove())

  potential_ko = is_koish(new_pos.board, c)

  place_stones!(new_pos.board, color, [c])
  captured_stones = add_stone!(new_pos.lib_tracker, color, c)
  place_stones!(new_pos.board, EMPTY, captured_stones)

  opp_color = -color

  N = board_size(pos)

  new_board_delta = zeros(Int8, N, N)
  new_board_delta[c...] = color
  place_stones!(new_board_delta, color, captured_stones)

  if length(captured_stones) == 1 && potential_ko == opp_color
    new_ko = collect(captured_stones)[1]
  else
    new_ko = nothing
  end

  if new_pos.to_play == BLACK
    new_caps = (new_pos.caps[1] + length(captured_stones), new_pos.caps[2])
  else
    new_caps = (new_pos.caps[1], new_pos.caps[2] + length(captured_stones))
  end

  new_pos.n += 1
  new_pos.caps = new_caps
  new_pos.ko = new_ko
  push!(new_pos.recent, PlayerMove(color, c))

  # keep a rolling history of last 7 deltas - that's all we'll need to
  # extract the last 8 board states.

  new_pos.board_deltas = cat(dims = 3, reshape(new_board_delta, N, N, 1),
			                   get_first_n(new_pos.board_deltas, new_pos.planes-2))
  new_pos.to_play *= -1

  return new_pos
end

function score(pos::GoPosition)
  # Return score from B perspective. If W is winning, score is negative.
  WHITE, EMPTY, BLACK, FILL, KO, UNKNOWN = collect(-1:4)

  working_board = deepcopy(pos.board)
  N = board_size(pos)
  while EMPTY ∈ working_board
    unassigned_spaces = findfirst(x -> x == EMPTY, working_board[:])
    c = coordify(unassigned_spaces, N)
    territory, borders = find_reached(working_board, c)
    border_colors = Set(working_board[b...] for b in borders)

    X_border = BLACK ∈ border_colors
    O_border = WHITE ∈ border_colors

    if X_border && ! O_border
      territory_color = BLACK
    elseif O_border && ! X_border
      territory_color = WHITE
    else
      territory_color = UNKNOWN # dame, or seki
    end
    place_stones!(working_board, territory_color, territory)
  end

  return count(x -> x == BLACK, working_board) -
         count(x -> x == WHITE, working_board) - pos.komi
end

function result(pos::GoPosition)
  points = score(pos)
  points > 0 && return 1 # BLACK wins
  points < 0 && return -1 # WHITE wins
  return 0  # DRAW
end


function result_string(pos::GoPosition; winner = nothing,
                       was_resign::Bool=false)
  points = score(pos)

  if winner == 1
    winner = "B"
  elseif winner == -1
    winner = "W"
  elseif winnner === nothing
    winner = points > 0 ? "B" : "W"
  end

  suffix =  was_resign ? "+R" : @sprintf("+%.1f", abs(points))

  return winner == "W" || winner == "B" ? winner * suffix : "DRAW"
end

function replay_position(pos::GoPosition, result)
  #=
  Wrapper for a GoPosition which replays its history.
  Assumes an empty start position! (i.e. no handicap, and history must be exhaustive.)

  Result must be passed in, since a resign cannot be inferred from position
  history alone.

  for position_w_context in replay_position(position):
    print(position_w_context.position)
  =#

  pos.n == length(pos.recent) || throw(AssertionError("GoPosition history is incomplete"))
  replay_buffer = Vector{PositionWithContext}()
  N = board_size(pos)
  dummy_pos = GoPosition(N, pos.planes; komi = pos.komi)

  for player_move in pos.recent
    color, next_move = player_move.color, player_move.move
    push!(replay_buffer, PositionWithContext(dummy_pos, next_move, result))
    dummy_pos = play_move!(dummy_pos, next_move, color = color)
  end

  return replay_buffer
end

struct Go <: AbstractEnv
  board_data::BoardEnv
  pos::GoPosition
  colors::Dict{String, Int8}
end

function Go(board_size = 19, planes = 17)
  N = board_size
  action_space = N ^ 2 + 1 # plus 1 for pass move
  @assert planes % 2 == 1
  board_env = BoardEnv(N, 1:action_space, 1:362, planes)
  pln = (planes - 1) ÷ 2
  chrome = ["WHITE", "EMPTY", "BLACK", "FILL", "KO", "UNKNOWN"]
  colors = Dict{String, Int8}([col=>i-2 for (i, col) in enumerate(chrome)])

  Go(board_env, GoPosition(N, pln), colors)
end

function Base.show(io::IO, env::Go)
  N, planes = env.board_data.N, env.pos.planes
  print("Go(board size=$N, planes=$planes")
end

init_position(pos::GoPosition) = GoPosition(board_size(pos), pos.planes)
init_position(env::Go) = GoPosition(env.board_data.N, env.board_data.planes)
