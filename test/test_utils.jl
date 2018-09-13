function load_board(str, go_env::GoEnv)
  reverse_map = Dict{Char, Int}([
      'X' => 1, # BLACK
      'O' => -1,  # WHITE
      '.' => 0, # EMPTY
      '#' => 2, # FILL
      '*' => 3, # Ko
      '?' => 4  # UNKNOWN
  ])
  str = replace(str, r"[^XO\.#]+" => s"")
  @assert length(str) == go_env.N ^ 2 # "Board to load didn't have right dimensions"
  board = zeros(Int8, go_env.N, go_env.N)
  for (i, char) in enumerate(str)
      board[i] = reverse_map[char]
  end
  board = permutedims(board, [2, 1])
  return board
end

function assertEqualArray(array1, array2)
  if !all(array1 .== array2)
    throw(AssertionError("Arrays differed in one or more locations:\n$array1\n%$array2\n"))
  end
  return true
end

function assertEqualLibTracker(lib_tracker1, lib_tracker2)
  # A lib tracker may have differently numbered groups yet still
  # represent the same set of groups.
  # "Sort" the group_ids to ensure they are the same.
  function find_group_mapping(lib_tracker)
    current_gid = 0
    mapping = Dict{Int16, Int}()
    for group_id in lib_tracker.group_index
      if group_id == MISSING_GROUP_ID
        continue
      end
      if group_id ∉ keys(mapping)
        mapping[group_id] = current_gid
        current_gid += 1
      end
    end
    return mapping
  end

  lt1_mapping = find_group_mapping(lib_tracker1)
  lt2_mapping = find_group_mapping(lib_tracker2)

  remapped_group_index1 = [get(lt1_mapping, gid, MISSING_GROUP_ID)
                            for gid in lib_tracker1.group_index]
  remapped_group_index2 = [get(lt2_mapping, gid, MISSING_GROUP_ID)
                            for gid in lib_tracker2.group_index]
  @assert remapped_group_index1 == remapped_group_index2

  remapped_groups1 = Dict(get(lt1_mapping, gid, 0) => group for (gid, group) in lib_tracker1.groups)
  remapped_groups2 = Dict(get(lt2_mapping, gid, 0) => group for (gid, group) in lib_tracker2.groups)
  @assert remapped_groups1 == remapped_groups2

  assertEqualArray(lib_tracker1.liberty_cache, lib_tracker2.liberty_cache)
end

function assertEqualPositions(pos1, pos2)
  assertEqualArray(pos1.board, pos2.board)
  assertEqualLibTracker(pos1.lib_tracker, pos2.lib_tracker)
  @assert pos1.n == pos2.n
  @assert pos1.caps == pos2.caps
  @assert pos1.ko == pos2.ko
  r_len = min(length(pos1.recent), length(pos2.recent))
  if r_len > 0 # if a position has no history, then don't bother testing
    @assert pos1.recent[end - r_len + 1:end] == pos2.recent[end - r_len + 1:end]
  end
  @assert pos1.to_play == pos2.to_play
  return true
end

function assertNoPendingVirtualLosses(root)
  # Raise an error if any node in this subtree has vlosses pending.
  queue = [root]
  while !isempty(queue)
    current = pop!(queue)
    @assert current.losses_applied == 0
    queue = vcat(queue, collect(values(current.children)))
  end
  return true
end
