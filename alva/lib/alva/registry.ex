defmodule Alva.Registry do
  @moduledoc """
  Host-app registry boundary for Alva runtime and code generation.
  Consolidates introspection across the App, Domain, and Resource levels.
  """

  defstruct otp_app: nil,
            domains: [],
            event_map: %{},
            subscription_map: %{},
            collection_map: %{},
            signal_map: %{},
            file_upload_arguments: []

  @registry_cache_key {__MODULE__, :registry}

  # --- INTERNAL SPARK ADAPTER ---
  defmodule SparkAdapter do
    @moduledoc false
    def get_persisted(module, key, default) do
      Spark.Dsl.Extension.get_persisted(module, key, default)
    end

    def get_entities(module, path) do
      Spark.Dsl.Extension.get_entities(module, path)
    end
  end

  # ==========================================
  # APP LEVEL INTROSPECTION
  # ==========================================

  def registry(otp_app) when is_atom(otp_app) and not is_nil(otp_app) do
    if cache_registry?() do
      cache_key = {@registry_cache_key, otp_app}

      case :persistent_term.get(cache_key, :missing) do
        :missing ->
          registry = build_registry(otp_app)
          :persistent_term.put(cache_key, registry)
          registry

        registry ->
          registry
      end
    else
      build_registry(otp_app)
    end
  end

  def event_map(otp_app) when is_atom(otp_app) and not is_nil(otp_app) do
    registry(otp_app).event_map
  end

  def fetch_event(otp_app, event_name)
      when is_atom(otp_app) and not is_nil(otp_app) and is_binary(event_name) do
    case Map.fetch(event_map(otp_app), event_name) do
      {:ok, {resource, event}} -> {:ok, resource, event}
      :error -> :error
    end
  end

  def subscription_map(otp_app) when is_atom(otp_app) and not is_nil(otp_app) do
    registry(otp_app).subscription_map
  end

  def fetch_subscription(otp_app, subscription_name)
      when is_atom(otp_app) and not is_nil(otp_app) and is_binary(subscription_name) do
    case Enum.find(subscription_map(otp_app), fn {_key, {_res, sub}} ->
           sub.name == subscription_name
         end) do
      {_key, {resource, subscription}} -> {:ok, resource, subscription}
      nil -> :error
    end
  end

  def fetch_subscription_by_key(otp_app, subscription_key)
      when is_atom(otp_app) and not is_nil(otp_app) and is_atom(subscription_key) do
    case Map.fetch(subscription_map(otp_app), subscription_key) do
      {:ok, {resource, subscription}} -> {:ok, resource, subscription}
      :error -> :error
    end
  end

  def otp_app(%{endpoint: endpoint}), do: otp_app(endpoint)

  def otp_app(endpoint) when is_atom(endpoint) do
    cond do
      function_exported?(endpoint, :otp_app, 0) ->
        endpoint.otp_app()

      otp_app = Application.get_application(endpoint) ->
        otp_app

      function_exported?(endpoint, :config, 1) ->
        safe_endpoint_config(endpoint, :otp_app)

      true ->
        nil
    end
  end

  def otp_app(_), do: nil

  def verify_host_app_command_uniqueness!(current_domain, current_event_map) do
    verify_host_app_uniqueness!(
      current_domain,
      current_event_map,
      &alva_event_map/1,
      "application event name"
    )
  end

  def verify_host_app_subscription_uniqueness!(current_domain, current_subscription_map) do
    verify_host_app_uniqueness!(
      current_domain,
      current_subscription_map,
      &alva_subscription_map/1,
      "application subscription key"
    )
  end

  def verify_host_app_collection_uniqueness!(current_domain, current_collection_map) do
    verify_host_app_uniqueness!(
      current_domain,
      current_collection_map,
      &alva_collection_map/1,
      "application collection key"
    )
  end

  def verify_host_app_signal_key_uniqueness!(current_domain, current_signal_map) do
    verify_host_app_uniqueness!(
      current_domain,
      current_signal_map,
      &alva_signal_map/1,
      "application signal key"
    )
  end

  def verify_host_app_signal_name_uniqueness!(current_domain, current_signal_name_map) do
    verify_host_app_uniqueness!(
      current_domain,
      current_signal_name_map,
      &signal_name_map/1,
      "application signal exposed name"
    )
  end

  defp verify_host_app_uniqueness!(current_domain, current_entries, fetcher, identity_label) do
    with true <- Code.ensure_loaded?(Mix.Project),
         otp_app when is_atom(otp_app) <- Mix.Project.config()[:app],
         domains when is_list(domains) <- Ash.Info.domains(otp_app),
         true <- current_domain in domains,
         true <- all_domains_loaded?(domains, current_domain) do
      verify_unique_host_app_entries!(
        otp_app,
        domains,
        current_domain,
        current_entries,
        fetcher,
        identity_label
      )
    else
      _ -> :ok
    end
  end

  defp build_registry(otp_app) do
    domains = Ash.Info.domains(otp_app)

    %__MODULE__{
      otp_app: otp_app,
      domains: domains,
      event_map: build_unique_map!(domains, &alva_event_map/1, "event name"),
      subscription_map:
        build_unique_map!(domains, &alva_subscription_map/1, "subscription key"),
      collection_map:
        build_unique_map!(domains, &alva_collection_map/1, "collection name"),
      signal_map: build_unique_map!(domains, &alva_signal_map/1, "signal key"),
      file_upload_arguments: build_file_upload_arguments(domains)
    }
  end

  defp build_unique_map!(domains, fetcher, identity_label) do
    domains
    |> Enum.reduce(%{}, fn domain, acc ->
      fetcher.(domain)
      |> Enum.reduce(acc, fn {identity, {resource, value}}, map ->
        case map do
          %{^identity => {existing_resource, _existing_value}} ->
            raise ArgumentError,
                  "Duplicate application #{identity_label} #{inspect(identity)} found in #{inspect(resource)} (already defined in #{inspect(existing_resource)})"

          _ ->
            Map.put(map, identity, {resource, value})
        end
      end)
    end)
  end

  defp build_file_upload_arguments(domains) do
    domains
    |> Enum.flat_map(&file_upload_arguments/1)
    |> Enum.uniq_by(& &1.name)
  end

  defp all_domains_loaded?(domains, current_domain) do
    Enum.all?(domains, fn domain ->
      domain == current_domain or Code.ensure_loaded?(domain)
    end)
  end

  defp verify_unique_host_app_entries!(
         otp_app,
         domains,
         current_domain,
         current_entries,
         fetcher,
         identity_label
       ) do
    _ =
      domains
      |> Enum.reduce(%{}, fn domain, acc ->
        domain_entries =
          if domain == current_domain do
            current_entries
          else
            fetcher.(domain)
          end

        Enum.reduce(domain_entries, acc, fn {identity, {resource, _value}}, map ->
          case map do
            %{^identity => {existing_domain, existing_resource}} ->
              raise Spark.Error.DslError,
                module: current_domain,
                path: [:resources],
                message:
                  "Duplicate #{identity_label} #{inspect(identity)} in #{inspect(otp_app)} across #{inspect(domain)} / #{inspect(resource)} (already defined in #{inspect(existing_domain)} / #{inspect(existing_resource)})"

            _ ->
              Map.put(map, identity, {domain, resource})
          end
        end)
      end)

    :ok
  end

  defp cache_registry? do
    not (Code.ensure_loaded?(Mix) and function_exported?(Mix, :env, 0) and
           Mix.env() in [:dev, :test])
  end

  defp safe_endpoint_config(endpoint, key) do
    endpoint.config(key)
  rescue
    ArgumentError -> nil
  end

  defp signal_name_map(domain) do
    domain
    |> Ash.Domain.Info.resources()
    |> Enum.reduce(%{}, fn resource, acc ->
      resource
      |> signals()
      |> Enum.reduce(acc, fn signal, map ->
        Map.put(map, signal.name, {resource, signal})
      end)
    end)
  end

  # ==========================================
  # DOMAIN LEVEL INTROSPECTION
  # ==========================================

  def alva_event_map(domain) do
    SparkAdapter.get_persisted(domain, :alva_event_map, %{})
  end

  def alva_event_key_map(domain) do
    SparkAdapter.get_persisted(domain, :alva_event_key_map, %{})
  end

  def alva_collection_map(domain) do
    SparkAdapter.get_persisted(domain, :alva_collection_map, %{})
  end

  def alva_subscription_map(domain) do
    SparkAdapter.get_persisted(domain, :alva_subscription_map, %{})
  end

  def alva_signal_map(domain) do
    SparkAdapter.get_persisted(domain, :alva_signal_map, %{})
  end

  def file_upload_arguments(domain) do
    domain
    |> alva_event_map()
    |> Enum.flat_map(fn {_event_name, {resource, event_def}} ->
      action = Ash.Resource.Info.action(resource, event_def.action)

      if action do
        Enum.filter(action.arguments, fn arg ->
          case arg.type do
            Ash.Type.File -> true
            {:array, Ash.Type.File} -> true
            _ -> false
          end
        end)
      else
        []
      end
    end)
  end

  # ==========================================
  # RESOURCE LEVEL INTROSPECTION
  # ==========================================

  def events(resource) do
    SparkAdapter.get_entities(resource, [:live_vue])
    |> Enum.filter(&match?(%Alva.Resource.Event{}, &1))
  end

  def collections(resource) do
    SparkAdapter.get_entities(resource, [:live_vue])
    |> Enum.filter(&match?(%Alva.Resource.Collection{}, &1))
    |> Enum.map(&normalize_collection/1)
  end

  def signals(resource) do
    SparkAdapter.get_entities(resource, [:live_vue])
    |> Enum.filter(&match?(%Alva.Resource.Signal{}, &1))
  end

  def subscriptions(resource) do
    SparkAdapter.get_entities(resource, [:live_vue])
    |> Enum.filter(&match?(%Alva.Resource.Subscription{}, &1))
    |> Enum.map(&normalize_subscription/1)
  end

  def public_fields(resource) do
    attrs = Ash.Resource.Info.public_attributes(resource) |> Enum.map(& &1.name)
    calcs = Ash.Resource.Info.public_calculations(resource) |> Enum.map(& &1.name)
    rels = Ash.Resource.Info.public_relationships(resource) |> Enum.map(& &1.name)
    aggs = Ash.Resource.Info.public_aggregates(resource) |> Enum.map(& &1.name)

    attrs ++ calcs ++ rels ++ aggs
  end

  defp normalize_collection(%Alva.Resource.Collection{source: source} = collection) do
    %{collection | source: unwrap_source(source)}
  end

  defp normalize_subscription(%Alva.Resource.Subscription{source: source} = sub) do
    %{sub | source: unwrap_source(source)}
  end

  defp unwrap_source([source]), do: source
  defp unwrap_source([]), do: nil
  defp unwrap_source(source), do: source
end
