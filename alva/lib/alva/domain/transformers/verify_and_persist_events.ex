defmodule Alva.Domain.Transformers.VerifyAndPersistEvents do
  @moduledoc false

  use Spark.Dsl.Transformer

  def after?(Ash.Domain.Transformers.DefineResources), do: true
  def after?(_), do: false

  def transform(dsl_state) do
    resources = Ash.Domain.Info.resources(dsl_state)
    module = Spark.Dsl.Extension.get_persisted(dsl_state, :module)

    event_map =
      Enum.reduce(resources, %{}, fn resource, acc ->
        persist_unique(
          acc,
          Alva.Resource.Info.events(resource),
          resource,
          module,
          :event
        )
      end)

    stream_map =
      Enum.reduce(resources, %{}, fn resource, acc ->
        persist_unique(
          acc,
          Alva.Resource.Info.streams(resource),
          resource,
          module,
          :stream
        )
      end)

    signal_map =
      Enum.reduce(resources, %{}, fn resource, acc ->
        persist_unique(
          acc,
          Alva.Resource.Info.signals(resource),
          resource,
          module,
          :signal
        )
      end)

    dsl_state =
      dsl_state
      |> Spark.Dsl.Transformer.persist(:alva_event_map, event_map)
      |> Spark.Dsl.Transformer.persist(:alva_stream_map, stream_map)
      |> Spark.Dsl.Transformer.persist(:alva_signal_map, signal_map)

    {:ok, dsl_state}
  end

  defp persist_unique(map, projections, resource, module, kind) do
    Enum.reduce(projections, map, fn projection, acc ->
      if Map.has_key?(acc, projection.name) do
        {existing_resource, _} = acc[projection.name]

        raise Spark.Error.DslError,
          module: module,
          path: [:resources],
          message:
            "Duplicate #{kind} name #{inspect(projection.name)} found in resource #{inspect(resource)} (already defined in #{inspect(existing_resource)})"
      else
        Map.put(acc, projection.name, {resource, projection})
      end
    end)
  end
end
