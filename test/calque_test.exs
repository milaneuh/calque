defmodule CalqueTest do
  require Calque
  use ExUnit.Case
  doctest Calque

  test "Exemple 1" do
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
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

  test "This is a snapshot test testing the macro" do
    %{title: "This is a snapshot test checking a map"}
    |> inspect()
    |> Calque.check()
  end
end
