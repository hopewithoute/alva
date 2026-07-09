defmodule Alva.Registry do
  @moduledoc """
  Host-app registry boundary for Alva runtime and code generation.
  Consolidates introspection across the App, Domain, and Resource levels.
  """

  defstruct otp_app: nil,
            domains: [],
            event_map: %{},
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

  def signal_map(otp_app) when is_atom(otp_app) and not is_nil(otp_app) do
    registry(otp_app).signal_map
  end

  def fetch_signal(otp_app, signal_name)
      when is_atom(otp_app) and not is_nil(otp_app) and is_binary(signal_name) do
    case Map.fetch(signal_map(otp_app), signal_name) do
      {:ok, {resource, signal}} -> {:ok, resource, signal}
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

  def verify_host_app_signal_uniqueness!(current_domain, current_signal_map) do
    verify_host_app_uniqueness!(
      current_domain,
      current_signal_map,
      &alva_signal_map/1,
      "application signal name"
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
      signal_map: build_unique_map!(domains, &alva_signal_map/1, "signal name"),
      file_upload_arguments: build_file_upload_arguments(domains)
    }
  end

  defp build_unique_map!(domains, fetcher, identity_label) do
    Enum.reduce(domains, %{}, fn domain, acc ->
      domain
      |> fetcher.()
      |> reduce_unique_map!(acc, identity_label)
    end)
  end

  defp reduce_unique_map!(entries, acc, identity_label) do
    Enum.reduce(entries, acc, fn {identity, {resource, value}}, map ->
      case map do
        %{^identity => {existing_resource, _existing_value}} ->
          raise ArgumentError,
                "Duplicate application #{identity_label} #{inspect(identity)} found in #{inspect(resource)} (already defined in #{inspect(existing_resource)})"

        _ ->
          Map.put(map, identity, {resource, value})
      end
    end)
  end

  defp build_file_upload_arguments(domains) do
    domains
    |> Enum.flat_map(&file_upload_arguments/1)
    |> Enum.reduce(%{}, fn arg, acc ->
      case Map.fetch(acc, arg.name) do
        {:ok, existing_arg} ->
          if arg.type != existing_arg.type or arg.constraints != existing_arg.constraints do
            raise ArgumentError,
                  "Conflicting file upload arguments found for #{inspect(arg.name)}. Both have the same name but different types or constraints."
          else
            acc
          end

        :error ->
          Map.put(acc, arg.name, arg)
      end
    end)
    |> Map.values()
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
      Enum.reduce(domains, %{}, fn domain, acc ->
        domain_entries =
          if domain == current_domain do
            current_entries
          else
            fetcher.(domain)
          end

        reduce_domain_entries!(
          domain_entries,
          acc,
          domain,
          current_domain,
          otp_app,
          identity_label
        )
      end)

    :ok
  end

  defp reduce_domain_entries!(
         domain_entries,
         acc,
         domain,
         current_domain,
         otp_app,
         identity_label
       ) do
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

  # ==========================================
  # DOMAIN LEVEL INTROSPECTION
  # ==========================================

  def alva_event_map(domain) do
    SparkAdapter.get_persisted(domain, :alva_event_map, %{})
  end

  def alva_event_key_map(domain) do
    SparkAdapter.get_persisted(domain, :alva_event_key_map, %{})
  end

  def alva_signal_map(domain) do
    SparkAdapter.get_persisted(domain, :alva_signal_map, %{})
  end

  def alva_signal_key_map(domain) do
    SparkAdapter.get_persisted(domain, :alva_signal_key_map, %{})
  end

  def file_upload_arguments(domain) do
    domain
    |> alva_event_map()
    |> Enum.flat_map(fn {_event_name, {resource, event_def}} ->
      resource
      |> Ash.Resource.Info.action(event_def.action)
      |> maybe_file_args()
    end)
  end

  defp maybe_file_args(nil), do: []
  defp maybe_file_args(action), do: Enum.filter(action.arguments, &file_arg?/1)

  defp file_arg?(arg) do
    case arg.type do
      Ash.Type.File -> true
      {:array, Ash.Type.File} -> true
      _ -> false
    end
  end

  # ==========================================
  # RESOURCE LEVEL INTROSPECTION
  # ==========================================

  def events(resource) do
    get_live_vue_entities(resource, Alva.Resource.Event)
  end

  def signals(resource) do
    get_live_vue_entities(resource, Alva.Resource.Signal)
  end

  defp get_live_vue_entities(resource, module) do
    SparkAdapter.get_entities(resource, [:alva])
    |> Enum.filter(&is_struct(&1, module))
  end

  def public_fields(resource) do
    [
      Ash.Resource.Info.public_attributes(resource),
      Ash.Resource.Info.public_calculations(resource),
      Ash.Resource.Info.public_relationships(resource),
      Ash.Resource.Info.public_aggregates(resource)
    ]
    |> Enum.flat_map(fn items -> Enum.map(items, & &1.name) end)
  end
end
