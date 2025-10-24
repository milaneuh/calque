defmodule Calque.Diff do
  @moduledoc """
  Utilities to render simple line-by-line diffs used by Calque's CLI output.
  """

  @type diff_line_kind :: :old | :new | :shared
  @type diff_line :: %{number: pos_integer(), line: String.t(), kind: diff_line_kind()}

  @doc false
  @spec line_by_line(String.t(), String.t()) :: [diff_line()]
  def line_by_line("", ""), do: [%{number: 1, line: "", kind: :shared}]

  def line_by_line(old, new) when is_binary(old) and is_binary(new) do
    old
    |> split_lines()
    |> build_diff(split_lines(new))
  end

  def line_by_line(_, _), do: []

  @spec split_lines(String.t()) :: [String.t()]
  defp split_lines(""), do: []
  defp split_lines(text), do: String.split(text, "\n", trim: false)

  @spec build_diff([String.t()], [String.t()]) :: [diff_line()]
  defp build_diff([], []), do: []

  defp build_diff(old_lines, new_lines) do
    max_len = max(length(old_lines), length(new_lines))

    0..(max_len - 1)
    |> Enum.flat_map(&diff_entry(&1, old_lines, new_lines))
  end

  @spec diff_entry(non_neg_integer(), [String.t()], [String.t()]) :: [diff_line()]
  defp diff_entry(index, old_lines, new_lines) do
    number = index + 1
    old_line = Enum.at(old_lines, index)
    new_line = Enum.at(new_lines, index)

    case {old_line, new_line} do
      {nil, nil} ->
        []

      {line, line} when not is_nil(line) ->
        [%{number: number, line: line, kind: :shared}]

      {line, nil} when not is_nil(line) ->
        [%{number: number, line: line, kind: :old}]

      {nil, line} when not is_nil(line) ->
        [%{number: number, line: line, kind: :new}]

      {old_line, new_line} ->
        [
          %{number: number, line: old_line, kind: :old},
          %{number: number, line: new_line, kind: :new}
        ]
    end
  end
end
