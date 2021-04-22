defmodule RandomAI do
  def turn(board) do
    board |> Board.get_legal_moves()
          |> Board.moves_to_list()
          |> Enum.random()
  end
end
