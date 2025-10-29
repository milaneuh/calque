defmodule Calque.Levenshtein do
  @moduledoc """
  Levenshtein (edit) distance between two strings (insert, delete, substitute).
  Unicode-safe by operating on graphemes.
  """

  @doc false
  @spec distance(String.t(), String.t()) :: non_neg_integer()
  def distance(a, "") do
    String.length(a)
  end

  def distance("", b) do
    String.length(b)
  end

  def distance(a, b) when a == b do
    0
  end

  def distance(a, b) do
    do_distance(String.graphemes(a), String.graphemes(b))
  end

  @doc false
  defp do_distance(a, b) do
    prev_row = Enum.to_list(0..length(b))

    final_row =
      Enum.reduce(a, prev_row, fn sc, prev_row ->
        build_row(sc, b, prev_row)
      end)

    List.last(final_row)
  end

  @doc false
  defp build_row(sc, t, prev_row) do
    first_cell = hd(prev_row) + 1
    up_left0 = hd(prev_row)

    {row_rev, _last_up} =
      Enum.reduce(Enum.with_index(t, 1), {[first_cell], up_left0}, fn {tc, j}, {row_rev, up_left} ->
        left = hd(row_rev)
        up = Enum.at(prev_row, j)
        cost = if sc == tc, do: 0, else: 1
        cell = min(min(left + 1, up + 1), up_left + cost)
        {[cell | row_rev], up}
      end)

    Enum.reverse(row_rev)
  end
end
