⚠️ This library is a work in progress, it is not yet available on hex ⚠️

# 📝 Calque — Snapshot testing for Elixir

> **/kalk/** — “Calque” is a French word meaning *tracing paper* or *copy*.  
> Like its name, this library lets you trace your program’s output and compare it over time.

**Calque** lets you assert on complex outputs without hand-crafting expected values.  
On first run, Calque stores a **snapshot**; subsequent runs compare against it and show a reviewable diff.

Think of it as:

> You focus on producing the result. Calque stores it, compares it later, and helps you review changes.

Inspired by **Insta (Rust)** and **Birdie (Gleam)** — simple, expressive, and pleasant to use.

---

## ✨ Features

- **Zero-friction assertions** — write `snapshot!(value)` and move on.  
- **Readable diffs** — pretty boxes highlighting `+` additions and `-` deletions.  
- **CLI review loop** — accept (`a`), reject (`r`), skip (`s`) or quit (`q`) interactively.  
- **Deterministic output** — optional normalizers/formatters for stable snapshots.  
- **Project-local storage** — snapshots live under `calque_snapshots/` by default.  
- **ExUnit friendly** — drop-in helpers for clean test integration.  
- **CI-ready** — fail the build on mismatches, review locally, then re-run.

---

## 🔧 Installation

Add **Calque** to your `mix.exs`:

```elixir
def deps do
  [
    {:calque, "~> 1.0.0", only: :test}
  ]
end
```

Then:

```bash
mix deps.get
```

---

## 🚀 Quick start

```elixir
defmodule MyApp.FancyRenderTest do
  use ExUnit.Case, async: true

  test "renders a friendly greeting" do
    got =
      %{
        hello: "world",
        nums: [1, 2, 3, 4]
      }
      |> inspect(pretty: true)
      |> Calque.snapshot()
  end
end
```

First run: Calque writes a new snapshot.
Next runs: Calque diffs the current output against the saved snapshot.

---

## 🖥️ CLI review

When tests detect **new** or **mismatched** snapshots, Calque prints a friendly hint:

```
📝 Calque snapshot test failed

── new snapshot ───────────────────────────────────────────────────────────────
... content ...
```

Start the review loop:

```bash
mix calque review
```

You'll see an interactive UI:

```
Reviewing snapshot 1 of 2

── mismatched snapshot ────────────────────────────────────────────────────────

title:  My first snapshot ! :D    

- old snapshot  
+ new snapshot
-------┬-----------------------------------------------------------------------
   1 - hello: "world"
   1 + hello: "world!!"
-------┴-----------------------------------------------------------------------

  a accept    r reject    s skip    q quit
```

- Press `a` to accept and update the stored snapshot
- Press `r` to reject (keeps the stored snapshot)
- Press `s` to skip and continue
- Press `q` to quit the interactive review

---

## 🖍️ Writing great snapshot tests

- Prefer stable, pretty representation. Do not hesitate to make your own !
- Use normalizers to remove volatile data (timestamps, random IDS)
- Keep **titles** meaningful and unique for easier review
- Treat snapshots as part of your spec -- commit them with version control

---

## 🫶 Inspirations and acknowledgments

[![Birdie (Gleam)](https://github.com/giacomocavalieri/birdie)
[![Insta (Rust)](https://github.com/mitsuhiko/insta)
[![Giacomo Cavalieri’s talk “Supercharge your tests with Snapshot Testing”](https://www.youtube.com/watch?v=DpakV96jeRk)
