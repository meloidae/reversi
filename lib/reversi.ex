defmodule Reversi do
  @moduledoc """
  module for reversi
  """

  @doc """

  ## Examples

  """

  def game_loop(board, player, prev_pass, ai_fn) do
    curr_pass = Board.pass?(board)
    case {prev_pass, curr_pass} do
      {true, true} ->
        # Both players pass = game is done
        IO.puts Board.to_string(board)
        game_end(board)
      {false, true} ->
        # Current turn is a pass
        IO.puts Board.to_string(board)
        IO.puts "Pass"
        # Print stuff
        # To next turn
        game_loop(Board.switch_turn(board), player, true, ai_fn)
      {_, false} ->
        # Play on normally, regardless of prev turn
        new_board = if player == board.turn do
          Board.switch_turn(player_turn(board))
        else
          Board.switch_turn(ai_turn(board, ai_fn))
        end
        game_loop(new_board, player, false, ai_fn)
    end
  end

  defp _player_turn(board) do
    IO.puts Board.to_string(board)
    input = IO.gets("Choose your move (#{if board.turn == Board.turn_black, do: "B", else: "W"}) : ")
    xy = String.trim(input)
    if String.length(xy) < 2 do
      {:error, "Invalid input"}
    else
      case Board.coord_to_bits(xy) do
        {:ok, move} ->
          if Board.legal_move?(board, move) do
            {:ok, Board.flip(board, move)}
          else
            {:error,"#{xy} is NOT legal!" }
          end
        err ->
          err
      end
    end
  end

  def player_turn(board) do
    case _player_turn(board) do
      {:ok, board} ->
        board
      {:error, msg} ->
        IO.puts msg
        player_turn(board)
    end
  end

  def ai_turn(board, ai_fn) do
    move = ai_fn.(board)
    Board.flip(board, move)
  end

  def game_end(board) do
    b = board.black |> Board.popcount()
    w = board.white |> Board.popcount()
    cond do
      b > w ->
        IO.puts "Black: #{b}, White: #{w}\nThe winner is BLACK!"
      w < b ->
        IO.puts "Black: #{b}, White: #{w}\nThe winnger is WHITE!"
      true ->
        IO.puts "Black: #{b}, White: #{w}\nIt's a tie!"
    end
  end

end

defmodule Reversi.CLI do
  def main(argv) do
    {options, _, _} = OptionParser.parse(argv,
      switches: [player: :integer, mcts: :boolean, simcount: :integer]
    )
    player = if options[:player] < 0, do: Board.turn_black, else: Board.turn_white
    board = Board.new()
    ai_init = if options[:mcts], do: &MCTS.init/0, else: &RandomAI.init/0
    ai_init.()
    ai_fn = if options[:mcts] do 
      sim_count = options[:simcount]
      fn x -> MCTS.turn(x, sim_count) end
    else
      &RandomAI.turn/1
    end
    Reversi.game_loop(board, player, false, ai_fn)
  end
end

