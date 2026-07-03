defmodule Alva.Codegen.NamespaceProxy do
  @moduledoc """
  Generates a nested TypeScript interface for proxying AlvaEvents.
  """

  def generate_interface(events) do
    tree = build_tree(events)

    """
    export interface AlvaApi {
    #{render_node(tree, 1)}
    }
    """
  end

  defp build_tree(events) do
    Enum.reduce(events, %{}, fn event, acc ->
      path = String.split(event, ".")
      put_in_tree(acc, path, event)
    end)
  end

  defp put_in_tree(tree, [leaf], original_event) do
    Map.put(tree, leaf, original_event)
  end

  defp put_in_tree(tree, [node | rest], original_event) do
    sub_tree = Map.get(tree, node, %{})
    Map.put(tree, node, put_in_tree(sub_tree, rest, original_event))
  end

  defp render_node(tree, depth) when is_map(tree) do
    indent = String.duplicate("  ", depth)

    tree
    |> Enum.map(fn {key, value} ->
      case value do
        sub_tree when is_map(sub_tree) ->
          "#{indent}#{key}: {\n#{render_node(sub_tree, depth + 1)}\n#{indent}};"

        original_event when is_binary(original_event) ->
          "#{indent}#{key}: (input: AlvaEvents[\"#{original_event}\"][\"input\"]) => Promise<AlvaEvents[\"#{original_event}\"][\"output\"]>;"
      end
    end)
    |> Enum.join("\n")
  end
end
