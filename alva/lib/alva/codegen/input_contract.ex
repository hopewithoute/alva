defmodule Alva.Codegen.InputContract do
  @moduledoc """
  Generates TypeScript input shapes for Ash Actions.
  """

  alias Alva.Codegen.TypeMapper

  def generate_input_shape(resource, event_def, action, indent \\ "") do
    if action.type in [:read, :create, :update, :action] do
      policy_fields = resource_policy_fields(resource)

      args_ts = generate_arguments_ts(Map.get(action, :arguments, []), indent)

      attrs_ts =
        generate_attributes_ts(
          resource,
          action.type,
          Map.get(action, :accept, []),
          Map.get(action, :require_attributes, []),
          policy_fields,
          Map.get(action, :allow_nil_input, []),
          indent
        )

      pks_ts = generate_primary_keys_ts(resource, action.type, indent)
      filter_ts = generate_filter_ts(resource, Map.get(event_def, :enable_filter, false), indent)

      extra_opts_ts =
        if action.type == :read do
          [
            "#{indent}  page?: Types.PaginationInput;",
            "#{indent}  sort?: string | string[];"
          ]
        else
          []
        end

      all_fields =
        (args_ts ++ pks_ts ++ attrs_ts ++ filter_ts ++ extra_opts_ts)
        |> Enum.uniq()
        |> Enum.join("\n")

      if all_fields == "" do
        "Record<string, never>"
      else
        "{\n#{all_fields}\n#{indent}}"
      end
    else
      "any"
    end
  end

  defp resource_policy_fields(resource) do
    if Code.ensure_loaded?(Ash.Policy.Info) and
         function_exported?(Ash.Policy.Info, :field_policies, 1) do
      (apply(Ash.Policy.Info, :field_policies, [resource]) || [])
      |> Enum.flat_map(& &1.fields)
      |> Enum.uniq()
    else
      []
    end
  end

  defp generate_arguments_ts(arguments, indent) do
    Enum.map(arguments, fn arg ->
      optional? = arg_optional?(arg)
      ts_type = input_ts_type(arg.type, Map.get(arg, :constraints, []))
      format_field(arg.name, ts_type, optional?, indent)
    end)
  end

  defp generate_attributes_ts(
         resource,
         action_type,
         accept,
         require_attributes,
         policy_fields,
         allow_nil_input,
         indent
       ) do
    accept
    |> Enum.map(fn attr_name ->
      attr = Ash.Resource.Info.attribute(resource, attr_name)

      if attr do
        optional? =
          attr_optional?(attr, action_type, require_attributes, policy_fields, allow_nil_input)

        ts_type = input_ts_type(attr.type, Map.get(attr, :constraints, []))
        format_field(attr.name, ts_type, optional?, indent)
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp generate_primary_keys_ts(resource, action_type, indent) do
    if action_type in [:update, :destroy] do
      Ash.Resource.Info.primary_key(resource)
      |> Enum.map(fn pk ->
        attr = Ash.Resource.Info.attribute(resource, pk)
        ts_type = TypeMapper.map_type(attr.type, Map.get(attr, :constraints, []))
        format_field(attr.name, ts_type, false, indent)
      end)
    else
      []
    end
  end

  defp generate_filter_ts(resource, enable_filter?, indent) do
    if enable_filter? do
      resource_name = resource |> Module.split() |> List.last()
      ["#{indent}  filter?: Types.#{resource_name}Filter;"]
    else
      []
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

  defp input_ts_type({:array, Ash.Type.File}, _constraints), do: "string[]"
  defp input_ts_type({:array, :file}, _constraints), do: "string[]"
  defp input_ts_type(type, _constraints) when type in [Ash.Type.File, :file], do: "string"
  defp input_ts_type(type, constraints), do: TypeMapper.map_type(type, constraints)

  defp format_field(name, type, true = _optional?, indent), do: "#{indent}  #{name}?: #{type};"
  defp format_field(name, type, false = _optional?, indent), do: "#{indent}  #{name}: #{type};"
end
