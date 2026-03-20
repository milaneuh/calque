defmodule Calque.ErrorTest do
  use ExUnit.Case, async: true
  alias Calque.Error

  describe "format_error/1" do
    test ":snapshot_with_empty_title" do
      assert Error.format_error(:snapshot_with_empty_title) =~ "empty"
    end

    test "{:corrupted_snapshot, path}" do
      msg = Error.format_error({:corrupted_snapshot, "calque_snapshots/foo.accepted.snap"})
      assert msg =~ "valid snapshot"
      assert msg =~ "calque_snapshots/foo.accepted.snap"
    end

    test "{:cannot_create_snapshots_folder, reason}" do
      msg = Error.format_error({:cannot_create_snapshots_folder, :eacces})
      assert msg =~ "snapshots folder"
      assert msg =~ "permission denied"
    end

    test "{:cannot_read_accepted_snapshot, reason, path}" do
      msg =
        Error.format_error({:cannot_read_accepted_snapshot, :enoent, "calque_snapshots/foo.accepted.snap"})

      assert msg =~ "accepted snapshot"
      assert msg =~ "calque_snapshots/foo.accepted.snap"
      assert msg =~ "no such file"
    end

    test "{:cannot_read_new_snapshot, reason, path}" do
      msg = Error.format_error({:cannot_read_new_snapshot, :enoent, "calque_snapshots/foo.snap"})
      assert msg =~ "calque_snapshots/foo.snap"
    end

    test "{:cannot_save_new_snapshot, reason, title, dest}" do
      msg =
        Error.format_error(
          {:cannot_save_new_snapshot, :eacces, "my snapshot", "calque_snapshots/my snapshot.snap"}
        )

      assert msg =~ "my snapshot"
      assert msg =~ "calque_snapshots/my snapshot.snap"
      assert msg =~ "permission denied"
    end

    test "{:cannot_read_user_input, reason}" do
      msg = Error.format_error({:cannot_read_user_input, :eof})
      assert msg =~ "user input"
    end

    test "{:cannot_accept_snapshot, reason, path}" do
      msg = Error.format_error({:cannot_accept_snapshot, :eacces, "calque_snapshots/foo.snap"})
      assert msg =~ "accept"
      assert msg =~ "calque_snapshots/foo.snap"
    end

    test "{:cannot_reject_snapshot, reason, path}" do
      msg = Error.format_error({:cannot_reject_snapshot, :eacces, "calque_snapshots/foo.snap"})
      assert msg =~ "reject"
      assert msg =~ "calque_snapshots/foo.snap"
    end

    test "{:cannot_delete_snapshot, reason, path}" do
      msg = Error.format_error({:cannot_delete_snapshot, :eacces, "calque_snapshots/foo.snap"})
      assert msg =~ "delete"
      assert msg =~ "calque_snapshots/foo.snap"
    end
  end

  describe "explain/1" do
    test "prefixes the message with the error icon" do
      result = Error.explain({:corrupted_snapshot, "some/path.snap"})
      assert String.starts_with?(result, "❌")
    end

    test "includes the formatted message" do
      result = Error.explain(:snapshot_with_empty_title)
      assert result =~ "empty"
    end
  end
end
