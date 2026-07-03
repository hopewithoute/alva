defmodule Alva.Codegen.InputContract do
  @moduledoc """
  Generates TypeScript input shapes for Ash Actions.
  """

  alias Alva.Codegen.TypeMapper

  def generate_input_shape(resource, event_def, action, indent \\ "") do
    is_read = action.type == :read
    enable_filter? = Map.get(event_def, :enable_filter, false)

    if not is_read and action.type not in [:create, :update, :action] do
      "any"
    else
      arguments = Map.get(action, :arguments, [])
      accept = Map.get(action, :accept, [])
      require_attributes = Map.get(action, :require_attributes, [])
      allow_nil_input = Map.get(action, :allow_nil_input, [])

      field_policies =
        if Code.ensure_loaded?(Ash.Policy.Info) and function_exported?(Ash.Policy.Info, :field_policies, 1) do
          apply(Ash.Policy.Info, :field_policies, [resource]) || []
        else
          []
        end

      policy_fields =
        field_policies
        |> Enum.flat_map(fn policy -> policy.fields end)
        |> Enum.uniq()

      args_ts =
        arguments
        |> Enum.map(fn arg ->
          optional? = arg_optional?(arg)
          ts_type = TypeMapper.map_type(arg.type, Map.get(arg, :constraints, []))
          format_field(arg.name, ts_type, optional?, indent)
        end)

      attrs_ts =
        accept
        |> Enum.map(fn attr_name ->
          attr = Ash.Resource.Info.attribute(resource, attr_name)
          
          if attr do
            optional? = attr_optional?(attr, action.type, require_attributes, policy_fields, allow_nil_input)
            ts_type = TypeMapper.map_type(attr.type, Map.get(attr, :constraints, []))
            format_field(attr.name, ts_type, optional?, indent)
          else
            nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      filter_ts = 
        if enable_filter? do
          resource_name = resource |> Module.split() |> List.last()
          ["#{indent}  filter?: Types.AshFilter<Types.#{resource_name}>;"]
        else
          []
        end

      all_fields = (args_ts ++ attrs_ts ++ filter_ts) |> Enum.join("\n")

      if all_fields == "" do
        "Record<string, never>"
      else
        "{\n#{all_fields}\n#{indent}}"
      end
    end
  end

  defp arg_optional?(arg) do
    arg.allow_nil? or has_default?(arg)
  end
  
  defp has_default?(arg_or_attr) do
    arg_or_attr.default != nil
  end

  defp attr_optional?(attr, action_type, require_attributes, policy_fields, allow_nil_input) do
    cond do
      attr.name in allow_nil_input ->
        true
      attr.name in policy_fields ->
        true
      attr.name in require_attributes ->
        false
      action_type == :update ->
        true
      action_type == :create ->
        attr.allow_nil? or has_default?(attr)
      true ->
        true
    end
  end

  defp format_field(name, type, true = _optional?, indent), do: "#{indent}  #{name}?: #{type};"
  defp format_field(name, type, false = _optional?, indent), do: "#{indent}  #{name}: #{type};"
end
