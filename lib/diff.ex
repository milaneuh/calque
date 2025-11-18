defmodule Calque.Diff do
  @moduledoc """
  Utilities to render simple line-by-line diffs used by Calque's CLI output.
  """

  @type diff_line_kind :: :old | :new | :shared
  @type tagged_line :: %{kind: diff_line_kind(), line: String.t()}
  @type diff_line :: %{number: pos_integer(), line: String.t(), kind: diff_line_kind()}

  # Internal histogram occurrence type
  @type occurrence ::
          {:one, non_neg_integer(), [String.t()], [String.t()]}
          | {:other, non_neg_integer(), [String.t()], [String.t()]}
          | {:both, non_neg_integer(), [String.t()], [String.t()], [String.t()], [String.t()]}

  @doc false
  @spec line_by_line(String.t(), String.t()) :: [diff_line()]
  def line_by_line("", ""), do: [%{number: 1, line: "", kind: :shared}]

  def line_by_line(old, new) when is_binary(old) and is_binary(new) do
    old_lines = split_lines(old)
    new_lines = split_lines(new)
    lcs = longest_chain(old_lines, new_lines)

    match_diff_lines([], lcs, 1, old_lines, 1, new_lines)
  end

  def line_by_line(_, _), do: []

  @doc false
  @spec split_lines(String.t()) :: [String.t()]
  defp split_lines(""), do: []
  defp split_lines(text), do: String.split(text, "\n", trim: false)

  # -------------------------
  # DIFF RECONSTRUCTION FROM LCS (HISTOGRAM-BASED)
  # -------------------------

  # Accumulator is built in reverse, then flipped at the end.
  @doc false
  @spec match_diff_lines(
          [diff_line()],
          [String.t()],
          pos_integer(),
          [String.t()],
          pos_integer(),
          [String.t()]
        ) :: [diff_line()]
  defp match_diff_lines(acc, lcs, old_idx, old_lines, new_idx, new_lines) do
    case {lcs, old_lines, new_lines} do
      # Everything drained: return accumulated result in correct order
      {[], [], []} ->
        Enum.reverse(acc)

      # No more common lines; drain remaining old_lines as :old
      {[], [old | old_rest], new_lines} ->
        match_diff_lines(
          [%{number: old_idx, line: old, kind: :old} | acc],
          lcs,
          old_idx + 1,
          old_rest,
          new_idx,
          new_lines
        )

      # No more common lines; old is empty; drain remaining new_lines as :new
      {[], [], [new | new_rest]} ->
        match_diff_lines(
          [%{number: new_idx, line: new, kind: :new} | acc],
          lcs,
          old_idx,
          [],
          new_idx + 1,
          new_rest
        )

      # While the old side has lines that are not the next common line → :old
      {[common | _] = lcs, [old | old_rest], new_lines} when old != common ->
        match_diff_lines(
          [%{number: old_idx, line: old, kind: :old} | acc],
          lcs,
          old_idx + 1,
          old_rest,
          new_idx,
          new_lines
        )

      # While the new side has lines that are not the next common line → :new
      {[common | _] = lcs, old_lines, [new | new_rest]} when new != common ->
        match_diff_lines(
          [%{number: new_idx, line: new, kind: :new} | acc],
          lcs,
          old_idx,
          old_lines,
          new_idx + 1,
          new_rest
        )

      # Both lists start with the same common element → :shared
      {[common | lcs_rest], [_ | old_rest], [_ | new_rest]} ->
        match_diff_lines(
          [%{number: new_idx, line: common, kind: :shared} | acc],
          lcs_rest,
          old_idx + 1,
          old_rest,
          new_idx + 1,
          new_rest
        )
    end
  end

  # -------------------------
  # HISTOGRAM-BASED LCS ("LONGEST CHAIN")
  # -------------------------

  @doc false
  @spec longest_chain([String.t()], [String.t()]) :: [String.t()]
  defp longest_chain(old_lines, new_lines) do
    {prefix, old_rest, new_rest} = pop_common_prefix(old_lines, new_lines)
    {suffix, old_rest, new_rest} = pop_common_suffix(old_rest, new_rest)

    case lowest_occurrence_common_item(old_rest, new_rest) do
      nil ->
        prefix ++ suffix

      {item, _count, before_old, after_old, before_new, after_new} ->
        prefix ++
          longest_chain(Enum.reverse(before_old), Enum.reverse(before_new)) ++
          [item] ++
          longest_chain(after_old, after_new) ++
          suffix
    end
  end

  # -------------------------
  # HISTOGRAM & PIVOT SELECTION
  # -------------------------

  @doc false
  @spec lowest_occurrence_common_item([String.t()], [String.t()]) ::
          {String.t(), non_neg_integer(), [String.t()], [String.t()], [String.t()], [String.t()]}
          | nil
  defp lowest_occurrence_common_item(old_lines, new_lines) do
    histogram =
      %{}
      |> histogram_add(old_lines, :one, [])
      |> histogram_add(new_lines, :other, [])

    Enum.reduce(histogram, nil, fn
      {_line, {:one, _n, _b, _a}}, acc ->
        acc

      {_line, {:other, _n, _b, _a}}, acc ->
        acc

      {line, {:both, n, before_old, after_old, before_new, after_new}}, nil ->
        {line, n, before_old, after_old, before_new, after_new}

      {line, {:both, n, before_old, after_old, before_new, after_new}},
      {_best_line, best_n, _bo, _ao, _bn, _an} = acc ->
        if n < best_n do
          {line, n, before_old, after_old, before_new, after_new}
        else
          acc
        end
    end)
  end

  @doc false
  @spec histogram_add(
          %{optional(String.t()) => occurrence()},
          [String.t()],
          :one | :other,
          [String.t()]
        ) :: %{optional(String.t()) => occurrence()}
  defp histogram_add(histogram, [], _which, _reverse_prefix), do: histogram

  defp histogram_add(histogram, [line | rest], which, reverse_prefix) do
    new_occurrence =
      case which do
        :one -> {:one, 1, reverse_prefix, rest}
        :other -> {:other, 1, reverse_prefix, rest}
      end

    updated_occurrence =
      case Map.get(histogram, line) do
        nil -> new_occurrence
        previous -> sum_occurrences(previous, new_occurrence)
      end

    histogram
    |> Map.put(line, updated_occurrence)
    |> histogram_add(rest, which, [line | reverse_prefix])
  end

  @doc false
  @spec sum_occurrences(occurrence(), occurrence()) :: occurrence()
  defp sum_occurrences({:one, n, _b1, _a1}, {:one, m, b2, a2}) do
    {:one, n + m, b2, a2}
  end

  defp sum_occurrences({:other, n, _b1, _a1}, {:other, m, b2, a2}) do
    {:other, n + m, b2, a2}
  end

  defp sum_occurrences({:one, n, before_old, after_old}, {:other, m, before_new, after_new}) do
    {:both, n + m, before_old, after_old, before_new, after_new}
  end

  defp sum_occurrences(
         {:both, n, before_old, after_old, _b2, _a2},
         {:other, m, before_new, after_new}
       ) do
    {:both, n + m, before_old, after_old, before_new, after_new}
  end

  # -------------------------
  # LIST UTILITIES (COMMON PREFIX/SUFFIX)
  # -------------------------

  @doc false
  @spec pop_common_prefix([String.t()], [String.t()]) ::
          {[String.t()], [String.t()], [String.t()]}
  defp pop_common_prefix(old_lines, new_lines) do
    {rev_prefix, rest_old, rest_new} = do_pop_common_prefix([], old_lines, new_lines)
    {Enum.reverse(rev_prefix), rest_old, rest_new}
  end

  @doc false
  @spec do_pop_common_prefix([String.t()], [String.t()], [String.t()]) ::
          {[String.t()], [String.t()], [String.t()]}
  defp do_pop_common_prefix(rev_prefix, [old | rest_old], [new | rest_new]) when old == new do
    do_pop_common_prefix([old | rev_prefix], rest_old, rest_new)
  end

  defp do_pop_common_prefix(rev_prefix, old_lines, new_lines) do
    {rev_prefix, old_lines, new_lines}
  end

  @doc false
  @spec pop_common_suffix([String.t()], [String.t()]) ::
          {[String.t()], [String.t()], [String.t()]}
  defp pop_common_suffix(old_lines, new_lines) do
    {suffix, rev_old, rev_new} =
      do_pop_common_prefix([], Enum.reverse(old_lines), Enum.reverse(new_lines))

    {suffix, Enum.reverse(rev_old), Enum.reverse(rev_new)}
  end
end
