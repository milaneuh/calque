defmodule Calque.DiffTest do
  use ExUnit.Case, async: true
  alias Calque.Diff

  describe "Diff.line_by_line/2" do
    test "identical strings produce shared lines" do
      old = "line1\nline2"
      new = "line1\nline2"

      diffs = Diff.line_by_line(old, new)

      assert diffs == [
               %{number: 1, line: "line1", kind: :shared},
               %{number: 2, line: "line2", kind: :shared}
             ]
    end

    test "extra lines in new are handled correctly" do
      old = "line1\nline2"
      new = "line1\nline2\nline3"

      diffs = Diff.line_by_line(old, new)

      assert diffs == [
               %{number: 1, line: "line1", kind: :shared},
               %{number: 2, line: "line2", kind: :shared},
               %{number: 3, line: "line3", kind: :new}
             ]
    end

    test "extra lines in old are handled correctly" do
      old = "line1\nline2\nline3"
      new = "line1\nline2"

      diffs = Diff.line_by_line(old, new)

      assert diffs == [
               %{number: 1, line: "line1", kind: :shared},
               %{number: 2, line: "line2", kind: :shared},
               %{number: 3, line: "line3", kind: :old}
             ]
    end

    test "changed line at same index yields two entries: old then new" do
      old = "same\nold"
      new = "same\nNEW"

      diffs = Diff.line_by_line(old, new)

      assert diffs == [
               %{number: 1, line: "same", kind: :shared},
               %{number: 2, line: "old", kind: :old},
               %{number: 2, line: "NEW", kind: :new}
             ]
    end

    test "preserves trailing empty line differences (trim: false)" do
      old = "a"
      # new has an extra trailing empty line
      new = "a\n"

      diffs = Diff.line_by_line(old, new)

      assert diffs == [
               %{number: 1, line: "a", kind: :shared},
               %{number: 2, line: "", kind: :new}
             ]
    end

    test "both sides trailing newline -> shared empty line" do
      old = "a\n"
      new = "a\n"

      diffs = Diff.line_by_line(old, new)

      assert diffs == [
               %{number: 1, line: "a", kind: :shared},
               %{number: 2, line: "", kind: :shared}
             ]
    end

    test "handles unicode safely and flags changed line (no inline coloring here)" do
      old = "café"
      new = "cafe"

      diffs = Diff.line_by_line(old, new)

      assert diffs == [
               %{number: 1, line: "café", kind: :old},
               %{number: 1, line: "cafe", kind: :new}
             ]
    end

    test "empty inputs" do
      assert Diff.line_by_line("", "") == [%{number: 1, line: "", kind: :shared}]
      assert Diff.line_by_line("", "x") == [%{number: 1, line: "x", kind: :new}]
      assert Diff.line_by_line("x", "") == [%{number: 1, line: "x", kind: :old}]
    end
  end
end
