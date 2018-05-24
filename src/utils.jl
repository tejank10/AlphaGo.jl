KGS_COLUMNS = "ABCDEFGHJKLMNOPQRST"
SGF_COLUMNS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

#parse_sgf_to_flat(sgf) = flatten_coords(parse_sgf_coords(sgf))

#flatten_coords(c) = N * (c[2] - 1) + c[1]

#unflatten_coords(f) = tuple([i + 1 for i in reverse(divrem(f - 1, N))...])

function parse_sgf_coords(s)
  # Interprets coords. aa is top left corner; sa is top right corner
  if s == nothing || s == ""
    return nothing
  end
  return searchindex(SGF_COLUMNS, s[2]), searchindex(SGF_COLUMNS, s[1])
end

function parse_kgs_coords(s)
  # Interprets coords. A1 is bottom left; A9 is top left.
  if s == "pass"
    return nothing
  end
  s = uppercase(s)
  col = searchindex(KGS_COLUMNS, s[1])
  row_from_bottom = parse(Int, s[2:end])
  return N - row_from_bottom + 1, col
end
