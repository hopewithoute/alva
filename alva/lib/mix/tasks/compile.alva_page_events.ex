defmodule Mix.Tasks.Compile.AlvaPageEvents do
  @shortdoc "Extracts and generates TypeScript bindings for Alva.LiveView page events"
  @moduledoc """
  Parses all `.ex` files in the current project to extract `page_events` declarations
  from `use Alva.LiveView` and generates their `.events.ts` files.
  """

  use Mix.Task

  @impl true
  def run(_args) do
    # Get all .ex files in lib/
    files = Path.wildcard("lib/**/*.ex")

    Enum.each(files, fn file ->
      code = File.read!(file)
      
      try do
        ast = Code.string_to_quoted!(code)
        
        Macro.prewalk(ast, fn
          {:use, _, [{:__aliases__, _, [:Alva, :LiveView]}, opts]} ->
            page_events_ast = Keyword.get(opts, :page_events, [])
            
            # Find the module name
            module_name = extract_module_name(ast)
            
            if module_name do
              {page_events, _} = Code.eval_quoted(page_events_ast)
              
              if length(page_events) > 0 do
                Alva.Codegen.PageEventsGenerator.generate!(Module.concat([module_name]), page_events)
              end
            end
            
            nil
            
          other -> other
        end)
      rescue
        _ -> :ok # Ignore parsing errors for now
      end
    end)
    
    {:ok, []}
  end
  
  defp extract_module_name(ast) do
    # Find defmodule
    result =
      Macro.prewalk(ast, nil, fn
        {:defmodule, _, [{:__aliases__, _, aliases}, _]}, _acc -> {nil, Enum.join(aliases, ".")}
        node, acc -> {node, acc}
      end)
      
    elem(result, 1)
  end
end
