defmodule Mix.Tasks.Alva.Watch do
  @shortdoc "Watches Ash resources and re-runs alva.codegen on file changes"
  @moduledoc """
  Watches `lib/**/*.ex` for file modifications and automatically re-runs `mix alva.codegen`.

  ## Usage

      mix alva.watch

  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.shell().info("[:alva] Watching Ash resources in lib/**/*.ex for codegen updates...")

    # Run initial codegen pass
    Mix.Task.run("alva.codegen", args)

    loop_watch(args, get_file_timestamps())
  end

  defp get_file_timestamps do
    "lib/**/*.ex"
    |> Path.wildcard()
    |> Enum.reduce(%{}, fn file, acc ->
      case File.stat(file) do
        {:ok, %{mtime: mtime}} -> Map.put(acc, file, mtime)
        _ -> acc
      end
    end)
  end

  defp loop_watch(args, timestamps) do
    Process.sleep(500)
    new_timestamps = get_file_timestamps()

    if timestamps != %{} and new_timestamps != timestamps do
      changed_files =
        Enum.filter(new_timestamps, fn {file, mtime} ->
          Map.get(timestamps, file) != mtime
        end)

      if changed_files != [] do
        file_names = Enum.map_join(changed_files, ", ", fn {f, _} -> Path.basename(f) end)

        IO.puts(
          "\n\e[32m[Alva Watcher]\e[0m Resource modified (#{file_names}) -> Re-running mix alva.codegen..."
        )

        Mix.Task.reenable("alva.codegen")
        Mix.Task.run("alva.codegen", args)
      end
    end

    loop_watch(args, new_timestamps)
  end
end
