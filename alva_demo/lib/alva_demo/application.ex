defmodule AlvaDemo.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AlvaDemoWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:alva_demo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AlvaDemo.PubSub},
      AlvaDemoWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: AlvaDemo.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    AlvaDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
