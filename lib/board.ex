defmodule Board do
  use Bitwise

  @default_white 0x0000001008000000
  @default_black 0x0000000810000000 

  @turn_black -1
  @turn_white 1

  defstruct black: 0, white: 0, turn: @turn_black, move: 1

  def turn_black, do: @turn_black
  def turn_white, do: @turn_white

  def new(black \\ @default_black, white \\ @default_white) do
    # Test code
    # test_board = 0x12_34_01_10_80_08_40_04
    # IO.puts move_to_bit_string(test_board)
    # moves_to_list(test_board) |> Enum.map(fn x -> IO.puts move_to_bit_string(x) end)
    # Test end
    %Board{white: white, black: black, turn: -1, move: 1}
  end

  def to_string(board) do
    "\n  a b c d e f g h\n" <> rec_to_string(board, 64, "")
  end

  def move_to_bit_string(move) do
    digits = Integer.digits(move, 2)
    len = digits |> length
    remainder = 64 - len
    if remainder != 0 do
      head_zeros = Enum.map(Enum.to_list(1..remainder), fn _ -> 0 end)
      Enum.join(head_zeros ++ digits)
    else
      Enum.join(digits)
    end
  end

  @a_value 97
  @base_mask 0x8000000000000000
  def coord_to_bits(xy) do
    <<c::utf8>> = String.at(xy, 0)
    x = c - @a_value
    {y, _} = Integer.parse(String.at(xy, 1))
    y = y - 1
    cond do
      x < 0 or 7 < x ->
        {:error, "x is out of bounds in #{xy}"}
      y < 0 or 7 < y ->
        {:error, "y is out of bounds in #{xy}"}
      true ->
        bits = @base_mask >>> x
        {:ok, bits >>> (y * 8)}
    end
  end

  def switch_turn(board) do
    %{board | turn: board.turn * -1}
  end

  defguard is_border(n) when rem(n, 8) == 0

  def rec_to_string(_board, 0, acc) do
    Integer.to_string(1) <> acc
  end

  def rec_to_string(board, n, acc) when is_border(n) do
    border = if n == 64 do
      ""
    else
      "\n" <> Integer.to_string(div(n, 8) + 1)
    end
    c = bit_to_char(board, @base_mask >>> (n - 1))
    rec_to_string(board, n - 1, " " <> c <> border <> acc)
  end

  def rec_to_string(board, n, acc) do
    c = bit_to_char(board, @base_mask >>> (n - 1))
    rec_to_string(board, n - 1, " " <> c <> acc)
  end

  def bit_to_char(board, bit) do
    cond do
      (board.white &&& bit) != 0 ->
        "W"
      (board.black &&& bit) != 0 ->
        "B"
      true ->
        "-"
    end
  end 

  # Population count
  def popcount(bits) do
    sum_bytes(:binary.encode_unsigned(bits), 0)
  end

  defp sum_bytes(<<byte::8>> <> rest, sum) do
    sum_bytes(rest, sum + lookup_hamming(byte))
  end

  defp sum_bytes(<<>>, sum) do
    sum
  end

  for byte <- 0..255 do
    sum = (for <<bit::1 <- :binary.encode_unsigned(byte)>>, do: bit) |> Enum.sum
    defp lookup_hamming(unquote(byte)), do: unquote(sum)
  end

  # Break up moves bits into list of moves (one-hot integers)
  def moves_to_list(moves) do
    (for <<byte::8 <- :binary.encode_unsigned(moves, :little)>>, do: byte)
    |> Stream.with_index()
    |> Enum.flat_map(fn {x, i} -> lookup_move_list(x, i) end)
  end

  # Get indices of set bits
  def moves_to_indices(moves) do
    (for <<byte::8 <- :binary.encode_unsigned(moves, :little)>>, do: byte)
    |> Stream.with_index()
    |> Stream.flat_map(fn {x, i} -> lookup_move_indices(x, i) end)
  end

  for byte <- 0..255 do
    move_offsets = 0..7 |> Enum.filter(fn x -> ((1 <<< x) &&& byte) != 0 end)
    for offset_byte <- 0..7 do
      indices = Enum.map(move_offsets, fn x -> x + offset_byte * 8 end)
      moves = Enum.map(indices, fn x -> 1 <<< x end)
      defp lookup_move_list(unquote(byte), unquote(offset_byte)), do: unquote(moves)
      defp lookup_move_indices(unquote(byte), unquote(offset_byte)), do: unquote(indices)
    end
  end

  def legal_move?(board, move) do
    legals = get_legal_moves(board)
    (move &&& legals) == move
  end

  def pass?(board) do
    popcount(get_legal_moves(board)) == 0
  end

  def get_legal_moves(board) do
    {me, you} = if board.turn == @turn_black do
      {board.black, board.white}
    else
      {board.white, board.black}
    end

    horizontal_watcher = you &&& 0x7e7e7e7e7e7e7e7e
    vertical_watcher = you &&& 0x00FFFFFFFFFFFF00
    diagonal_watcher = you &&& 0x007e7e7e7e7e7e00

    # Get all unoccupied positions
    unoccupied = bnot(me ||| you)

    # Check all 8 directions
    # Left
    tmp = horizontal_watcher &&& (me <<< 1)
    tmp = tmp ||| (horizontal_watcher &&& (tmp <<< 1))
    tmp = tmp ||| (horizontal_watcher &&& (tmp <<< 1))
    tmp = tmp ||| (horizontal_watcher &&& (tmp <<< 1))
    tmp = tmp ||| (horizontal_watcher &&& (tmp <<< 1))
    tmp = tmp ||| (horizontal_watcher &&& (tmp <<< 1))
    legals = unoccupied &&& (tmp <<< 1)

    # Right
    tmp = horizontal_watcher &&& (me >>> 1)
    tmp = tmp ||| (horizontal_watcher &&& (tmp >>> 1))
    tmp = tmp ||| (horizontal_watcher &&& (tmp >>> 1))
    tmp = tmp ||| (horizontal_watcher &&& (tmp >>> 1))
    tmp = tmp ||| (horizontal_watcher &&& (tmp >>> 1))
    tmp = tmp ||| (horizontal_watcher &&& (tmp >>> 1))
    legals = legals ||| (unoccupied &&& (tmp >>> 1))

    # Up
    tmp = vertical_watcher &&& (me <<< 8)
    tmp = tmp ||| (vertical_watcher &&& (tmp <<< 8))
    tmp = tmp ||| (vertical_watcher &&& (tmp <<< 8))
    tmp = tmp ||| (vertical_watcher &&& (tmp <<< 8))
    tmp = tmp ||| (vertical_watcher &&& (tmp <<< 8))
    tmp = tmp ||| (vertical_watcher &&& (tmp <<< 8))
    legals = legals ||| (unoccupied &&& (tmp <<< 8))

    # Down
    tmp = vertical_watcher &&& (me >>> 8)
    tmp = tmp ||| (vertical_watcher &&& (tmp >>> 8))
    tmp = tmp ||| (vertical_watcher &&& (tmp >>> 8))
    tmp = tmp ||| (vertical_watcher &&& (tmp >>> 8))
    tmp = tmp ||| (vertical_watcher &&& (tmp >>> 8))
    tmp = tmp ||| (vertical_watcher &&& (tmp >>> 8))
    legals = legals ||| (unoccupied &&& (tmp >>> 8))

    # Up Right
    tmp = diagonal_watcher &&& (me <<< 7)
    tmp = tmp ||| (diagonal_watcher &&& (tmp <<< 7))
    tmp = tmp ||| (diagonal_watcher &&& (tmp <<< 7))
    tmp = tmp ||| (diagonal_watcher &&& (tmp <<< 7))
    tmp = tmp ||| (diagonal_watcher &&& (tmp <<< 7))
    tmp = tmp ||| (diagonal_watcher &&& (tmp <<< 7))
    legals = legals ||| (unoccupied &&& (tmp <<< 7))

    # Up Left
    tmp = diagonal_watcher &&& (me <<< 9)
    tmp = tmp ||| (diagonal_watcher &&& (tmp <<< 9))
    tmp = tmp ||| (diagonal_watcher &&& (tmp <<< 9))
    tmp = tmp ||| (diagonal_watcher &&& (tmp <<< 9))
    tmp = tmp ||| (diagonal_watcher &&& (tmp <<< 9))
    tmp = tmp ||| (diagonal_watcher &&& (tmp <<< 9))
    legals = legals ||| (unoccupied &&& (tmp <<< 9))

    # Down Right
    tmp = diagonal_watcher &&& (me >>> 9)
    tmp = tmp ||| (diagonal_watcher &&& (tmp >>> 9))
    tmp = tmp ||| (diagonal_watcher &&& (tmp >>> 9))
    tmp = tmp ||| (diagonal_watcher &&& (tmp >>> 9))
    tmp = tmp ||| (diagonal_watcher &&& (tmp >>> 9))
    tmp = tmp ||| (diagonal_watcher &&& (tmp >>> 9))
    legals = legals ||| (unoccupied &&& (tmp >>> 9))

    # Down Left
    tmp = diagonal_watcher &&& (me >>> 7)
    tmp = tmp ||| (diagonal_watcher &&& (tmp >>> 7))
    tmp = tmp ||| (diagonal_watcher &&& (tmp >>> 7))
    tmp = tmp ||| (diagonal_watcher &&& (tmp >>> 7))
    tmp = tmp ||| (diagonal_watcher &&& (tmp >>> 7))
    tmp = tmp ||| (diagonal_watcher &&& (tmp >>> 7))
    legals = legals ||| (unoccupied &&& (tmp >>> 7))

    legals
  end

  # Return new black & white bits after flip
  def flip(board, move) do
    {me, you} = if board.turn == @turn_black do
      {board.black, board.white}
    else
      {board.white, board.black}
    end

    # Figure out positions to flip
    to_flip = Enum.reduce(0..7, 0x0,
      fn (dir, acc) ->
        mask = flip_bits(move, dir)
        {mask, flipped} = flip_loop(mask, dir, you, 0x0)
        if (mask &&& me) != 0, do: flipped ||| acc, else: acc
      end
    )

    # Flip
    new_me = me ^^^ (move ||| to_flip)
    new_you = you ^^^ to_flip

    if board.turn == @turn_black do
      %{board | black: new_me, white: new_you}
    else
      %{board | black: new_you, white: new_me}
    end
  end

  defp flip_loop(mask, dir, you, acc) when mask != 0 and ((mask &&& you) != 0) do
    new_mask = flip_bits(mask, dir)
    flip_loop(new_mask, dir, you, acc ||| mask)
  end

  defp flip_loop(mask, _dir, _you, acc) do
    {mask, acc}
  end

  defp flip_bits(move, dir) do
    case dir do
      0 -> (move <<< 8) &&& 0xffffffffffffff00  # Up
      1 -> (move <<< 7) &&& 0x7f7f7f7f7f7f7f00  # Up Right
      2 -> (move >>> 1) &&& 0x7f7f7f7f7f7f7f7f  # Right
      3 -> (move >>> 9) &&& 0x007f7f7f7f7f7f7f  # Down Right
      4 -> (move >>> 8) &&& 0x00ffffffffffffff  # Down
      5 -> (move >>> 7) &&& 0x00fefefefefefefe  # Down Left
      6 -> (move <<< 1) &&& 0xfefefefefefefefe  # Left
      7 -> (move <<< 9) &&& 0xfefefefefefefe00  # Up Left
      _ -> 0x0
    end
  end

end

