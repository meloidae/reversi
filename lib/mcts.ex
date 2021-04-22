defmodule MCTS do
  @legal_table :legal
  @count_table :count
  def legal_table, do: @legal_table
  def count_table, do: @count_table

  defstruct legal: %{}, count: %{}

  def init(board) do
    legals = Board.get_legal_moves(board)
  end

  def run(board) do
  end

  defp step(board) do
  end

  defp _step(board) do
  end

end
