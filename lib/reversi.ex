defmodule Reversi do
  @moduledoc """
  Documentation for `Reversi`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Reversi.hello()
      :world

  """

  def game_loop(board, player, prev_pass) do
    curr_pass = Board.pass?(board)
    case {prev_pass, curr_pass} do
      {true, true} ->
        # Both players pass = game is done
        IO.puts Board.to_string(board)
        IO.puts "Game is done"
      {false, true} ->
        # Current turn is a pass
        IO.puts Board.to_string(board)
        IO.puts "Pass"
        # Print stuff
        # To next turn
        game_loop(Board.switch_turn(board), player, true)
      {_, false} ->
        # Play on normally, regardless of prev turn
        new_board = if player == board.turn do
          Board.switch_turn(player_turn(board))
        else
          Board.switch_turn(board)
        end
        game_loop(new_board, player, false)
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
            {black, white} = Board.flip(board, move)
            {:ok, %{board | black: black, white: white}}
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

  def ai_turn(board) do
  end

end

defmodule Reversi.CLI do
  def main(argv) do
    {options, _, _} = OptionParser.parse(argv,
      switches: [player: :integer]
    )
    player = if options[:player] < 0, do: Board.turn_black, else: Board.turn_white
    board = Board.new()
    # mcts_tables = MCTS.init(board)
    Reversi.game_loop(board, player, false)
  end
end

