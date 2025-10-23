defmodule Calque.Diff do
  @moduledoc """
  Robust line-by-line diff that returns plain maps with kind metadata (no ANSI).
  Coloring is handled by the UI layer (Calque.pretty_diff_line/2).
  """

  @type diff_line_kind :: :old | :new | :shared
  @type diff_line :: %{number: pos_integer(), line: String.t(), kind: diff_line_kind()}

  @doc """
  Compare two multiline strings line by line and return a flat list of lines.

  For each index:
    * if both sides present and equal    -> one `:shared` line
    * if only old present                -> one `:old` line
    * if only new present                -> one `:new` line
    * if both present but different      -> two lines: first `:old`, then `:new`
  """
  @spec line_by_line(String.t(), String.t()) :: [diff_line()]
  def line_by_line(old, new) when is_binary(old) and is_binary(new) do
    # Degenerate case: both empty -> one shared empty line
    if old == "" and new == "" do
      [%{number: 1, line: "", kind: :shared}]
    else
      # Treat a totally empty side as "no lines" (not [""])
      old_lines =
        if old == "" do
          []
        else
          String.split(old, "\n", trim: false)
        end

      new_lines =
        if new == "" do
          []
        else
          String.split(new, "\n", trim: false)
        end

      max_len = max(length(old_lines), length(new_lines))

      0..(max_len - 1)
      |> Enum.flat_map(fn i ->
        n = i + 1
        old_line = Enum.at(old_lines, i, nil)
        new_line = Enum.at(new_lines, i, nil)

        cond do
          not is_nil(old_line) and not is_nil(new_line) and old_line == new_line ->
            [%{number: n, line: old_line, kind: :shared}]

          not is_nil(old_line) and is_nil(new_line) ->
            [%{number: n, line: old_line, kind: :old}]

          is_nil(old_line) and not is_nil(new_line) ->
            [%{number: n, line: new_line, kind: :new}]

          true ->
            [
              %{number: n, line: old_line, kind: :old},
              %{number: n, line: new_line, kind: :new}
            ]
        end
      end)
    end
  end

  # permissive fallback
  def line_by_line(_, _), do: []
end
