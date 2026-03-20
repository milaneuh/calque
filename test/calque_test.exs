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

  test "Checking a complex snapshot" do
    """
    case action do
      :left -> slide_to_the_left()
      :right -> slide_to_the_right()
      _ -> criss_cross()
    end
    """
    |> Calque.check()
  end

  test "Checking a keyword list" do
    [name: "Alice", role: :admin, age: 30]
    |> inspect(pretty: true)
    |> Calque.check()
  end

  test "Checking a nested map" do
    %{
      user: %{name: "Bob", email: "bob@example.com"},
      permissions: [:read, :write],
      metadata: %{created_at: "2024-01-01", version: 2}
    }
    |> inspect(pretty: true)
    |> Calque.check()
  end

  test "Checking an error tuple" do
    {:error, {:cannot_connect, :econnrefused, "localhost:5432"}}
    |> inspect()
    |> Calque.check()
  end

  test "Checking a list of maps" do
    [
      %{id: 1, status: :pending, label: "first"},
      %{id: 2, status: :done, label: "second"},
      %{id: 3, status: :failed, label: "third"}
    ]
    |> inspect(pretty: true)
    |> Calque.check()
  end

  test "Checking unicode content" do
    "Héllo wörld — こんにちは 🌍"
    |> Calque.check()
  end

  test "Checking a multiline formatted string" do
    """
    Name    │ Score │ Grade
    ────────┼───────┼──────
    Alice   │    95 │ A
    Bob     │    82 │ B
    Charlie │    74 │ C
    """
    |> Calque.check()
  end

  describe "check/2 — error cases" do
    test "raises when title is empty" do
      assert_raise ExUnit.AssertionError, fn ->
        Calque.check("some content", "")
      end
    end

    test "creates a .snap file and raises when no accepted snapshot exists" do
      title = "calque-internal-new-snapshot-test"
      pending_path = Path.join("calque_snapshots", "#{title}.snap")
      File.rm(pending_path)
      on_exit(fn -> File.rm(pending_path) end)

      assert_raise RuntimeError, "Calque snapshot test failed", fn ->
        Calque.check("brand new content", title)
      end

      assert File.exists?(pending_path)
    end

    test "raises when content differs from accepted snapshot" do
      title = "calque-internal-mismatch-test"
      accepted_path = Path.join("calque_snapshots", "#{title}.accepted.snap")
      pending_path = Path.join("calque_snapshots", "#{title}.snap")

      on_exit(fn ->
        File.rm(accepted_path)
        File.rm(pending_path)
      end)

      File.write!(
        accepted_path,
        "---\nversion: test\ntitle: #{title}\nsource: test/calque_test.exs:1\n---\noriginal content"
      )

      assert_raise RuntimeError, "Calque snapshot test failed", fn ->
        Calque.check("different content", title)
      end
    end

    test "CRLF in accepted snapshot is normalized and matches LF content" do
      title = "calque-internal-crlf-test"
      accepted_path = Path.join("calque_snapshots", "#{title}.accepted.snap")
      on_exit(fn -> File.rm(accepted_path) end)

      header = "---\nversion: test\ntitle: #{title}\nsource: test/calque_test.exs:1\n---\n"
      File.write!(accepted_path, header <> "hello\r\nworld")

      assert Calque.check("hello\nworld", title) == :ok
    end
  end
end
