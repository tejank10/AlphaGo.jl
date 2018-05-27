#=
This is Julia implementation of Go Board by Tejan Karmali.
Original Python version of the implementation of Go by
Brian Lee (https://github.com/brilee/MuGo/blob/master/go.py)
=#

import Base: ==, deepcopy, show
using IterTools: chain
WHITE, EMPTY, BLACK, FILL, KO, UNKNOWN = collect(-1:4)

# Represents "group not found" in the LibertyTracker object
MISSING_GROUP_ID = -1

struct PlayerMove
  color
  move
end

struct IllegalMove <:Exception end

N = 19
ALL_COORDS = Vector{NTuple{2, Int}}()
EMPTY_BOARD = nothing
NEIGHBORS = Dict{NTuple{2, Int}, Array{NTuple{2, Int}, 1}}()
DIAGONALS = Dict{NTuple{2, Int}, Array{NTuple{2, Int}, 1}}()

function set_board_size(n::Int = 19)
  global N, ALL_COORDS, EMPTY_BOARD, NEIGHBORS, DIAGONALS
  n ∈ (9, 13, 17, 19) || error("Illegal board size $n")
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

#TODO: type of c
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
      coord = 1 + (found_color[1] - 1)% N, 1 + (found_color[1] - 1) ÷ N
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

function _create_group!(lib_trac::LibertyTracker, color, c::NTuple{2, Int},
  liberties::Set{NTuple{2, Int}})
  lib_trac.max_group_id += 1
  new_group = Group(lib_trac.max_group_id, Set([c]), liberties, color)
  lib_trac.groups[new_group.id] = new_group
  lib_trac.group_index[c...] = new_group.id
  lib_trac.liberty_cache[c...] = length(liberties)
  return new_group
end

function _update_liberties!(lib_trac::LibertyTracker, group_id::Integer; add = nothing, remove = nothing)
  group = lib_trac.groups[group_id]
  if add != nothing
    union!(group.liberties, add)
  end
  if remove != nothing
    setdiff!(group.liberties, remove)
  end

  new_lib_count = length(group.liberties)
  for s in group.stones
    lib_trac.liberty_cache[s...] = new_lib_count
  end
end

function _merge_groups!(lib_trac::LibertyTracker, group1_id::Int, group2_id::Int)
  group1 = lib_trac.groups[group1_id]
  group2 = lib_trac.groups[group2_id]
  union!(group1.stones, group2.stones)
  delete!(lib_trac.groups, group2_id)
  for s in group2.stones
    lib_trac.group_index[s...] = group1_id
  end

  _update_liberties!(lib_trac, group1_id; add = group2.liberties, remove = union(group2.stones, group1.stones))

  return group1
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

  new_group = _create_group!(lib_trac, color, c, empty_neighbors)

  for group_id in friendly_neighboring_group_ids
    new_group = _merge_groups!(lib_trac, group_id, new_group.id)
  end
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
  if length(new_group.liberties) == 0
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
  to_play: BLACK or WHITE
  =#

  board::Array{Int8, 2}
  n::Int
  komi::Float64
  caps::NTuple{2, Int}
  lib_tracker::LibertyTracker
  ko::Any
  recent::Vector{PlayerMove}
  to_play::Int
  done::Bool

  function Position(;board = nothing, n = 0, komi = 7.5, caps = (0, 0), lib_tracker = nothing,
    ko = nothing, recent = Vector{PlayerMove}(), to_play = BLACK)
    b = board != nothing ? board : deepcopy(EMPTY_BOARD)
    lib_trac = lib_tracker != nothing ? lib_tracker : from_board(b)
    new(b, n, komi, caps, lib_trac, ko, recent, to_play, false)
  end
end

function deepcopy(pos::Position)
  new_board = deepcopy(pos.board)
  new_lib_tracker = deepcopy(pos.lib_tracker)
  return Position(;board = new_board, n = pos.n, komi = pos.komi, caps = pos.caps,
  lib_tracker = new_lib_tracker, ko = pos.ko, recent = pos.recent, to_play = pos.to_play)
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
      appended = (length(pos.recent) != 0 && (i, j) == pos.recent[end].move) ? "<" : " "
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
  return length(potential_libs) == 0
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

function pass_move!(pos::Position; mutate = false)
  new_pos = mutate ? pos : deepcopy(pos)
  new_pos.n += 1
  push!(new_pos.recent, PlayerMove(new_pos.to_play, nothing))
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

  place_stones!(new_pos.board, color, [c])
  captured_stones = add_stone!(new_pos.lib_tracker, color, c)
  place_stones!(new_pos.board, EMPTY, captured_stones)

  opp_color = -color

  if length(captured_stones) == 1 && is_koish(pos.board, c) == opp_color
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
  new_pos.to_play *= -1
  return new_pos
end

function score(pos::Position)
  working_board = deepcopy(pos.board)
  while EMPTY ∈ working_board
    unassigned_spaces = find(x -> x == EMPTY, working_board)
    c = 1 + (unassigned_spaces[1] - 1) % N, 1 + (unassigned_spaces[1] - 1) ÷ N
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
    return "B+" * @sprintf("%.1f", points)
  elseif points < 0
    return "W+" *  @sprintf("%.1f", abs(points))
  else
    return "DRAW"
  end
end
