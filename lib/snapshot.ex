defmodule Calque.Snapshot do
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
