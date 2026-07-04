defmodule Alva.Resource.Verifiers.VerifyActions do
  @moduledoc false

  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    projections = Spark.Dsl.Extension.get_entities(dsl_state, [:live_vue])
    events = Enum.filter(projections, &match?(%Alva.Resource.Event{}, &1))
    streams = Enum.filter(projections, &match?(%Alva.Resource.Stream{}, &1))
    collections = Enum.filter(projections, &match?(%Alva.Resource.Collection{}, &1))
    signals = Enum.filter(projections, &match?(%Alva.Resource.Signal{}, &1))
    module = Spark.Dsl.Extension.get_persisted(dsl_state, :module)
    publication_names = pubsub_publication_names(dsl_state)
    event_names =
      events
      |> Enum.map(& &1.name)
      |> MapSet.new()

    Enum.each(events, fn event ->
      action = Ash.Resource.Info.action(dsl_state, event.action)

      if is_nil(action) do
        raise_dsl_error(module, event, "Action #{inspect(event.action)} does not exist.")
      end

      unless action.public? do
        raise_dsl_error(
          module,
          event,
          "Action #{inspect(event.action)} must be public? true to be exposed via live_vue."
        )
      end

      if empty_dto?(dsl_state, action) do
        require Logger

        Logger.warning(
          "Alva Extension: Event #{inspect(event.name)} maps to action #{inspect(event.action)} which returns an empty DTO. Vue will receive an empty payload."
        )
      end
    end)

    Enum.each(streams, fn stream ->
      Enum.each(stream.operations || [], fn operation ->
        unless non_empty_string?(operation.on) do
          raise Spark.Error.DslError,
            module: module,
            path: [:live_vue, :stream, stream.name, operation.op],
            message: "Stream projection trigger must be a non-empty string."
        end

        verify_publication!(
          module,
          [:live_vue, :stream, stream.name, operation.op],
          "Stream",
          operation.on,
          publication_names
        )
      end)
    end)

    Enum.each(collections, fn collection ->
      verify_collection_source!(module, collection, event_names)

      if Enum.empty?(collection.operations || []) do
        require Logger

        Logger.warning(
          "Alva Extension: Collection #{inspect(collection.name)} has no insert/update/delete mappings and will not update from PubSub."
        )
      end

      Enum.each(collection.operations || [], fn operation ->
        unless non_empty_string?(operation.on) do
          raise Spark.Error.DslError,
            module: module,
            path: [:live_vue, :collection, collection.name, operation.op],
            message: "Collection projection trigger must be a non-empty string."
        end

        verify_publication!(
          module,
          [:live_vue, :collection, collection.name, operation.op],
          "Collection",
          operation.on,
          publication_names
        )
      end)
    end)

    Enum.each(signals, fn signal ->
      unless non_empty_string?(signal.on) do
        raise Spark.Error.DslError,
          module: module,
          path: [:live_vue, :signal, signal.name],
          message: "Signal projection trigger must be a non-empty string."
      end

      verify_publication!(
        module,
        [:live_vue, :signal, signal.name],
        "Signal",
        signal.on,
        publication_names
      )
    end)

    :ok
  end

  defp non_empty_string?(value) when is_binary(value), do: String.trim(value) != ""
  defp non_empty_string?(_), do: false

  defp verify_collection_source!(
         module,
         %Alva.Resource.Collection{name: name, source: [source]},
         event_names
       ) do
    unless non_empty_string?(source.event) do
      raise Spark.Error.DslError,
        module: module,
        path: [:live_vue, :collection, name, :source],
        message: "Collection #{inspect(name)} source event must be a non-empty string."
    end

    unless MapSet.member?(event_names, source.event) do
      raise Spark.Error.DslError,
        module: module,
        path: [:live_vue, :collection, name, :source],
        message:
          "Collection #{inspect(name)} source event #{inspect(source.event)} must reference a declared live_vue event."
    end
  end

  defp verify_collection_source!(module, %Alva.Resource.Collection{name: name}, _event_names) do
    raise Spark.Error.DslError,
      module: module,
      path: [:live_vue, :collection, name],
      message: "Collection #{inspect(name)} must declare exactly one source event."
  end

  defp empty_dto?(dsl_state, action) do
    if action.type == :action do
      is_nil(action.returns)
    else
      public_fields_count(dsl_state) == 0
    end
  end

  defp public_fields_count(dsl_state) do
    Alva.Resource.Info.public_fields(dsl_state) |> length()
  end

  defp pubsub_publication_names(resource) do
    if Code.ensure_loaded?(Ash.Notifier.PubSub.Info) and
         function_exported?(Ash.Notifier.PubSub.Info, :publications, 1) do
      resource
      |> Ash.Notifier.PubSub.Info.publications()
      |> Enum.map(&publication_name/1)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()
    else
      MapSet.new()
    end
  end

  defp publication_name(publication) do
    case publication.event || publication.action || publication.type do
      nil -> nil
      value -> to_string(value)
    end
  end

  defp verify_publication!(module, path, kind, trigger, publication_names) do
    if MapSet.size(publication_names) > 0 and not MapSet.member?(publication_names, trigger) do
      available =
        publication_names
        |> MapSet.to_list()
        |> Enum.sort()
        |> Enum.map_join(", ", &inspect/1)

      raise Spark.Error.DslError,
        module: module,
        path: path,
        message:
          "#{kind} projection trigger #{inspect(trigger)} does not match a declared Ash PubSub publication. Available publications: #{available}."
    end
  end

  defp raise_dsl_error(module, event, message) do
    raise Spark.Error.DslError,
      module: module,
      path: [:live_vue, :event, event.name],
      message: message
  end
end
