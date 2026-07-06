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

  @doc """
  Returns a static O(1) map of all LiveVue event declaration keys registered across all resources in the domain.
  The map structure is: %{ :event_key => {ResourceModule, EventStruct} }
  """
  def alva_event_key_map(domain) do
    Spark.Dsl.Extension.get_persisted(domain, :alva_event_key_map, %{})
  end

  @doc """
  Returns a static O(1) map of all Alva Collections registered across all resources in the domain.
  The map structure is: %{ :collection_name => {ResourceModule, CollectionStruct} }
  """
  def alva_collection_map(domain) do
    Spark.Dsl.Extension.get_persisted(domain, :alva_collection_map, %{})
  end

  @doc """
  Returns a static O(1) map of all LiveVue signal projections registered across all resources in the domain.
  The map structure is: %{ :signal_key => {ResourceModule, SignalStruct} }
  """
  def alva_signal_map(domain) do
    Spark.Dsl.Extension.get_persisted(domain, :alva_signal_map, %{})
  end

  @doc """
  Returns a flat list of Ash action arguments configured as Ash.Type.File.
  """
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
end
