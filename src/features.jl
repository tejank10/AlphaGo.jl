GoTypePos = Union{GoPosition}

function stone_features(pos::T) where T<:GoTypePos
  N =  board_size(pos)
  planes = pos.planes
  features = zeros(UInt8, N, N, 2planes)

  num_deltas_avail = size(pos.board_deltas, 3)
  cumulative_deltas = cumsum(pos.board_deltas, dims=3)
  extra_dim_board = reshape(pos.board, size(pos.board)..., 1)
  last_eight = repeat(extra_dim_board, outer = (1, 1, planes))

  # apply deltas to compute previous board states
  last_eight[:, :, 2:num_deltas_avail + 1] .= last_eight[:, :, 2:num_deltas_avail + 1] .- cumulative_deltas
  # if no more deltas are available, just repeat oldest board.
  last_eight[:, :, num_deltas_avail + 2:end] .= last_eight[:, :, num_deltas_avail + 1]

  features[:, :, 1:2:end] .= last_eight .== pos.to_play
  features[:, :, 2:2:end] .= last_eight .== -pos.to_play

  features .+ 0f0
end

color_to_play_feature(pos::GoTypePos) = pos.to_play * ones(UInt8, pos.env.N, pos.env.N, 1)

get_feats(pos::GoTypePos) = cat(dims=3, stone_features(pos), color_to_play_feature(pos))
