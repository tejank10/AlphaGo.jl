include("AlphaGo.jl")
using AlphaGo

set_all_params(5)

prev_nn = NeuralNet(tower_height = 0)
cur_nn = deepcopy(prev_nn)
player = MCTSPlayer(cur_nn)

for i = 1:5
  initialize_game!(player)
  while !is_done(player)
    tree_search!(player)
    play_move!(player, pick_move(player))
  end
  set_result!(player, result(player.root.position), false)
  in_data = extract_data(player)
  train!(cur_nn, in_data)
  cur_is_best = evaluate(cur_nn, prev_nn; num_games = 5, num_sims = 8)

  if cur_is_best
    prev_nn = deepcopy(cur_nn)
  else
    cur_nn = deepcopy(prev_nn)
  end
end
