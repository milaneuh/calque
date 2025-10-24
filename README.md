# 🎨 Calque — Snapshot testing for Elixir

[![Hex.pm Package](https://img.shields.io/hexpm/v/calque.svg)](https://hex.pm/packages/calque)
[![HexDocs](https://img.shields.io/badge/HexDocs-blue.svg)](https://hexdocs.pm/calque/1.0.1/Calque.html)
> **/kalk/** — “Calque” is a French word meaning *tracing paper* or *copy*.
> Like its name, this library lets you trace your program’s output and compare it over time.

Calque makes string-heavy assertions delightful. Pipe your rendered value into `Calque.check/2`,
review the diff the first time it runs, and commit the accepted snapshot so future test runs can
keep you honest.

## ✨ Why snapshots?

- ✅ Capture large or noisy output without hand-writing long expectations.
- ✅ Review changes visually with rich diffs instead of squinting at a single assertion.
- ✅ Lock in formatting and serialization decisions across releases.

On the very first run Calque will save a snapshot under `calque_snapshots/` and fail with the
message `📝 Calque snapshot test failed`. Accept the snapshot and every subsequent run compares the
current output against that accepted baseline.

## 🚀 Getting started

Add Calque as a test dependency and fetch it:

```elixir
def deps do
  [
    {:calque, "~> 1.0.1", only: :test}
  ]
end
```

```bash
mix deps.get
```

## 🧪 Writing snapshot tests

Any value you can turn into a string can become a snapshot. `inspect/2` works great for Elixir data
structures, but feel free to render however you like before calling `Calque.check/2`:

```elixir
defmodule MyApp.GreetingTest do
  use ExUnit.Case, async: true

  test "renders a friendly greeting" do
    %{hello: "world", nums: [1, 2, 3, 4]}
    |> inspect(pretty: true)
    |> Calque.check("greeting renders correctly")
  end
end
```

Snapshots live alongside your code in `calque_snapshots/`:

- New snapshots are named `<title>.snap`.
- Accepted snapshots become `<title>.accepted.snap` after review.
- Rejected snapshots are renamed to `<title>.rejected.snap` so you can see what you declined.

Calque normalises Windows newlines to Unix newlines during comparison, so cross-platform reviews stay
clean.

## 🕹️ Reviewing snapshots

Calque ships with interactive Mix tasks to help you triage snapshots quickly:

```text
mix calque review        # interactive review (alias: mix calque r)
mix calque accept-all    # accept every pending snapshot (alias: mix calque aa)
mix calque reject-all    # reject every pending snapshot (alias: mix calque ra)
mix calque help          # print usage information (alias: mix calque h)
```

Run `mix calque review` after your tests fail. The TUI clears the terminal, shows the diff, and lets
you choose accept, reject, skip, or quit. Batch decisions with `mix calque accept-all` and
`mix calque reject-all` when you already know the answer.

## 🗂️ Recommended workflow

1. 🧪 `mix test`
2. 🔍 Inspect the diff Calque prints when a snapshot changes.
3. 🎛️ Run `mix calque review` to accept, reject, or skip each pending snapshot.
4. 📦 Commit accepted snapshots alongside the change that produced them.

## 💡 Tips for reliable snapshots

- ✂️ Strip timestamps, random IDs, and other volatile data before snapshotting.
- 🏷️ Keep titles unique and descriptive—the title becomes the filename.
- 🧾 Treat accepted snapshots like source: review them in PRs and keep them under version control.

## 🙌 Inspiration

Calque draws inspiration from the vibrant snapshot testing ecosystem:

- 🐦‍⬛ [Birdie](https://github.com/giacomocavalieri/birdie) (Gleam)
- 🦀 [insta](https://insta.rs) (Rust)
- 🎙️ [Giacomo Cavalieri — *Supercharge your Tests with Snapshot Testing *](https://www.youtube.com/watch?v=DpakV96jeRk)

If you enjoy Calque, give those projects (and talk!) a look for even more snapshot wisdom.
