defmodule CalqueTest do
  use ExUnit.Case
  doctest Calque

  test "Exemple 1" do
    [1, 2, 3, 4]
    |> Enum.join(",")
    |> Calque.check("Checking a list of numbers")
  end

  test "Exemple 2" do
    {:ok, 13}
    |> inspect()
    |> Calque.check("Checking my favorite number wrap into a tuple")
  end

  test "Exemple 3" do
    "Check this !"
    |> Calque.check("my first snapshot")
  end
end
