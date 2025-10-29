defmodule Calque do
  @moduledoc """
  Calque — a lightweight snapshot testing and review tool for Elixir projects.

  Calque allows you to:
  - **Record** test outputs as snapshot files (`*.snap`)
  - **Compare** new outputs against previously accepted snapshots
  - **Review and accept/reject** snapshots interactively from the CLI

  ## Typical usage

      Calque.check(result, "my test title")

  If no accepted snapshot exists, Calque will create one and fail the test,
  prompting you to review it with:

      mix calque review

  Calque stores all snapshots under `calque_snapshots/` in your project root.

  ## CLI commands

  - `mix calque review` — review new or changed snapshots interactively
  - `mix calque accept-all` — accept all pending snapshots
  - `mix calque reject-all` — reject all pending snapshots
  - `mix calque help` — show CLI usage information

  ---
  """

  alias Calque.{Diff, Error, Levenshtein, Snapshot}

  @type snapshot :: Snapshot.t()

  @version "1.3.0"
  @snapshot_folder "calque_snapshots"
  @snapshot_test_failed_message "Calque snapshot test failed"
  @hint_review_message "Please review this snapshot using `mix calque review`"

  @doc """
  Performs a snapshot test with the given title, saving the content to a new
  snapshot file and comparing it to the accepted one.

  The `check/1` macro is usually preferred for convenience, as it automatically
  infers the snapshot title from the calling function.

  ## Parameters

  * `content` — The stringified output to snapshot.
  * `title` — A unique identifier (string) for the snapshot. This is often the test name.

  ## Returns

  * `:ok` — If the output matches the accepted snapshot.
  * **Raises an error** (`no_return()`) — If a new snapshot is created or the content
      differs from the accepted snapshot.
  """

  @spec check(String.t(), String.t()) :: :ok | no_return()
  def check(content, title) do
    case do_check(content, title) do
      {:ok, :same} ->
        :ok

      {:ok, {:new_snapshot_created, %{snapshot: snapshot}}} ->
        hint_message = hint_text(@hint_review_message)

        hint = %{
          type: :info_line_with_title,
          content: hint_message,
          split: :no_split,
          title: "hint"
        }

        box = new_snapshot_box(snapshot, [hint])

        IO.puts(:stderr, "\n\n#{box}\n")
        raise(@snapshot_test_failed_message)

      {:ok, {:different, %{accepted: accepted, new: new}}} ->
        hint_message = hint_text(@hint_review_message)

        hint = %{
          type: :info_line_with_title,
          content: hint_message,
          split: :no_split,
          title: "hint"
        }

        box = diff_snapshot_box(accepted, new, [hint])

        IO.puts(:stderr, "\n\n#{box}\n")
        raise(@snapshot_test_failed_message)

      {:error, error} ->
        IO.puts(:stderr, "\n" <> Error.explain(error) <> "\n")
        IO.puts(@snapshot_test_failed_message)
        fail!("snapshot #{inspect(title)} failed: #{Error.format_error(error)}")
    end
  end

  @doc """
  Performs a snapshot test using the **calling function name** as the snapshot title.

  This macro is a **convenience shorthand** for `check/2`, where the required
  `title` parameter is automatically derived from the function in which the macro is
  called (e.g., the `test` block name in `ExUnit`).

  It behaves exactly like `check/2`, comparing the given content to the accepted
  snapshot and raising an error if a new or differing snapshot is found.

  ## Parameters

  * `content` — The stringified output to snapshot.

  ## Returns

  * `:ok` — If the output matches the accepted snapshot.
  * **Raises an error** (`no_return()`) — If a new snapshot is created or the content
    differs from the accepted snapshot.
  """

  @spec check(term(), String.t()) :: :ok | no_return()
  defmacro check(content) do
    defining_mod = __MODULE__
    {fun_name, _arity} = __CALLER__.function || {:no_function, 0}

    title = to_string(fun_name)

    quote do
      unquote(defining_mod).check(unquote(content), unquote(title))
    end
  end

  # -------------------------
  # INTERNAL LOGIC
  # -------------------------

  @doc false
  @spec do_check(String.t(), String.t()) ::
          {:ok, :same | {:new_snapshot_created, map()} | {:different, map()}}
          | {:error, Error.t()}
  defp do_check(content, title) do
    with {:ok, title} <- verify_title(title),
         {:ok, folder} <- find_snapshots_folder(),
         snapshot <- Snapshot.new(title, content),
         new_snapshot_path <- new_destination(snapshot, folder),
         accepted_snapshot_path <- to_accepted_path(new_snapshot_path),
         {:ok, accepted} <- read_accepted(accepted_snapshot_path) do
      case accepted do
        nil ->
          with :ok <- save(snapshot, new_snapshot_path) do
            {:ok, {:new_snapshot_created, %{snapshot: snapshot, path: new_snapshot_path}}}
          end

        %Snapshot{} = accepted_snapshot ->
          if normalize_body(accepted_snapshot.content) == normalize_body(content) do
            cleanup_if_present(new_snapshot_path)
            {:ok, :same}
          else
            with :ok <- save(snapshot, new_snapshot_path) do
              {:ok,
               {:different,
                %{
                  accepted: accepted_snapshot,
                  new: snapshot,
                  path: new_snapshot_path
                }}}
            end
          end
      end
    end
  end

  @doc false
  @spec verify_title(binary() | nil) :: {:ok, binary()} | {:error, Error.t()}
  defp verify_title(nil), do: {:error, :snapshot_with_empty_title}
  defp verify_title(""), do: {:error, :snapshot_with_empty_title}
  defp verify_title(title), do: {:ok, title}

  @doc false
  @spec normalize_body(binary()) :: binary()
  defp normalize_body(str) when is_binary(str) do
    String.replace(str, "\r\n", "\n")
  end

  @doc false
  @spec fail!(binary()) :: no_return()
  defp fail!(message) do
    if Code.ensure_loaded?(ExUnit.AssertionError) do
      raise ExUnit.AssertionError, message: message
    else
      raise message: message
    end
  end

  # -------------------------
  # FILE OPERATIONS
  # -------------------------

  @doc false
  @spec read_accepted(Path.t()) :: {:ok, snapshot | nil} | {:error, Error.t()}
  defp read_accepted(path) do
    case File.read(path) do
      {:ok, content} ->
        case deserialise(content, :accepted) do
          {:ok, snapshot} -> {:ok, snapshot}
          {:error, :invalid_snapshot} -> {:error, {:corrupted_snapshot, path}}
        end

      {:error, :enoent} ->
        {:ok, nil}

      {:error, reason} ->
        {:error, {:cannot_read_accepted_snapshot, reason, path}}
    end
  end

  @doc false
  @spec cleanup_if_present(Path.t()) :: :ok
  defp cleanup_if_present(path) do
    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, _} -> :ok
    end
  end

  @doc false
  @spec save(snapshot, Path.t()) :: :ok | {:error, Error.t()}
  defp save(%Snapshot{status: :new} = snapshot, destination) do
    # We store new snapshots as *.snap. Accepted snapshots are *.accepted.snap.
    cond do
      String.ends_with?(destination, ".accepted.snap") ->
        {:error, {:cannot_save_new_snapshot, :invalid_destination, snapshot.title, destination}}

      String.ends_with?(destination, ".snap") ->
        with :ok <- ensure_parent_directory(destination),
             :ok <- File.write(destination, serialise(snapshot)) do
          :ok
        else
          {:error, reason} ->
            {:error, {:cannot_save_new_snapshot, reason, snapshot.title, destination}}
        end

      true ->
        {:error, {:cannot_save_new_snapshot, :invalid_destination, snapshot.title, destination}}
    end
  end

  @doc false
  @spec ensure_parent_directory(Path.t()) :: :ok | {:error, term()}
  defp ensure_parent_directory(path) do
    path
    |> Path.dirname()
    |> File.mkdir_p()
  end

  @doc false
  @spec find_snapshots_folder() :: {:ok, Path.t()} | {:error, Error.t()}
  defp find_snapshots_folder do
    case File.mkdir_p(@snapshot_folder) do
      :ok ->
        case File.stat(@snapshot_folder) do
          {:ok, %File.Stat{type: :directory}} ->
            {:ok, @snapshot_folder}

          {:ok, _} ->
            {:error, {:cannot_create_snapshots_folder, :not_a_directory}}

          {:error, reason} ->
            {:error, {:cannot_create_snapshots_folder, reason}}
        end

      {:error, reason} ->
        {:error, {:cannot_create_snapshots_folder, reason}}
    end
  end

  @doc false
  @spec new_destination(snapshot, Path.t()) :: Path.t()
  defp new_destination(%Snapshot{} = snapshot, folder),
    do: Path.join(folder, safe_basename(snapshot.title) <> ".snap")

  @doc false
  @spec safe_basename(binary()) :: binary()
  defp safe_basename(title) do
    title
    |> String.replace(~r/[\/\\]/u, "⧸")
    |> String.replace(~r/[^[:alnum:]\- _.!+:]/u, "_")
    |> String.trim()
    |> String.replace(~r/\s+/u, " ")
  end

  @doc false
  @spec to_accepted_path(Path.t()) :: Path.t()
  defp to_accepted_path(path), do: String.replace_suffix(path, ".snap", ".accepted.snap")

  # -------------------------
  # SNAPSHOT DE/SERIALIZATION
  # -------------------------

  @doc false
  @spec serialise(snapshot) :: binary()
  defp serialise(%Snapshot{title: title, content: content}) do
    escaped_title = String.replace(title, "\n", "\\n")

    [
      "---",
      "version: #{@version}",
      "title: #{escaped_title}",
      "---",
      content
    ]
    |> Enum.join("\n")
  end

  @doc false
  @spec deserialise(binary(), :new | :accepted) ::
          {:ok, snapshot} | {:error, :invalid_snapshot}
  defp deserialise(raw, status) when status in [:new, :accepted] do
    raw = String.replace(raw, "\r\n", "\n")

    with {:ok, {open_line, rest}} <- split_once(raw),
         true <- open_line == "---",
         {:ok, {_version_line, rest}} <- split_once(rest),
         {:ok, {title_line, rest}} <- split_once(rest),
         "title: " <> escaped_title <- title_line,
         {:ok, {close_line, content}} <- split_once(rest),
         true <- close_line == "---" do
      title = String.replace(escaped_title, "\\n", "\n")
      {:ok, build_snapshot(title, content, status)}
    else
      _ -> {:error, :invalid_snapshot}
    end
  end

  @doc false
  @spec build_snapshot(binary(), binary(), :new | :accepted) :: snapshot
  defp build_snapshot(title, content, :new), do: Snapshot.new(title, content)
  defp build_snapshot(title, content, :accepted), do: Snapshot.accepted(title, content)

  @doc false
  @spec split_once(binary()) :: {:ok, {binary(), binary()}} | {:error, nil}
  defp split_once(str) do
    case String.split(str, "\n", parts: 2) do
      [first, rest] -> {:ok, {first, rest}}
      [_] -> {:error, nil}
      [] -> {:error, nil}
    end
  end

  # -------------------------
  # SNAPSHOT DIFFING
  # -------------------------

  @doc false
  @spec snapshot_body(snapshot) :: binary()
  defp snapshot_body(%Snapshot{content: content}), do: snapshot_body(content)

  @doc false
  @spec snapshot_body(binary()) :: binary()
  defp snapshot_body(content) when is_binary(content) do
    content
    |> String.replace("\r\n", "\n")
    |> String.replace(~r/\A---\n(?s:.*?)---\n/u, "")
  end

  @doc false
  @spec to_diff_lines(snapshot, snapshot) ::
          [%{number: non_neg_integer(), line: binary(), kind: :shared | :new | :old}]
  defp to_diff_lines(%Snapshot{} = accepted, %Snapshot{} = new) do
    accepted_body = snapshot_body(accepted)
    new_body = snapshot_body(new)
    Diff.line_by_line(accepted_body, new_body)
  end

  # -------------------------
  # PRETTY PRINTING
  # -------------------------

  @doc false
  @spec hint_text(binary()) :: binary()
  defp hint_text(message), do: IO.ANSI.yellow() <> message <> IO.ANSI.reset()

  @doc false
  @spec new_snapshot_box(snapshot, list(map())) :: binary()
  defp new_snapshot_box(%Snapshot{} = snapshot, additional_info_lines) do
    body = snapshot_body(snapshot)

    content_lines =
      body
      |> String.split("\n", trim: false)
      |> Enum.with_index()
      |> Enum.map(fn {line, i} -> %{number: i + 1, line: line, kind: :new} end)

    info_lines =
      [
        %{
          type: :info_line_with_title,
          content: snapshot.title,
          split: :split_words,
          title: "title"
        }
      ] ++ List.wrap(additional_info_lines)

    pretty_box("new snapshot", content_lines, info_lines)
  end

  @doc false
  @spec diff_snapshot_box(snapshot, snapshot, list(map())) :: binary()
  defp diff_snapshot_box(%Snapshot{} = accepted, %Snapshot{} = new, additional_info_lines) do
    info_lines =
      [
        %{
          type: :info_line_with_title,
          content: new.title,
          split: :split_words,
          title: "title"
        }
      ] ++
        List.wrap(additional_info_lines) ++
        [
          %{type: :info_line_without_title, content: "", split: :no_split},
          %{
            type: :info_line_without_title,
            content: IO.ANSI.red() <> "- old snapshot" <> IO.ANSI.reset(),
            split: :no_split
          },
          %{
            type: :info_line_without_title,
            content: IO.ANSI.green() <> "+ new snapshot" <> IO.ANSI.reset(),
            split: :no_split
          }
        ]

    pretty_box("mismatched snapshots", to_diff_lines(accepted, new), info_lines)
  end

  @doc false
  @spec pretty_box(
          binary(),
          [%{number: non_neg_integer(), line: binary(), kind: :shared | :new | :old}],
          list(map())
        ) :: binary()
  defp pretty_box(title, content_lines, info_lines) do
    terminal_width =
      case :io.columns() do
        {:ok, w} when is_integer(w) and w > 20 -> w
        _ -> 80
      end

    lines_count = length(content_lines) + 1
    digits_count = Integer.digits(lines_count) |> length()
    padding = digits_count * 2 + 5

    title_length = String.length(title)
    title_line_right = String.duplicate("─", max(terminal_width - 5 - title_length, 0))
    title_line = "── " <> title <> " ─" <> title_line_right

    info_lines = Enum.map(info_lines, &pretty_info_line(&1, terminal_width))

    content = Enum.map_join(content_lines, "\n", &pretty_diff_line(&1, padding))

    left_padding_line = String.duplicate("─", padding)
    right_padding_line = String.duplicate("─", terminal_width - padding - 1)
    open_line = left_padding_line <> "┬" <> right_padding_line
    closed_line = left_padding_line <> "┴" <> right_padding_line

    Enum.join(
      [
        title_line,
        "",
        Enum.join(info_lines, "\n"),
        "",
        open_line,
        content,
        closed_line
      ],
      "\n"
    )
  end

  @doc false
  @spec pretty_info_line(
          %{
            type: :info_line_with_title,
            title: binary(),
            content: binary(),
            split: :no_split | :split_words | :truncate
          },
          pos_integer()
        ) :: binary()
  defp pretty_info_line(
         %{type: :info_line_with_title, title: title, content: content, split: split},
         width
       ) do
    title_length = String.length(title)

    line_doc =
      case split do
        :no_split ->
          content

        :split_words ->
          content |> String.split("\n") |> Enum.join(" ")

        :truncate ->
          max_len = width - title_length - 6

          if String.length(content) <= max_len,
            do: content,
            else: String.slice(content, 0, max_len - 3) <> "..."
      end

    IO.ANSI.blue() <> "  " <> title <> ": " <> IO.ANSI.reset() <> " " <> line_doc
  end

  @doc false
  @spec pretty_info_line(
          %{
            type: :info_line_without_title,
            content: binary(),
            split: :no_split | :split_words | :truncate
          },
          pos_integer()
        ) :: binary()
  defp pretty_info_line(%{type: :info_line_without_title, content: content, split: split}, width) do
    line_doc =
      case split do
        :no_split ->
          content

        :split_words ->
          content |> String.split("\n") |> Enum.join(" ")

        :truncate ->
          max_len = width - 6

          if String.length(content) <= max_len,
            do: content,
            else: String.slice(content, 0, max_len - 3) <> "..."
      end

    "  " <> line_doc
  end

  @doc false
  @spec pretty_diff_line(
          %{number: non_neg_integer(), line: binary(), kind: :shared | :new | :old},
          pos_integer()
        ) :: binary()
  defp pretty_diff_line(%{number: number, line: line, kind: kind}, padding) do
    {pretty_number, pretty_line, separator} =
      case kind do
        :shared ->
          number_str = pad_left(Integer.to_string(number), padding - 1)

          {
            IO.ANSI.faint() <> number_str <> IO.ANSI.reset(),
            IO.ANSI.faint() <> line <> IO.ANSI.reset(),
            " │ "
          }

        :new ->
          number_str = pad_left(Integer.to_string(number), padding - 1)

          {
            IO.ANSI.green() <> IO.ANSI.bright() <> number_str <> IO.ANSI.reset(),
            IO.ANSI.green() <> line <> IO.ANSI.reset(),
            IO.ANSI.green() <> " + " <> IO.ANSI.reset()
          }

        :old ->
          number_str = pad_right(" " <> Integer.to_string(number), padding - 1)

          {
            IO.ANSI.red() <> number_str <> IO.ANSI.reset(),
            IO.ANSI.red() <> line <> IO.ANSI.reset(),
            IO.ANSI.red() <> " - " <> IO.ANSI.reset()
          }
      end

    pretty_number <> separator <> pretty_line
  end

  @doc false
  @spec pad_left(binary(), non_neg_integer()) :: binary()
  defp pad_left(str, width), do: String.pad_leading(str, width, " ")

  @doc false
  @spec pad_right(binary(), non_neg_integer()) :: binary()
  defp pad_right(str, width), do: String.pad_trailing(str, width, " ")

  # -------------------------
  # CLI Entry
  # -------------------------

  @doc false
  @spec main([String.t()]) :: :ok
  def main(args \\ []) do
    args
    |> normalize_command()
    |> execute_command()
  end

  @type cli_command :: :review | :accept_all | :reject_all | :help

  @command_aliases %{
    "review" => :review,
    "r" => :review,
    "accept-all" => :accept_all,
    "aa" => :accept_all,
    "reject-all" => :reject_all,
    "ra" => :reject_all,
    "help" => :help,
    "h" => :help
  }

  @doc false
  @spec normalize_command([String.t()]) ::
          {:ok, cli_command()}
          | {:error, {:unknown_command, String.t()} | {:too_many_commands, [String.t()]}}
  defp normalize_command([]), do: {:ok, :review}

  defp normalize_command([command]) do
    normalized = Map.get(@command_aliases, String.downcase(command))

    case normalized do
      nil -> {:error, {:unknown_command, command}}
      _ -> {:ok, normalized}
    end
  end

  defp normalize_command(commands), do: {:error, {:too_many_commands, commands}}

  @doc false
  @spec execute_command({:ok, cli_command()} | {:error, term()}) :: :ok
  defp execute_command({:ok, :review}), do: review_snapshots()
  defp execute_command({:ok, :accept_all}), do: accept_all_snapshots()
  defp execute_command({:ok, :reject_all}), do: reject_all_snapshots()
  defp execute_command({:ok, :help}), do: show_help()

  defp execute_command({:error, {:unknown_command, command}}),
    do: unexpected_subcommand(command)

  defp execute_command({:error, {:too_many_commands, commands}}),
    do: more_than_one_command(commands)

  # -------------------------
  # CLI Internal logic
  # -------------------------
  @doc false
  @spec review_snapshots() :: :ok
  defp review_snapshots do
    case find_snapshots_folder() do
      {:ok, folder} ->
        case list_new_snapshots(folder) do
          {:ok, []} ->
            IO.puts(IO.ANSI.green() <> "No new snapshots to review." <> IO.ANSI.reset())

          {:ok, paths} ->
            do_review(paths, 1, length(paths))

          {:error, tagged} ->
            IO.puts(Error.explain(tagged))
        end

      {:error, reason} ->
        IO.puts(Error.explain(reason))
    end
  end

  @doc false
  @spec do_review([], non_neg_integer(), non_neg_integer()) :: :ok
  defp do_review([], _current, _total), do: :ok

  @doc false
  @spec do_review([Path.t()], pos_integer(), pos_integer()) :: :ok
  defp do_review([snapshot_path | rest], current, total) do
    IO.write("\e[H\e[2J")

    snapshot_path
    |> read_snapshot()
    |> handle_review(snapshot_path, rest, current, total)
  end

  @doc false
  @spec handle_review(
          {:ok, snapshot} | {:error, Error.t()},
          Path.t(),
          [Path.t()],
          pos_integer(),
          pos_integer()
        ) :: :ok
  defp handle_review({:ok, new_snapshot}, snapshot_path, rest, current, total) do
    snapshot_path
    |> accepted_path_for()
    |> review_box(new_snapshot)
    |> display_review(current, total)

    case resolve_choice(snapshot_path) do
      :aborted -> :ok
      :continue -> do_review(rest, current + 1, total)
    end
  end

  defp handle_review({:error, tagged_reason}, _snapshot_path, rest, current, total) do
    IO.puts(Error.explain(tagged_reason))
    do_review(rest, current + 1, total)
  end

  @doc false
  @spec accepted_path_for(Path.t()) :: Path.t()
  defp accepted_path_for(path), do: String.replace_suffix(path, ".snap", ".accepted.snap")

  @doc false
  @spec review_box(Path.t(), snapshot) :: binary()
  defp review_box(accepted_path, new_snapshot) do
    case read_accepted_for(new_snapshot, accepted_path) do
      {:ok, %Snapshot{} = accepted} ->
        diff_snapshot_box(accepted, new_snapshot, [])

      {:ok, nil} ->
        new_snapshot_box(new_snapshot, [])

      {:error, tagged_reason} ->
        IO.puts(Error.explain(tagged_reason))
        new_snapshot_box(new_snapshot, [])
    end
  end

  @doc false
  @spec display_review(binary(), pos_integer(), pos_integer()) :: :ok
  defp display_review(box, current, total) do
    IO.puts(IO.ANSI.cyan() <> "Reviewing snapshot #{current} of #{total}" <> IO.ANSI.reset())
    IO.puts("\n#{box}\n")
    :ok
  end

  @doc false
  @spec resolve_choice(Path.t()) :: :continue | :aborted
  defp resolve_choice(snapshot_path) do
    case ask_choice() do
      :accept ->
        _ = accept_snapshot(snapshot_path)
        :continue

      :reject ->
        _ = reject_snapshot(snapshot_path)
        :continue

      :skip ->
        :continue

      :aborted ->
        IO.puts(IO.ANSI.cyan() <> "Review aborted by the user." <> IO.ANSI.reset())
        :aborted

      {:error, {:cannot_read_user_input, reason}} ->
        IO.puts(Error.format_error({:cannot_read_user_input, reason}))
        :continue
    end
  end

  # -------------------------
  # Batch commands
  # -------------------------

  @doc false
  @spec accept_all_snapshots() :: :ok
  defp accept_all_snapshots do
    IO.puts("Looking for new snapshots...")

    with {:ok, folder} <- find_snapshots_folder(),
         {:ok, paths} <- list_new_snapshots(folder) do
      paths |> Enum.each(&accept_snapshot/1)
      IO.puts(IO.ANSI.green() <> "All new snapshots accepted!" <> IO.ANSI.reset())
    else
      {:error, tagged} ->
        IO.puts(Error.explain(tagged))
    end
  end

  @doc false
  @spec reject_all_snapshots() :: :ok
  defp reject_all_snapshots do
    IO.puts("Looking for new snapshots...")

    with {:ok, folder} <- find_snapshots_folder(),
         {:ok, paths} <- list_new_snapshots(folder) do
      paths |> Enum.each(&reject_snapshot/1)
      IO.puts(IO.ANSI.red() <> "All new snapshots rejected!" <> IO.ANSI.reset())
    else
      {:error, tagged} ->
        IO.puts(Error.explain(tagged))
    end
  end

  # -------------------------
  # Helper functions
  # -------------------------

  @doc false
  @spec list_new_snapshots(Path.t()) :: {:ok, [Path.t()]} | {:error, Error.t()}
  defp list_new_snapshots(folder) do
    case File.ls(folder) do
      {:ok, entries} ->
        snapshots =
          entries
          |> Enum.filter(fn name ->
            String.ends_with?(name, ".snap") and
              not String.ends_with?(name, ".accepted.snap") and
              not String.ends_with?(name, ".rejected.snap")
          end)
          |> Enum.sort()
          |> Enum.map(&Path.join(folder, &1))

        {:ok, snapshots}

      {:error, reason} ->
        {:error, {:cannot_read_snapshots, reason, folder}}
    end
  end

  @doc false
  @spec read_snapshot(Path.t()) :: {:ok, snapshot} | {:error, Error.t()}
  defp read_snapshot(path) do
    case File.read(path) do
      {:ok, raw} ->
        case deserialise(raw, :new) do
          {:ok, snapshot} ->
            {:ok, snapshot}

          {:error, reason} ->
            {:error, {:cannot_read_new_snapshot, reason, path}}
        end

      {:error, reason} ->
        {:error, {:cannot_read_new_snapshot, reason, path}}
    end
  end

  @doc false
  @spec read_accepted_for(snapshot, Path.t()) ::
          {:ok, snapshot | nil} | {:error, Error.t()}
  defp read_accepted_for(_snapshot, path) do
    case File.read(path) do
      {:ok, raw} ->
        case deserialise(raw, :accepted) do
          {:ok, snap} -> {:ok, snap}
          {:error, err} -> {:error, {:cannot_read_accepted_snapshot, err, path}}
        end

      # ➜ This is the normal case on first review for a title: no accepted snapshot yet
      {:error, :enoent} ->
        {:ok, nil}

      {:error, reason} ->
        {:error, {:cannot_read_accepted_snapshot, reason, path}}
    end
  end

  @doc false
  @spec ask_choice() ::
          :accept
          | :reject
          | :skip
          | :aborted
          | {:error, Error.t()}
  defp ask_choice do
    print_choice_menu()
    prompt_choice()
  end

  @doc false
  @spec print_choice_menu() :: :ok
  defp print_choice_menu do
    IO.puts(
      IO.ANSI.green() <>
        "  a" <>
        IO.ANSI.reset() <>
        " accept  " <>
        IO.ANSI.red() <>
        "  r" <>
        IO.ANSI.reset() <>
        " reject  " <>
        IO.ANSI.yellow() <>
        "  s" <>
        IO.ANSI.reset() <>
        " skip  " <>
        IO.ANSI.cyan() <> "  q" <> IO.ANSI.reset() <> " quit"
    )

    :ok
  end

  @doc false
  @spec prompt_choice() :: :accept | :reject | :skip | :aborted | {:error, Error.t()}
  defp prompt_choice do
    case IO.gets("> ") do
      :eof ->
        {:error, {:cannot_read_user_input, :eof}}

      data when is_binary(data) ->
        data
        |> String.trim()
        |> parse_choice()

      other ->
        {:error, {:cannot_read_user_input, other}}
    end
  end

  @doc false
  @spec parse_choice(String.t()) :: :accept | :reject | :skip | :aborted | {:error, Error.t()}
  defp parse_choice(choice) do
    case choice do
      "a" -> :accept
      "r" -> :reject
      "s" -> :skip
      "q" -> :aborted
      "" -> retry_choice()
      _ -> retry_choice()
    end
  end

  @doc false
  @spec retry_choice() :: :accept | :reject | :skip | :aborted | {:error, Error.t()}
  defp retry_choice do
    print_choice_menu()
    prompt_choice()
  end

  @doc false
  @spec accept_snapshot(Path.t()) :: :ok | Error.t()
  defp accept_snapshot(path) do
    accepted_path = String.replace_suffix(path, ".snap", ".accepted.snap")

    case File.rename(path, accepted_path) do
      :ok ->
        IO.puts(IO.ANSI.green() <> "Accepted #{Path.basename(path)}" <> IO.ANSI.reset())
        :ok

      {:error, reason} ->
        tagged = {:cannot_accept_snapshot, reason, path}
        IO.puts(Error.explain(tagged))
        tagged
    end
  end

  @doc false
  @spec reject_snapshot(Path.t()) :: :ok | Error.t()
  defp reject_snapshot(path) do
    rejected_path = String.replace_suffix(path, ".snap", ".rejected.snap")

    case File.rename(path, rejected_path) do
      :ok ->
        IO.puts(IO.ANSI.red() <> "Rejected #{Path.basename(path)}" <> IO.ANSI.reset())
        :ok

      {:error, reason} ->
        tagged = {:cannot_reject_snapshot, reason, path}
        IO.puts(Error.explain(tagged))
        tagged
    end
  end

  # -------------------------
  # Error handling / help
  # -------------------------

  @doc false
  @spec show_help() :: :ok
  defp show_help do
    IO.puts("""
    #{IO.ANSI.yellow()}USAGE:#{IO.ANSI.reset()}
      calque [ <SUBCOMMAND> ]

    #{IO.ANSI.yellow()}SUBCOMMANDS:#{IO.ANSI.reset()}
      #{IO.ANSI.green()}review#{IO.ANSI.reset()}       Review all new snapshots one by one
      #{IO.ANSI.green()}accept-all#{IO.ANSI.reset()}   Accept all new snapshots
      #{IO.ANSI.green()}reject-all#{IO.ANSI.reset()}   Reject all new snapshots
      #{IO.ANSI.green()}help#{IO.ANSI.reset()}         Show this help text
    """)
  end

  @doc false
  @spec unexpected_subcommand(String.t()) :: :ok
  defp unexpected_subcommand(cmd) do
    IO.puts(IO.ANSI.red() <> "Error: #{cmd} isn't a valid subcommand." <> IO.ANSI.reset())

    case closest_command(cmd) do
      nil ->
        show_help()

      command ->
        suggest_command(command)
    end
  end

  @doc false
  @spec suggest_command(String.t()) :: :ok
  defp suggest_command(suggestion) do
    msg =
      IO.ANSI.yellow() <>
        "I think you misspelled `#{suggestion}` would you like to run it instead ? [Y/n]\n" <>
        IO.ANSI.reset() <> "\n> "

    case IO.gets(msg) |> String.trim() |> String.downcase() do
      value when value in ["yes", "y"] ->
        command = Map.get(@command_aliases, suggestion)
        execute_command({:ok, command})

      _ ->
        show_help()
    end
  end

  @doc false
  @spec more_than_one_command([String.t()]) :: :ok
  defp more_than_one_command(subs) do
    IO.puts(
      IO.ANSI.red() <>
        "Error: Only one subcommand is allowed: #{Enum.join(subs, ", ")}" <> IO.ANSI.reset()
    )

    show_help()
  end

  @commands [
    "review",
    "accept-all",
    "reject-all",
    "help"
  ]

  @doc false
  @spec closest_command(String.t()) :: String.t() | nil
  defp closest_command(s) do
    commands =
      @commands
      |> Enum.map(fn c -> {c, Levenshtein.distance(s, c)} end)
      |> Enum.filter(fn {_, d} -> d <= 3 end)
      |> Enum.sort(fn x, y -> x <= y end)

    case commands do
      [] ->
        nil

      [head | _tail] ->
        {command, _} = head
        command
    end
  end
end
