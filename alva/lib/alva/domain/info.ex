defmodule Alva.Domain.Info do
  @moduledoc """
  Introspection helpers for Alva.Domain DSL.
  """

  @doc """
  Returns a static O(1) map of all LiveVue events registered across all resources in the domain.
  The map structure is: %{ "event_name" => {ResourceModule, EventStruct} }
  """
  def alva_event_map(domain) do
    Spark.Dsl.Extension.get_persisted(domain, :alva_event_map, %{})
  end
end
