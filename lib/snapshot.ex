defmodule Calque.Snapshot do
  @moduledoc """
  Represents a **snapshot** — a saved version of output data used by Calque’s
  snapshot testing system.

  A snapshot encapsulates:
  - `:title` — A human-readable identifier, often matching the test name.
  - `:content` — The stringified output captured during the test run.
  - `:status` — Either `:new` (freshly generated and unreviewed) or `:accepted`
    (already validated and stored).

  This module provides simple constructors to ensure consistent initialization:
  - `new/2` — Creates a new, unaccepted snapshot.
  - `accepted/2` — Builds an accepted snapshot loaded from disk.

  Snapshots are immutable data structures; their lifecycle and comparison logic
  are handled by higher-level modules such as `Calque` and `Calque.Diff`.
  """

  @enforce_keys [:title, :content, :status]
  defstruct [:title, :content, :status]

  @type t :: %__MODULE__{title: String.t(), content: String.t(), status: :new | :accepted}

  @spec new(String.t(), String.t()) :: t
  def new(title, content) do
    %__MODULE__{title: title, content: content, status: :new}
  end

  @spec accepted(String.t(), String.t()) :: t
  def accepted(title, content) do
    %__MODULE__{title: title, content: content, status: :accepted}
  end
end
