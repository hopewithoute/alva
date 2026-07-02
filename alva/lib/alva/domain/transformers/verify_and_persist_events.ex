defmodule Alva.Domain.Transformers.VerifyAndPersistEvents do
  @moduledoc false

  use Spark.Dsl.Transformer

  def after?(Ash.Domain.Transformers.DefineResources), do: true
  def after?(_), do: false

  def transform(dsl_state) do
    resources = Ash.Domain.Info.resources(dsl_state)
    module = Spark.Dsl.Extension.get_persisted(dsl_state, :module)

    events_map =
      Enum.reduce(resources, %{}, fn resource, acc ->
        events = Spark.Dsl.Extension.get_entities(resource, [:live_vue])

        Enum.reduce(events, acc, fn event, map_acc ->
          if Map.has_key?(map_acc, event.name) do
            {existing_resource, _} = map_acc[event.name]

            raise Spark.Error.DslError,
              module: module,
              path: [:resources],
              message:
                "Duplicate event name #{inspect(event.name)} found in resource #{inspect(resource)} (already defined in #{inspect(existing_resource)})"
          else
            Map.put(map_acc, event.name, {resource, event})
          end
        end)
      end)

    dsl_state = Spark.Dsl.Transformer.persist(dsl_state, :alva_event_map, events_map)

    {:ok, dsl_state}
  end
end
