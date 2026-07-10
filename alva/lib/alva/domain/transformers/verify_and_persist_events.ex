defmodule Alva.Domain.Transformers.VerifyAndPersistEvents do
  @moduledoc """
  A Spark DSL transformer for `Alva.Domain` (currently deprecated/unused in V2).

  This module historically validated that the resources attached to an Ash domain 
  properly implemented their Alva configurations. In the V2 architecture, this 
  resolution is handled dynamically by `Alva.Registry`.
  """

  use Spark.Dsl.Transformer

  def after?(Ash.Domain.Transformers.DefineResources), do: true
  def after?(_), do: false

  def transform(dsl_state) do
    resources = Ash.Domain.Info.resources(dsl_state)
    module = Spark.Dsl.Extension.get_persisted(dsl_state, :module)

    event_map =
      persist_projection_map(resources, module, :event, &Alva.Registry.events/1)

    signal_map =
      persist_projection_map(resources, module, :signal, &Alva.Registry.signals/1)

    dsl_state =
      dsl_state
      |> Spark.Dsl.Transformer.persist(:alva_event_map, event_map)
      |> Spark.Dsl.Transformer.persist(:alva_signal_map, signal_map)

    Alva.Registry.verify_host_app_command_uniqueness!(module, event_map)
    Alva.Registry.verify_host_app_signal_uniqueness!(module, signal_map)

    {:ok, dsl_state}
  end

  defp persist_projection_map(resources, module, kind, fetcher, opts \\ []) do
    identity_fun = Keyword.get(opts, :identity_fun, & &1.name)
    identity_label = Keyword.get(opts, :identity_label, :name)

    Enum.reduce(resources, %{}, fn resource, acc ->
      persist_unique(
        acc,
        fetcher.(resource),
        resource,
        module,
        kind,
        identity_fun,
        identity_label
      )
    end)
  end

  defp persist_unique(
         map,
         projections,
         resource,
         module,
         kind,
         identity_fun,
         identity_label
       ) do
    Enum.reduce(projections, map, fn projection, acc ->
      identity = identity_fun.(projection)

      if Map.has_key?(acc, identity) do
        {existing_resource, _} = acc[identity]

        raise Spark.Error.DslError,
          module: module,
          path: [:resources],
          message:
            "Duplicate #{kind} #{identity_label} #{inspect(identity)} found in resource #{inspect(resource)} (already defined in #{inspect(existing_resource)})"
      else
        Map.put(acc, identity, {resource, projection})
      end
    end)
  end
end
