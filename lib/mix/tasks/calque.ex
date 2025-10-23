defmodule Mix.Tasks.Calque do
  use Mix.Task

  @shortdoc "Run Calque CLI for snapshot review and management"

  @moduledoc """
  CLI interface for Calque snapshots.

  Usage:
    mix calque review        # Interactive snapshot review
    mix calque accept-all    # Accept all new snapshots
    mix calque reject-all    # Reject all new snapshots
    mix calque help          # Show help
  """

  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    Calque.main(args)
  end
end
