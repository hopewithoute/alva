defmodule Alva.App.Info do
  @moduledoc """
  Host-app registry boundary for Alva runtime and code generation.
  """

  defmodule Registry do
    @moduledoc false

    defstruct otp_app: nil,
              domains: [],
              event_map: %{},
              collection_map: %{},
              signal_map: %{},
              file_upload_arguments: []
  end

  @registry_cache_key {__MODULE__, :registry}

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
      &Alva.Domain.Info.alva_event_map/1,
      "application event name"
    )
  end

  def verify_host_app_collection_uniqueness!(current_domain, current_collection_map) do
    verify_host_app_uniqueness!(
      current_domain,
      current_collection_map,
      &Alva.Domain.Info.alva_collection_map/1,
      "application collection key"
    )
  end

  def verify_host_app_signal_key_uniqueness!(current_domain, current_signal_map) do
    verify_host_app_uniqueness!(
      current_domain,
      current_signal_map,
      &Alva.Domain.Info.alva_signal_map/1,
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

    %Registry{
      otp_app: otp_app,
      domains: domains,
      event_map: build_unique_map!(domains, &Alva.Domain.Info.alva_event_map/1, "event name"),
      collection_map:
        build_unique_map!(domains, &Alva.Domain.Info.alva_collection_map/1, "collection name"),
      signal_map: build_unique_map!(domains, &Alva.Domain.Info.alva_signal_map/1, "signal key"),
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
    |> Enum.flat_map(&Alva.Domain.Info.file_upload_arguments/1)
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
      |> Alva.Resource.Info.signals()
      |> Enum.reduce(acc, fn signal, map ->
        Map.put(map, signal.name, {resource, signal})
      end)
    end)
  end
end
