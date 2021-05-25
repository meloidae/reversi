defmodule MCTS do
  @moves_table :legal
  @visit_table :visit
  @win_table :win
  @branch_table :branch
  def moves_table, do: @moves_table
  def visit_table, do: @visit_table
  def win_table, do: @win_table
  def branch_table, do: @branch_table

  defstruct legal: %{}, count: %{}

  @score_array {120, -20,  20,   5,   5,  20, -20, 120,
                -20, -40,  -5,  -5,  -5,  -5, -40, -20,
                 20,  -5,  15,   3,   3,  15,  -5,  20,
                  5,  -5,   3,   3,   3,   3,  -5,   5,
                  5,  -5,   3,   3,   3,   3,  -5,   5,
                 20,  -5,  15,   3,   3,  15,  -5,  20,
                -20, -40,  -5,  -5,  -5,  -5, -40, -20,
                120, -20,  20,   5,   5,  20, -20, 120}


  # Got this vaule from a random paper
  @uct_constant :math.sqrt(2) * 8 / 3
  @branch_threshold 100

  def init() do
    # Initalize tables
    :ets.new(@moves_table, [:named_table])
    :ets.new(@visit_table, [:named_table])
    :ets.new(@win_table, [:named_table])
    :ets.new(@branch_table, [:named_table])
  end

  def simple_score(board) do
    black_score = board.black
                  |> Board.moves_to_indices()
                  |> Stream.map(fn x -> elem(@score_array, x) end)
                  |> Enum.sum()
    white_score = board.white
                  |> Board.moves_to_indices()
                  |> Stream.map(fn x -> elem(@score_array, x) end)
                  |> Enum.sum()
    (white_score - black_score) * (if board.turn == Board.turn_black, do: -1, else: 1)
  end

  def uct(board, parent_visit_count) do
    key = {board.black, board.white, board.turn}
    visit_count = :ets.lookup(@visit_table, key) |> hd |> elem(1)
    win_count = :ets.lookup(@win_table, key) |> hd |> elem(1)
    if visit_count == 0 do
      :infinity
    else
      win_prob = win_count / visit_count
      (@uct_constant * :math.sqrt(:math.log(parent_visit_count) / visit_count)) + win_prob
    end
  end

  def turn(board, simulation_count) do
    key = {board.black, board.white, board.turn}
    # Make sure this node is in all the tables
    cond do
      !:ets.member(@visit_table, key) ->
        # This node is not in any of the tables
        new_node(board)
        move_list = :ets.lookup(@moves_table, key) |> hd |> elem(1)
        expand(board, move_list)
      !:ets.member(@branch_table, key) ->
        # This node is not registered as a branch
        move_list = :ets.lookup(@moves_table, key) |> hd |> elem(1)
        expand(board, move_list)
      true ->
        nil
    end

    # Run Monte-Carlo Tree Search
    for i <- 1..simulation_count do
      {final_board, path} = select(board, false, [key])
      board_diff = Board.popcount(final_board.black) - Board.popcount(final_board.white)
      win = if board.turn == Board.turn_black, do: board_diff > 0, else: board_diff < 0
      update(win, path)
    end

    move_list = :ets.lookup(@moves_table, key) |> hd |> elem(1)
    scores = Stream.map(move_list,
      fn x ->
        b = Board.flip(board, x) |> Board.switch_turn()
        k = {b.black, b.white, b.turn}
        win = :ets.lookup(@win_table, k) |> hd |> elem(1)
        visit = :ets.lookup(@visit_table, k) |> hd |> elem(1)
        {win, visit}
      end
    )
    {_, chosen_move} = Stream.zip(scores, move_list) |> Enum.max_by(fn {s, m} ->
      {w, v} = s
      IO.puts "#{Board.move_to_bit_string(m)}: #{w}/#{v}"
      w 
    end)
    chosen_move
  end

  def new_node(board) do
    key = {board.black, board.white, board.turn}
    moves = Board.get_legal_moves(board) |> Board.moves_to_list()
    :ets.insert(@moves_table, {key, moves})
    :ets.insert(@visit_table, {key, 0})
    :ets.insert(@win_table, {key, 0})
  end

  def update(_, []) do
  end

  def update(false, [key | path]) do
    visit_count = :ets.lookup(@visit_table, key) |> hd |> elem(1)
    :ets.insert(@visit_table, {key, visit_count + 1})
    update(false, path)
  end

  def update(true, [key | path]) do
    visit_count = :ets.lookup(@visit_table, key) |> hd |> elem(1)
    :ets.insert(@visit_table, {key, visit_count + 1})
    win_count = :ets.lookup(@win_table, key) |> hd |> elem(1)
    :ets.insert(@win_table, {key, win_count + 1})
    update(true, path)
  end

  def expand(board, []) do
    # This node is now a branch
    :ets.insert(@branch_table, {{board.black, board.white, board.turn}, true})
    # Create a new node, the current node is a pass so only one new node
    new_board = Board.switch_turn(board)
    new_node(new_board)
  end

  def expand(board, move_list) do
    # This node is now a branch
    :ets.insert(@branch_table, {{board.black, board.white, board.turn}, true})
    for move <- move_list do
      new_board = Board.flip(board, move) |> Board.switch_turn()
      new_node(new_board)
    end
  end

  def select(board, prev_pass, path) do
    key = {board.black, board.white, board.turn}
    {_, move_list} = :ets.lookup(@moves_table, key) |> hd
    case {prev_pass, move_list, :ets.member(@branch_table, key)} do
      {true, [], _} ->
        # The previous node and this node are passes = game has ended
        {board, [key | path]}
      {false, [], true} ->
        # This node is a pass and is a branch
        select(Board.switch_turn(board), true, [key | path])
      {false, [], false} ->
        # This node is a pass and is a leaf
        visit_count = :ets.lookup(@visit_table, key) |> hd |> elem(1)
        if visit_count > 0 do
          # If it's not the first visit, then expand before further selection
          expand(board, move_list)
          select(Board.switch_turn(board), true, [key | path])
        else
          # If it's a first visit, then start a simulation
          simulate(Board.switch_turn(board), true, [key | path])
        end
      {_, _, branch} ->
        # Select a move with the highest uct score
        visit_count = :ets.lookup(@visit_table, key) |> hd |> elem(1)
        if branch do
          scores = move_list |> Stream.map(fn m -> 
            Board.flip(board, m) |> Board.switch_turn() |> uct(visit_count)
          end)
          {_, chosen_move} = Stream.zip(scores, move_list) |> Enum.max_by(fn {s, _} -> s end)
          new_board = board
                      |> Board.flip(chosen_move)
                      |> Board.switch_turn()
          select(new_board, false, [key | path])
        else
          chosen_move = move_list |> Enum.random()
          new_board = board
                      |> Board.flip(chosen_move)
                      |> Board.switch_turn()
          if visit_count > 0 do
            # If it's not the first visit, then expand before further selection
            expand(board, move_list)
            select(new_board, false, [key | path])
          else
            simulate(new_board, false, [key | path])
          end
        end
    end
  end

  def simulate(board, prev_pass, path) do
    move_list = Board.get_legal_moves(board) |> Board.moves_to_list()
    case {prev_pass, move_list} do
      {true, []} ->
        # The previous node and this node are passes = game has ended
        {board, path}
      {false, []} ->
        # This node is a pass
        simulate(Board.switch_turn(board), true, path)
      _ ->
        chosen_move = move_list |> Enum.random()
        new_board  = board |> Board.flip(chosen_move) |> Board.switch_turn()
        simulate(new_board, false, path)
    end
  end

end
