defmodule CalqueIntegrationTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  @folder "calque_snapshots"

  defp strip_ansi(str), do: Regex.replace(~r/\e\[[0-9;]*m/, str, "")

  setup do
    # clean slate
    File.rm_rf!(@folder)
    :ok
  end

  defp snap_path(title), do: Path.join(@folder, title <> ".snap")
  defp accepted_path(title), do: Path.join(@folder, title <> ".accepted.snap")

  defp make_new_snapshot!(title, content) do
    # Calque.check/2 raises on new/different snapshots; we swallow it intentionally.
    assert_raise RuntimeError, fn -> Calque.check(content, title) end
    :ok
  end

  defp accept_snapshot_file!(title) do
    File.mkdir_p!(@folder)
    File.rename!(snap_path(title), accepted_path(title))
  end

  test "second check with identical content returns :ok (no raise)" do
    title = "Identical content"
    content = "This is a snapshot"

    # First call creates *.snap and raises (new snapshot)
    make_new_snapshot!(title, content)
    # Accept it (simulate user pressing 'a')
    accept_snapshot_file!(title)

    # Second call: identical -> :ok (no raise)
    assert :ok = Calque.check(content, title)
    assert File.exists?(accepted_path(title))
    refute File.exists?(snap_path(title))
  end

  test "different content triggers diff and raise with pretty box" do
    title = "Different content"
    old = "line1\nline2"
    new = "line1\nline2\nline3"

    make_new_snapshot!(title, old)
    accept_snapshot_file!(title)

    # Capture the stderr box and assert we see the + line3
    msg =
      capture_io(:stderr, fn ->
        assert_raise RuntimeError, fn -> Calque.check(new, title) end
      end)

    assert msg =~ "mismatched snapshots" or msg =~ "missmatched snapshots"
    assert msg =~ "+ new snapshot"
    assert msg =~ "line3"
  end

  test "Windows CRLF accepted file is parsed correctly" do
    title = "CRLF file"
    content = "hello\r\nworld\r\n"

    # Manually write an accepted file with CRLF
    File.mkdir_p!(@folder)
    # in CalqueIntegrationTest
    accepted_raw =
      IO.iodata_to_binary([
        "---\n",
        "version: 1.0.1\n",
        "title: ",
        title,
        "\n",
        "---\n",
        # content already ends with \r\n; don't add another newline
        content
      ])

    File.write!(accepted_path(title), accepted_raw)

    # And for check, normalize only CRLF to LF (no trimming)
    normalized = String.replace(content, "\r\n", "\n")
    assert :ok = Calque.check(normalized, title)
  end

  test "trailing newline added in new snapshot shows as + empty line in box" do
    title = "Trailing newline grows"
    base = "a"

    make_new_snapshot!(title, base)
    accept_snapshot_file!(title)

    box =
      capture_io(:stderr, fn ->
        assert_raise RuntimeError, fn -> Calque.check(base <> "\n", title) end
      end)

    box_clean = strip_ansi(box)

    assert box_clean =~ "+ new snapshot"

    # Ensure we have line 1 shared and line 2 as an added empty line
    assert box_clean =~ ~r/\n\s*1\s+│\s+a\n/
    assert box_clean =~ ~r/\n\s*2\s+\+\s*\n/
  end

  test "CLI review reviews only .snap files (not accepted/rejected)" do
    title1 = "T1"
    title2 = "T2"

    # Prepare two accepted pairs and re-create .snap for each (to review)
    make_new_snapshot!(title1, "A")
    accept_snapshot_file!(title1)

    make_new_snapshot!(title2, "B")
    accept_snapshot_file!(title2)

    # create delta for T1 & T2 to have *.snap present
    File.write!(snap_path(title1), """
    ---
    version: 1.0.1
    title: #{title1}
    ---
    A\nC
    """)

    File.write!(snap_path(title2), """
    ---
    version: 1.0.1
    title: #{title2}
    ---
    B\nD
    """)

    out =
      capture_io(:stdio, "s\ns\n", fn ->
        # two snapshots -> "Reviewing snapshot 1 of 2" then "... 2 of 2"
        Calque.main(["review"])
      end)

    assert out =~ "Reviewing snapshot 1 of 2"
    assert out =~ "Reviewing snapshot 2 of 2"
    # we don't review accepted files directly
    refute out =~ ".accepted.snap"
  end
end
