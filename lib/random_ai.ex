defmodule RandomAI do
  def init(seed \\ {42, 43, 44}) do
    :rand.seed(:exorp, seed)
  end

  def turn(board) do
    board |> Board.get_legal_moves()
          |> Board.moves_to_list()
          |> Enum.random()
  end
end
