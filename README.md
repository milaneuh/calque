# 📝 Calque — Snapshot testing for Elixir

[![Hex.pm Package](https://img.shields.io/hexpm/v/calque.svg)](https://hex.pm/packages/calque)
[![HexDocs](https://img.shields.io/badge/HexDocs-blue.svg)](https://hexdocs.pm/calque/1.3.1/Calque.html)
> **/kalk/** — “Calque” is a French word meaning *tracing paper* or *copy*.
> Like its name, this library lets you trace your program’s output and compare it over time.

Calque makes string-heavy assertions delightful. Pipe your rendered value into `Calque.check/2`,
review the diff the first time it runs, and commit the accepted snapshot so future test runs can
keep you honest.

## Why snapshots?

Snapshot testing lets you quickly verify complex outputs by saving them once and comparing future results automatically. It removes the need for manual assertions and makes changes easy to review through clear diffs, giving faster feedback and stronger confidence against regressions.

On the very first run Calque will save a snapshot under `calque_snapshots/` and fail with the message `📝 Calque snapshot test failed`. Accept the snapshot and every subsequent run compares the current output against that accepted baseline.

## Getting started

Add Calque as a test dependency and fetch it:

```elixir
def deps do
  [
    {:calque, "~> 1.3.1", only: :test}
  ]
end
```

```bash
mix deps.get
```

## Writing snapshot tests

You decide how to turn your value into a string before creating a snapshot, giving you full control over the format and making your snapshots easier to read and review.

```elixir
defmodule MyApp.GreetingTest do
  use ExUnit.Case, async: true
  
  # Example using check/2
  test "renders a friendly greeting" do
    %{hello: "world", nums: [1, 2, 3, 4]}
    |> inspect(pretty: true)
    |> Calque.check("greeting renders correctly")
  end

  # Example using check/1 
  test "say hi to baloo" do
    # The title is automatically set to "say hi to baloo"
    "Hi baloo! You are my favorite bear."
    |> Calque.check()
  end

end
```

Snapshots live alongside your code in `calque_snapshots/`:

- New snapshots are named `<title>.snap`.
- Accepted snapshots become `<title>.accepted.snap` after review.
- Rejected snapshots are renamed to `<title>.rejected.snap` so you can see what you declined.

Calque normalises Windows newlines to Unix newlines during comparison, so cross-platform reviews stay
clean.

## Reviewing snapshots

Calque ships with interactive Mix tasks to help you triage snapshots quickly:

```
mix calque review        # interactive review (alias: mix calque r)
mix calque accept-all    # accept every pending snapshot (alias: mix calque aa)
mix calque reject-all    # reject every pending snapshot (alias: mix calque ra)
mix calque help          # print usage information (alias: mix calque h)
```

Run `mix calque review` after your tests fail. The TUI clears the terminal, shows the diff, and lets
you choose accept, reject, skip, or quit. Batch decisions with `mix calque accept-all` and
`mix calque reject-all` when you already know the answer.

## Inspiration

Calque draws inspiration from the vibrant snapshot testing ecosystem:

- [Birdie](https://github.com/giacomocavalieri/birdie) (Gleam)
- [insta](https://insta.rs) (Rust)
- [Giacomo Cavalieri — *Supercharge your Tests with Snapshot Testing*](https://www.youtube.com/watch?v=DpakV96jeRk)

If you enjoy Calque, give those projects (and talk!) a look for even more snapshot wisdom.
