defmodule Calque.Error do
  @moduledoc false
  alias Calque.Error

  @type t ::
          {:cannot_create_snapshots_folder, term()}
          | {:cannot_read_accepted_snapshot, term(), Path.t()}
          | {:cannot_read_new_snapshot, term(), Path.t()}
          | {:cannot_save_new_snapshot, term(), String.t(), Path.t()}
          | {:cannot_read_snapshots, term(), Path.t()}
          | {:cannot_reject_snapshot, term(), Path.t()}
          | {:cannot_accept_snapshot, term(), Path.t()}
          | {:corrupted_snapshot, Path.t()}
          | :cannot_read_user_input
          | {:cannot_read_user_input, term()}
          | :aborted
          | {:cannot_find_project_root, term()}

  @spec explain(Error.t()) :: String.t()
  def explain(reason), do: "❌ " <> color(:red, format_error(reason))

  @spec format_error(Error.t()) :: String.t()
  def format_error({:cannot_create_snapshots_folder, reason}) do
    "I couldn't create the snapshots folder: #{format_file_error(reason)}"
  end

  def format_error({:cannot_read_accepted_snapshot, reason, source}) do
    "I couldn't read the accepted snapshot from \"#{source}\": #{format_file_error(reason)}"
  end

  def format_error({:cannot_read_new_snapshot, reason, source}) do
    "I couldn't read the new snapshot from \"#{source}\": #{format_file_error(reason)}"
  end

  def format_error({:cannot_save_new_snapshot, reason, title, destination}) do
    "I couldn't save the snapshot \"#{title}\" to \"#{destination}\": #{format_file_error(reason)}"
  end

  def format_error({:cannot_read_snapshots, reason, folder}) do
    "I couldn't read the snapshots directory (#{folder}): #{format_file_error(reason)}"
  end

  def format_error({:cannot_reject_snapshot, reason, path}) do
    "I couldn't reject the snapshot at \"#{path}\": #{format_file_error(reason)}"
  end

  def format_error({:cannot_accept_snapshot, reason, path}) do
    "I couldn't accept the snapshot at \"#{path}\": #{format_file_error(reason)}"
  end

  def format_error(:cannot_read_user_input), do: "I couldn't read the user input"

  def format_error({:cannot_read_user_input, reason}) do
    "I couldn't read the user input: #{format_file_error(reason)}"
  end

  def format_error({:corrupted_snapshot, source}) do
    "The file \"#{source}\" does not contain a valid snapshot"
  end

  # --- helpers ---

  @spec format_file_error(term()) :: String.t()
  def format_file_error(reason) do
    case :file.format_error(reason) do
      ~c"unknown POSIX error" -> inspect(reason)
      charlist -> to_string(charlist)
    end
  end

  @spec color(atom(), String.t()) :: String.t()
  def color(color, text) do
    IO.iodata_to_binary(IO.ANSI.format([color, text, :reset], true))
  end
end
