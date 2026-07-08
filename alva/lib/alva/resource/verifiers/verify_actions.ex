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
    publication_occurrence_keys = pubsub_occurrence_keys(dsl_state)

    event_keys = events |> Enum.map(& &1.key) |> MapSet.new()
    event_names = events |> Enum.map(& &1.name) |> MapSet.new()

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
      raise Spark.Error.DslError,
        module: module,
        path: [:live_vue, :stream, stream.name],
        message:
          "Alva stream projections have been removed. Replace #{inspect(stream.name)} with a Collection declaration or use raw Phoenix PubSub outside Alva."
    end)

    Enum.each(collections, fn collection ->
      verify_collection_source!(module, collection, event_keys)

      if Enum.empty?(collection.operations || []) do
        require Logger

        Logger.warning(
          "Alva Extension: Collection #{inspect(collection.name)} has no insert/update/delete mappings and will not update from PubSub."
        )
      end

      Enum.each(collection.operations || [], fn operation ->
        verify_occurrence_key!(
          module,
          [:live_vue, :collection, collection.name, operation.op],
          "Collection",
          operation.on,
          publication_occurrence_keys,
          event_keys,
          event_names
        )
      end)
    end)

    Enum.each(signals, fn signal ->
      verify_occurrence_key!(
        module,
        [:live_vue, :signal, signal.key],
        "Signal",
        signal.on,
        publication_occurrence_keys,
        event_keys,
        event_names
      )
    end)

    :ok
  end

  defp verify_collection_source!(
         module,
         %Alva.Resource.Collection{name: name, source: [source]},
         event_keys
       ) do
    unless is_atom(source.event) do
      raise Spark.Error.DslError,
        module: module,
        path: [:live_vue, :collection, name, :source],
        message:
          "Collection #{inspect(name)} source event must be an event declaration key atom, got: #{inspect(source.event)}."
    end

    unless MapSet.member?(event_keys, source.event) do
      raise Spark.Error.DslError,
        module: module,
        path: [:live_vue, :collection, name, :source],
        message:
          "Collection #{inspect(name)} source event #{inspect(source.event)} must reference a declared live_vue event declaration key."
    end
  end

  defp verify_collection_source!(module, %Alva.Resource.Collection{name: name}, _event_keys) do
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

  defp pubsub_occurrence_keys(resource) do
    if Code.ensure_loaded?(Ash.Notifier.PubSub.Info) and
         function_exported?(Ash.Notifier.PubSub.Info, :publications, 1) do
      resource
      |> Ash.Notifier.PubSub.Info.publications()
      |> Enum.map(&publication_occurrence_key/1)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()
    else
      MapSet.new()
    end
  end

  defp publication_occurrence_key(publication) do
    case publication.action || publication.type do
      nil -> nil
      value -> value
    end
  end

  defp verify_occurrence_key!(
         module,
         path,
         kind,
         trigger,
         publication_occurrence_keys,
         event_keys,
         event_names
       )

  defp verify_occurrence_key!(
         module,
         path,
         kind,
         trigger,
         publication_occurrence_keys,
         event_keys,
         _event_names
       )
       when is_atom(trigger) do
    cond do
      MapSet.member?(publication_occurrence_keys, trigger) ->
        :ok

      MapSet.member?(event_keys, trigger) ->
        raise Spark.Error.DslError,
          module: module,
          path: path,
          message:
            "#{kind} projection occurrence key #{inspect(trigger)} looks like a live_vue event declaration key. Use an Ash PubSub occurrence key atom instead."

      MapSet.size(publication_occurrence_keys) == 0 ->
        :ok

      true ->
        available =
          publication_occurrence_keys
          |> MapSet.to_list()
          |> Enum.sort()
          |> Enum.map_join(", ", &inspect/1)

        raise Spark.Error.DslError,
          module: module,
          path: path,
          message:
            "#{kind} projection occurrence key #{inspect(trigger)} does not match a declared Ash PubSub occurrence key. Available occurrence keys: #{available}."
    end
  end

  defp verify_occurrence_key!(
         module,
         path,
         kind,
         trigger,
         _publication_occurrence_keys,
         _event_keys,
         event_names
       )
       when is_binary(trigger) do
    trimmed = String.trim(trigger)

    message =
      cond do
        trimmed == "" ->
          "#{kind} projection occurrence key must be a non-empty atom."

        MapSet.member?(event_names, trigger) ->
          "#{kind} projection occurrence key #{inspect(trigger)} looks like a browser-facing live_vue event name. Use the Ash PubSub occurrence key atom instead."

        String.contains?(trigger, ".") ->
          "#{kind} projection occurrence key #{inspect(trigger)} looks like a browser-facing live_vue event name. Use the Ash PubSub occurrence key atom instead."

        String.contains?(trigger, ":") ->
          "#{kind} projection occurrence key #{inspect(trigger)} looks like a concrete PubSub topic. Use the Ash PubSub occurrence key atom instead."

        true ->
          "#{kind} projection occurrence key #{inspect(trigger)} looks like a raw PubSub event string. Use the Ash PubSub occurrence key atom instead."
      end

    raise Spark.Error.DslError,
      module: module,
      path: path,
      message: message
  end

  defp verify_occurrence_key!(module, path, kind, trigger, _keys, _event_keys, _event_names) do
    raise Spark.Error.DslError,
      module: module,
      path: path,
      message: "#{kind} projection occurrence key must be an atom, got: #{inspect(trigger)}."
  end

  defp raise_dsl_error(module, event, message) do
    raise Spark.Error.DslError,
      module: module,
      path: [:live_vue, :event, event.key],
      message: message
  end
end
