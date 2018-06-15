#=
This is Julia implementation of Go Board by Tejan Karmali.
Reference: Python version of the implementation of Go by
(https://github.com/tensorflow/minigo)
=#

import Base: ==, deepcopy, show
using IterTools: chain

# Cell occupants
#@enum CELL_OCC WHITE = -1 EMPTY BLACK  FILL KO UNKNOWN
WHITE, EMPTY, BLACK, FILL, KO, UNKNOWN = collect(-1:4)

# Represents "group not found" in the LibertyTracker object
MISSING_GROUP_ID = -1

struct PlayerMove
  color
  move
end

struct IllegalMove <:Exception end

function set_board_size(n::Int = 19)
  global N, ALL_COORDS, EMPTY_BOARD, NEIGHBORS, DIAGONALS
  #n ∈ (9, 13, 17, 19) || error("Illegal board size $n")
  N = n
  ALL_COORDS = [(i, j) for i = 1:n for j = 1:n]
  EMPTY_BOARD = zeros(Int8, n, n)

  check_bounds(c) = 1 <= c[1] <= n && 1 <= c[2] <= n

  NEIGHBORS = Dict((x, y) => filter(k->check_bounds(k),
                            [(x+1, y), (x-1, y), (x, y+1), (x, y-1)]) for (x, y) in ALL_COORDS)
  DIAGONALS = Dict((x, y) => filter(k->check_bounds(k),
                            [(x+1, y+1), (x+1, y-1), (x-1, y+1), (x-1, y-1)]) for (x, y) in ALL_COORDS)
  nothing
end

function place_stones!(board, color, stones)
  for s in stones
    board[s...] = color
  end
end

function find_reached(board, c)
  color = board[c...]
  chain = Set([c])
  reached = Set()
  frontier = [c]
  while length(frontier) != 0
    current = pop!(frontier)
    push!(chain, current)
    for n in NEIGHBORS[current...]
      if board[n...] == color && n ∉ chain
        push!(frontier, n)
      elseif board[n...] != color
        push!(reached, n)
      end
    end
  end
  return chain, reached
end

function is_koish(board, c)
  # Check if c is surrounded on all sides by 1 color, and return that color
  if board[c...] != EMPTY return nothing end
  neighs = Set(board[n...] for n in NEIGHBORS[c...])
  if length(neighs) == 1 && EMPTY ∉ neighs
    return collect(neighs)[1]
  else
    return nothing
  end
end

function is_eyeish(board, c)
  # Check if c is an eye, for the purpose of restricting MC rollouts.
  color = is_koish(board, c)
  if color == nothing
    return nothing
  end

  diag_faults = 0
  diag = DIAGONALS[c...]
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

# making a (x,y) coordinate for board from flattened index x
coordify(x) = 1 + (x - 1) % N, 1 + (x - 1) ÷ N

get_first_n(x::Array{Int8, 3}, n) = size(x, 3) < n ? x : x[:, :, 1:n]

mutable struct Group
  id::Int
  stones::Set{NTuple{2, Int}}
  liberties::Set{NTuple{2, Int}}
  color::Int
end

function ==(g1::Group, g2::Group)
  return g1.stones == g2.stones && g1.liberties == g2.liberties && g1.color == g2.color
end

mutable struct LibertyTracker
  group_index::Array{Int16, 2}
  groups::Dict{Int, Group}
  liberty_cache::Array{UInt8, 2}
  max_group_id::Int16

  function LibertyTracker(;group_index = nothing, groups = nothing,
    liberty_cache = nothing, max_group_id = 1)
    # group_index: a NxN array of group_ids. -1 means no group
    # groups: a dict of group_id to groups
    # liberty_cache: a NxN array of liberty counts
    grp_idx = group_index != nothing ? group_index : -ones(Int16, N, N)
    grps = groups != nothing ? groups : Dict{Int, Group}()
    lib_cache = liberty_cache != nothing ? liberty_cache : zeros(UInt8, N, N)
    new(grp_idx, grps, lib_cache, max_group_id)
  end
end

function deepcopy(lib_trac::LibertyTracker)
  new_group_index = deepcopy(lib_trac.group_index)
  new_lib_cache = deepcopy(lib_trac.liberty_cache)
  new_groups = Dict{Int, Group}(
      group.id => Group(group.id, Set(group.stones), Set(group.liberties), group.color)
      for group in values(lib_trac.groups)
  )
  return LibertyTracker(
                  group_index = new_group_index,
                  groups = new_groups,
                  liberty_cache = new_lib_cache,
                  max_group_id = lib_trac.max_group_id)
end

function from_board(board)
  board = deepcopy(board)
  curr_group_id = 0
  lib_tracker = LibertyTracker()
  for color ∈ (WHITE, BLACK)
    while color ∈ board
      curr_group_id += 1
      found_color = find(x -> x == color, board)
      coord = coordify(found_color[1])
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

  if !isempty(other_group_ids)
    setdiff!(liberties, Set([played]))
  end

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

function _update_liberties!(lib_trac::LibertyTracker, group_id::Integer;
  add = Set{NTuple{2, Int}}(), remove = Set{NTuple{2, Int}}())

  group = lib_trac.groups[group_id]
  new_libs = setdiff(group.liberties ∪ add, remove)
  lib_trac.groups[group_id] = Group(group_id, group.stones, new_libs, group.color)

  new_lib_count = length(new_libs)
  for s in lib_trac.groups[group_id].stones
    lib_trac.liberty_cache[s...] = new_lib_count
  end
end

function _capture_group!(lib_trac::LibertyTracker, group_id::Integer)
  dead_group = lib_trac.groups[group_id]
  delete!(lib_trac.groups, group_id)
  for s in dead_group.stones
    lib_trac.group_index[s...] = MISSING_GROUP_ID
    lib_trac.liberty_cache[s...] = 0
  end
  return dead_group.stones
end


function _handle_captures!(lib_trac::LibertyTracker, captured_stones)
  for s in captured_stones
    for n in NEIGHBORS[s...]
      group_id = lib_trac.group_index[n...]
      if group_id != MISSING_GROUP_ID
        _update_liberties!(lib_trac, group_id; add = Set([s]))
      end
    end
  end
end

function add_stone!(lib_trac::LibertyTracker, color, c)
  @assert lib_trac.group_index[c...] == MISSING_GROUP_ID
  captured_stones = Set()
  opponent_neighboring_group_ids = Set{Int}()
  friendly_neighboring_group_ids = Set{Int}()
  empty_neighbors = Set{NTuple{2, Int}}()

  for n in NEIGHBORS[c...]
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

  new_group = _merge_from_played!(lib_trac, color, c, empty_neighbors, friendly_neighboring_group_ids)

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
  if length(lib_trac.groups[new_group.id].liberties) == 0
    throw(IllegalMove())
  end

  return captured_stones
end

mutable struct Position
  #=
  board: an array
  n: an int representing moves played so far
  komi: a float, representing points given to the second player.
  caps: a (int, int) tuple of captures for B, W.
  lib_tracker: a LibertyTracker object
  ko: a Move
  recent: a tuple of PlayerMoves, such that recent[end] is the last move.
  board_deltas: an array of shape (N, N, n) representing changes
      made to the board at each move (played move and captures).
      Should satisfy next_pos.board - next_pos.board_deltas[:, :, 0] == pos.board
  to_play: BLACK or WHITE
  =#

  board::Array{Int8, 2}
  n::Int
  komi::Float32
  caps::NTuple{2, Int}
  lib_tracker::LibertyTracker
  ko
  recent::Vector{PlayerMove}
  board_deltas::Array{Int8, 3}
  to_play::Int
  done::Bool

  function Position(;board = nothing, n = 0, komi = 7.5, caps = (0, 0), lib_tracker = nothing,
    ko = nothing, recent = Vector{PlayerMove}(), board_deltas = nothing, to_play = BLACK)
    b = board != nothing ? board : deepcopy(EMPTY_BOARD)
    lib_trac = lib_tracker != nothing ? lib_tracker : from_board(b)
    bd = board_deltas != nothing ? board_deltas : zeros(Int8, N, N, 0)
    new(b, n, komi, caps, lib_trac, ko, recent, bd, to_play, false)
  end
end

function deepcopy(pos::Position)
  new_board = deepcopy(pos.board)
  new_lib_tracker = deepcopy(pos.lib_tracker)
  new_recent = deepcopy(pos.recent)
  return Position(; board = new_board, n = pos.n, komi = pos.komi, caps = pos.caps,
                  lib_tracker = new_lib_tracker, ko = pos.ko, recent = new_recent,
                  board_deltas = pos.board_deltas, to_play = pos.to_play)
end

function show(io::IO, pos::Position)
  pretty_print_map = Dict{Int, String}([
            WHITE => "O",
            EMPTY => ".",
            BLACK => "X",
            FILL => "#",
            KO => "*"
        ])
  board = deepcopy(pos.board)
  captures = pos.caps
  if pos.ko != nothing
    place_stones!(board, KO, [pos.ko])
  end

  raw_board_contents = []
  for i = 1:N
    row = []
    for j = 1:N
      appended = length(pos.recent) != 0 && (i, j) == pos.recent[end].move ? "<" : " "
      push!(row, pretty_print_map[board[i,j]] * appended)
    end
    push!(raw_board_contents, join(row))
  end

  row_labels_fmt = [@sprintf("%2d ", i) for i = N:-1:1]
  row_labels = [string(i) for i = N:-1:1]
  annotated_board_contents = [join(r) for r in zip(row_labels_fmt, raw_board_contents, row_labels)]
  header_footer_rows = ["   " * join("ABCDEFGHJKLMNOPQRST"[1:N], " ") * "   "]
  annotated_board = join(collect(chain(header_footer_rows, annotated_board_contents,
                                        header_footer_rows)), "\n")
  details = "\nMove: $(pos.n). Captures X: $(captures[1]) O: $(captures[2])\n"
  turn = pos.done ? "GAME OVER\n" : "To Play: " * (pos.to_play == BLACK ? "X(BLACK)\n" : "O(WHITE)\n")
  println(annotated_board * details * turn)
end

function is_move_suicidal(pos::Position, move)
  potential_libs = Set()
  for n in NEIGHBORS[move...]
    neighbor_group_id = pos.lib_tracker.group_index[n...]
    if neighbor_group_id == MISSING_GROUP_ID
    # at least one liberty after playing here, so not a suicide
      return false
    end
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

function is_move_legal(pos::Position, move)
  # Checks that a move is on an empty space, not on ko, and not suicide
  if move == nothing
    return true
  end
  if pos.board[move...] != EMPTY
    return false
  end
  if move == pos.ko
    return false
  end
  if is_move_suicidal(pos, move)
    return false
  end
  return true
end

function all_legal_moves(pos::Position)
  # Returns an array of size N² + 1, with 1 = legal, 0 = illegal
  # by default, every move is legal
  legal_moves = ones(Int8, N, N)
  # ...unless there is already a stone there
  legal_moves[pos.board .!= EMPTY] = 0
  # calculate which spots have 4 stones next to them
  # padding is because the edge always counts as a lost liberty.
  adjacent = ones(Int8, N + 2, N + 2)
  adjacent[2:end - 1, 2:end - 1] = abs.(pos.board)
  num_adjacent_stones = adjacent[1:end - 2, 2:end - 1] + adjacent[2:end - 1, 1:end - 2] +
                        adjacent[3:end, 2:end - 1] + adjacent[2:end - 1, 3:end]
  # Surrounded spots are those that are empty and have 4 adjacent stones.
  surrounded_spots = (pos.board .== EMPTY) .* (num_adjacent_stones .== 4)
  # Such spots are possibly illegal, unless they are capturing something.
  # Iterate over and manually check each spot.
  for c in find(x -> x != 0, surrounded_spots)
    coord = coordify(c)
    if is_move_suicidal(pos, coord)
      legal_moves[coord...] = 0
    end
  end

  # ...and retaking ko is always illegal
  if pos.ko != nothing
    legal_moves[pos.ko...] = 0
  end

  # and pass is always legal
  return cat(1, legal_moves[:], [1])
end

function pass_move!(pos::Position; mutate = false)
  new_pos = mutate ? pos : deepcopy(pos)
  new_pos.n += 1
  push!(new_pos.recent, PlayerMove(new_pos.to_play, nothing))
  new_pos.board_deltas = cat(3, zeros(Int8, N, N, 1), get_first_n(new_pos.board_deltas, 6))
  new_pos.to_play *= -1
  new_pos.ko = nothing
  if length(new_pos.recent) > 1 && new_pos.recent[end - 1].move == nothing
    new_pos.done = true
  end
  return new_pos
end

function flip_playerturn!(pos::Position; mutate = false)
  new_pos = mutate ? pos : deepcopy(pos)
  new_pos.ko = nothing
  new_pos.to_play *= -1
  return new_pos
end

get_liberties(pos::Position) = pos.lib_tracker.liberty_cache

function play_move!(pos::Position, c; color = nothing, mutate = false)
  # Obeys CGOS Rules of Play. defIn short:
  # No suicides
  # Chinese/area scoring
  # Positional superko (this is very crudely approximate at the moment.)
  if color == nothing
    color = pos.to_play
  end

  new_pos = mutate ? pos : deepcopy(pos)

  @assert !new_pos.done

  if c == nothing
    new_pos = pass_move!(new_pos; mutate = mutate)
    return new_pos
  end

  if !is_move_legal(pos, c) 
    throw(IllegalMove())
  end

  potential_ko = is_koish(new_pos.board, c)

  place_stones!(new_pos.board, color, [c])
  captured_stones = add_stone!(new_pos.lib_tracker, color, c)
  place_stones!(new_pos.board, EMPTY, captured_stones)

  opp_color = -color

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

  new_pos.board_deltas = cat(3, reshape(new_board_delta, N, N, 1), get_first_n(new_pos.board_deltas, 6))
  new_pos.to_play *= -1
  return new_pos
end

function score(pos::Position)
  # Return score from B perspective. If W is winning, score is negative.
  working_board = deepcopy(pos.board)
  while EMPTY ∈ working_board
    unassigned_spaces = find(x -> x == EMPTY, working_board)
    c = coordify(unassigned_spaces[1])
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
  return countnz(find(x -> x == BLACK, working_board)) -
  countnz(find(x -> x == WHITE, working_board)) - pos.komi
end

function result(pos::Position)
  points = score(pos)
  if points > 0
    return 1
  elseif points < 0
    return -1
  else
    return 0
  end
end

function result_string(pos::Position)
  points = score(pos)
  if points > 0
    return "B+" * @sprintf("%.1f", points)
  elseif points < 0
    return "W+" *  @sprintf("%.1f", abs(points))
  else
    return "DRAW"
  end
end

struct PositionWithContext
  position::Position
  next_move
  result::Int
end

function replay_position(pos::Position, result)
  #=
  Wrapper for a go.Position which replays its history.
  Assumes an empty start position! (i.e. no handicap, and history must be exhaustive.)

  Result must be passed in, since a resign cannot be inferred from position
  history alone.

  for position_w_context in replay_position(position):
    print(position_w_context.position)
  =#
  pos.n == length(pos.recent) ? nothing : throw(AssertionError("Position history is incomplete"))
  replay_buffer = Vector{PositionWithContext}()
  dummy_pos = Position(komi = pos.komi)

  for player_move in pos.recent
    color, next_move = player_move.color, player_move.move
    push!(replay_buffer, PositionWithContext(dummy_pos, next_move, result))
    dummy_pos = play_move!(dummy_pos, next_move, color = color)
  end
  return replay_buffer
end
