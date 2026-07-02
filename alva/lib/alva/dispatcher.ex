defmodule Alva.Dispatcher do
  @moduledoc """
  Dynamically routes events from Vue to Ash actions based on Spark DSL.
  """
  require Logger

  def dispatch(event_name, params, opts \\ []) do
    domains = Keyword.get(opts, :domains, [])

    case find_event(domains, event_name) do
      {:ok, resource, event_def} ->
        action_name = event_def.action
        action = Ash.Resource.Info.action(resource, action_name)

        case action.type do
          :read ->
            data = Ash.read!(resource, action: action_name)
                   |> Enum.map(&strip_metadata/1)

            %{ok: true, data: data}

          :create ->
            case Ash.create(resource, params, action: action_name) do
              {:ok, record} ->
                %{ok: true, data: strip_metadata(record)}

              {:error, error} ->
                %{ok: false, error: Alva.Error.format(error)}
            end

          _ ->
            Logger.warning("Alva Dispatcher: Action type #{action.type} not supported yet for event #{event_name}")
            %{ok: false, error: %{type: "unsupported", message: "Action type not supported yet"}}
        end

      :error ->
        Logger.warning("Alva Dispatcher: Unknown event #{event_name}")
        %{ok: false, error: %{type: "unknown", message: "Unknown event: #{event_name}"}}
    end
  end

  defp find_event(domains, event_name) do
    Enum.find_value(domains, :error, fn domain ->
      resources = Ash.Domain.Info.resources(domain)

      Enum.find_value(resources, nil, fn resource ->
        events = Alva.Resource.Info.events(resource)

        event = Enum.find(events, &(&1.name == event_name))
        if event do
          {:ok, resource, event}
        end
      end)
    end)
  end

  def strip_metadata(record) do
    record
    |> Map.from_struct()
    |> Map.drop([:__meta__])
  end
end
