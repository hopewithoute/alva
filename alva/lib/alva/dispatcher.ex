defmodule Alva.Dispatcher do
  @moduledoc """
  Dynamically routes events from Vue to Ash actions based on Spark DSL.
  """
  require Logger

  def dispatch(event_name, params, opts \\ []) do
    domains = Keyword.get(opts, :domains, [])
    ash_opts = Keyword.take(opts, [:actor, :tenant])

    case find_event(domains, event_name) do
      {:ok, resource, event_def} ->
        action_name = event_def.action
        action = Ash.Resource.Info.action(resource, action_name)
        params = Map.drop(params, ["meta", :meta])

        case action.type do
          :read ->
            if event_def.lookup do
              lookup_field = event_def.lookup
              lookup_key = to_string(lookup_field)
              lookup_value = Map.get(params, lookup_key)
              action_params = Map.delete(params, lookup_key)

              if is_nil(lookup_value) do
                handle_error(not_found_error(resource, lookup_field, lookup_value))
              else
                require Ash.Query
                require Ash.Expr

                query =
                  Ash.Query.for_read(resource, action_name, action_params, ash_opts)
                  |> Ash.Query.filter(^Ash.Expr.ref(lookup_field) == ^lookup_value)

                case Ash.read_one(query, ash_opts) do
                  {:ok, record} when not is_nil(record) ->
                    handle_success(strip_metadata(record))

                  {:ok, nil} ->
                    handle_error(not_found_error(resource, lookup_field, lookup_value))

                  {:error, error} ->
                    handle_error(error)
                end
              end
            else
              page_opts = get_indifferent(params, "page", :page)
              sort_opts = get_indifferent(params, "sort", :sort)
              action_params = Map.drop(params, ["page", :page, "sort", :sort])

              read_opts =
                if is_map(page_opts) do
                  valid_keys = ~w(limit offset after before count filter)

                  page_opts =
                    page_opts
                    |> Enum.filter(fn {k, _v} -> to_string(k) in valid_keys end)
                    |> Enum.map(fn {k, v} -> {String.to_existing_atom(to_string(k)), v} end)
                    |> Keyword.new()

                  [page: page_opts]
                else
                  []
                end

              read_opts = Keyword.merge(read_opts, ash_opts)
              query = Ash.Query.for_read(resource, action_name, action_params, ash_opts)

              query =
                if sort_opts do
                  case Ash.Sort.parse_input(resource, sort_opts) do
                    {:ok, valid_sort} -> Ash.Query.sort(query, valid_sort)
                    _ -> query
                  end
                else
                  query
                end

              case Ash.read(query, read_opts) do
                {:ok, %{results: records} = page}
                when is_struct(page, Ash.Page.Offset) or is_struct(page, Ash.Page.Keyset) ->
                  handle_success(Enum.map(records, &strip_metadata/1), page)

                {:ok, records} ->
                  handle_success(Enum.map(records, &strip_metadata/1))

                {:error, error} ->
                  handle_error(error)
              end
            end

          :create ->
            changeset = Ash.Changeset.for_create(resource, action_name, params, ash_opts)

            case Ash.create(changeset, ash_opts) do
              {:ok, record} ->
                handle_success(strip_metadata(record))

              {:error, error} ->
                handle_error(error)
            end

          :update ->
            lookup_field = event_def.lookup || :id
            lookup_key = to_string(lookup_field)
            update_params = Map.delete(params, lookup_key)

            with {:ok, record} <- fetch_record(resource, event_def, params, ash_opts),
                 changeset <-
                   Ash.Changeset.for_update(record, action_name, update_params, ash_opts),
                 {:ok, updated_record} <- Ash.update(changeset, ash_opts) do
              handle_success(strip_metadata(updated_record))
            else
              {:error, error} -> handle_error(error)
            end

          :destroy ->
            with {:ok, record} <- fetch_record(resource, event_def, params, ash_opts),
                 changeset <- Ash.Changeset.for_destroy(record, action_name, %{}, ash_opts) do
              case Ash.destroy(changeset, Keyword.merge([return_destroyed?: true], ash_opts)) do
                {:ok, destroyed_record} ->
                  handle_success(strip_metadata(destroyed_record))

                :ok ->
                  handle_success(strip_metadata(record))

                {:error, error} ->
                  handle_error(error)
              end
            else
              {:error, error} -> handle_error(error)
            end

          :action ->
            input = Ash.ActionInput.for_action(resource, action_name, params)

            case Ash.run_action(input, ash_opts) do
              {:ok, result} ->
                handle_success(result)

              {:error, error} ->
                handle_error(error)
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

  defp get_indifferent(map, string_key, atom_key) do
    Map.get(map, string_key, Map.get(map, atom_key))
  end

  defp fetch_record(resource, event_def, params, ash_opts) do
    lookup_field = event_def.lookup || :id
    lookup_key = to_string(lookup_field)
    lookup_value = Map.get(params, lookup_key)
    Ash.get(resource, [{lookup_field, lookup_value}], ash_opts)
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

  def strip_metadata(%module{} = record) do
    if Ash.Resource.Info.resource?(module) do
      fields = public_fields(module)

      record
      |> Map.take(fields)
      |> Enum.reject(fn {_k, v} ->
        match?(%Ash.NotLoaded{}, v) or match?(%Ash.ForbiddenField{}, v)
      end)
      |> Enum.map(fn {k, v} -> {k, strip_metadata(v)} end)
      |> Enum.into(%{})
    else
      record
      |> Map.from_struct()
      |> Map.drop([:__meta__])
    end
  end

  def strip_metadata(list) when is_list(list) do
    Enum.map(list, &strip_metadata/1)
  end

  def strip_metadata(other), do: other

  defp public_fields(resource) do
    attrs = Ash.Resource.Info.public_attributes(resource) |> Enum.map(& &1.name)
    calcs = Ash.Resource.Info.public_calculations(resource) |> Enum.map(& &1.name)
    rels = Ash.Resource.Info.public_relationships(resource) |> Enum.map(& &1.name)
    aggs = Ash.Resource.Info.public_aggregates(resource) |> Enum.map(& &1.name)

    attrs ++ calcs ++ rels ++ aggs
  end

  defp not_found_error(resource, lookup_field, lookup_value) do
    Ash.Error.Query.NotFound.exception(
      resource: resource,
      primary_key: %{lookup_field => lookup_value}
    )
  end

  defp handle_success(data) do
    {permissions, cleaned_data} = extract_and_remove_permissions(data)
    
    if map_size(permissions) > 0 do
      %{ok: true, data: cleaned_data, meta: %{_permissions: permissions}}
    else
      %{ok: true, data: cleaned_data}
    end
  end

  defp handle_success(data, page) do
    {permissions, cleaned_data} = extract_and_remove_permissions(data)

    meta_pagination =
      %{
        limit: page.limit,
        offset: page.offset,
        count: page.count,
        has_more: page.more?
      }
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Enum.into(%{})

    meta = %{pagination: meta_pagination}
    meta = if map_size(permissions) > 0 do
      Map.put(meta, :_permissions, permissions)
    else
      meta
    end

    %{ok: true, data: cleaned_data, meta: meta}
  end

  defp extract_and_remove_permissions(data) when is_list(data) do
    if data == [] do
      {%{}, []}
    else
      {permissions, _} = extract_permissions_from_map(hd(data))
      new_data = Enum.map(data, fn item -> 
        {_, cleaned} = extract_permissions_from_map(item)
        cleaned
      end)
      {permissions, new_data}
    end
  end

  defp extract_and_remove_permissions(data) when is_map(data) do
    extract_permissions_from_map(data)
  end

  defp extract_and_remove_permissions(other), do: {%{}, other}

  defp extract_permissions_from_map(map) when is_map(map) do
    {perms, rest} = Map.split_with(map, fn {k, _v} -> 
      String.starts_with?(to_string(k), "can_") 
    end)
    {Map.new(perms), Map.new(rest)}
  end
  defp extract_permissions_from_map(other), do: {%{}, other}

  defp handle_error(error) do
    %{ok: false, error: Alva.Error.format(error)}
  end
end
