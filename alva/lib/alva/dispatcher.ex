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
            data =
              Ash.read!(resource, action: action_name)
              |> Enum.map(&strip_metadata/1)

            %{ok: true, data: data}

          :create ->
            changeset = Ash.Changeset.for_create(resource, action_name, params)

            case Ash.create(changeset) do
              {:ok, record} ->
                %{ok: true, data: strip_metadata(record)}

              {:error, error} ->
                %{ok: false, error: Alva.Error.format(error)}
            end

          :update ->
            lookup_field = event_def.lookup || :id
            lookup_key = to_string(lookup_field)
            lookup_value = Map.get(params, lookup_key)
            update_params = Map.delete(params, lookup_key)

            if is_nil(lookup_value) do
              %{ok: false, error: %{type: "not_found", message: "Resource not found"}}
            else
              with {:ok, record} <- Ash.get(resource, [{lookup_field, lookup_value}]),
                   changeset <- Ash.Changeset.for_update(record, action_name, update_params),
                   {:ok, updated_record} <- Ash.update(changeset) do
                %{ok: true, data: strip_metadata(updated_record)}
              else
                {:error, error} ->
                  %{ok: false, error: Alva.Error.format(error)}
              end
            end

          :destroy ->
            lookup_field = event_def.lookup || :id
            lookup_key = to_string(lookup_field)
            lookup_value = Map.get(params, lookup_key)

            if is_nil(lookup_value) do
              %{ok: false, error: %{type: "not_found", message: "Resource not found"}}
            else
              with {:ok, record} <- Ash.get(resource, [{lookup_field, lookup_value}]) do
                case Ash.destroy(record, action: action_name) do
                  :ok -> %{ok: true, data: strip_metadata(record)}
                  {:ok, _} -> %{ok: true, data: strip_metadata(record)}
                  {:error, error} -> %{ok: false, error: Alva.Error.format(error)}
                end
              else
                {:error, error} ->
                  %{ok: false, error: Alva.Error.format(error)}
              end
            end

          :action ->
            input = Ash.ActionInput.for_action(resource, action_name, params)

            case Ash.run_action(input) do
              {:ok, result} ->
                %{ok: true, data: result}

              {:error, error} ->
                %{ok: false, error: Alva.Error.format(error)}
            end

          _ ->
            Logger.warning(
              "Alva Dispatcher: Action type #{action.type} not supported yet for event #{event_name}"
            )

            %{ok: false, error: %{type: "unsupported", message: "Action type not supported yet"}}
        end

      :error ->
        Logger.warning("Alva Dispatcher: Unknown event #{event_name}")
        %{ok: false, error: %{type: "unknown", message: "Unknown event: #{event_name}"}}
    end
  end

  defp find_event(domains, event_name) do
    Enum.find_value(domains, :error, fn domain ->
      map = Alva.Domain.Info.alva_event_map(domain)

      case Map.fetch(map, event_name) do
        {:ok, {resource, event}} -> {:ok, resource, event}
        :error -> nil
      end
    end)
  end

  def strip_metadata(record) do
    record
    |> Map.from_struct()
    |> Map.drop([:__meta__])
  end
end
