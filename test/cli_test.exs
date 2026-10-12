defmodule Calque.CLITest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  # Declines the suggestion so the suggested command is never actually run.
  defp run(args), do: capture_io("n\n", fn -> Calque.main(args) end)

  describe "command suggestions" do
    test "suggests the intended command for a misspelling" do
      for {typo, expected} <- [
            {"reviwe", "review"},
            {"revew", "review"},
            {"acept-all", "accept-all"},
            {"rject-all", "reject-all"},
            {"cleen", "clean"},
            {"halp", "help"}
          ] do
        output = run([typo])

        assert output =~ "#{typo} isn't a valid subcommand"
        assert output =~ "misspelled `#{expected}`"
      end
    end

    test "suggests accept-all for a truncated accept" do
      assert run(["accept"]) =~ "misspelled `accept-all`"
    end

    test "ranks by similarity rather than by command name" do
      # "hea" is within three edits of both `help` and `clean`, but is closer to
      # `help` — sorting the candidates by name would have suggested `clean`.
      refute run(["hea"]) =~ "misspelled `clean`"
    end

    test "shows help instead of suggesting for unrelated input" do
      for input <- ["ls", "xyz", "deploy", "status", "eap"] do
        output = run([input])

        assert output =~ "#{input} isn't a valid subcommand"
        refute output =~ "misspelled"
        assert output =~ "USAGE:"
      end
    end
  end
end
