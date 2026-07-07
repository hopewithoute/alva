defmodule Mix.Tasks.Compile.AlvaPageEvents do
  @shortdoc "Extracts and generates TypeScript bindings for Alva.LiveView page events"
  @moduledoc """
  Iterates over compiled `.beam` files to extract `page_events` declarations
  from modules that `use Alva.LiveView` and generates their `.events.ts` files.
  """

  use Mix.Task

  @impl true
  def run(_args) do
    # Ensure the code path is loaded so we can check modules
    Code.prepend_path(Mix.Project.compile_path())
    
    Mix.Project.compile_path()
    |> Path.join("*.beam")
    |> Path.wildcard()
    |> Enum.each(fn beam_path ->
      module_name = 
        beam_path
        |> Path.basename(".beam")
        |> String.to_atom()
        
      # Try to load the module first so function_exported? works
      case Code.ensure_loaded(module_name) do
        {:module, ^module_name} ->
          if function_exported?(module_name, :__alva_page_events__, 0) do
            page_events = apply(module_name, :__alva_page_events__, [])
            Alva.Codegen.PageEventsGenerator.generate!(module_name, page_events)
          end
        {:error, reason} ->
          Mix.shell().error("Failed to load module #{module_name} for page events generation: #{inspect(reason)}")
      end
    end)
    
    {:ok, []}
  end
end
