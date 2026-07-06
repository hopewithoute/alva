defmodule Alva.Resource.Info do
  @moduledoc """
  Introspection helpers for Alva.Resource DSL.
  """

  def events(resource) do
    resource
    |> Spark.Dsl.Extension.get_entities([:live_vue])
    |> Enum.filter(&match?(%Alva.Resource.Event{}, &1))
  end

  def collections(resource) do
    resource
    |> Spark.Dsl.Extension.get_entities([:live_vue])
    |> Enum.filter(&match?(%Alva.Resource.Collection{}, &1))
    |> Enum.map(&normalize_collection/1)
  end

  def signals(resource) do
    resource
    |> Spark.Dsl.Extension.get_entities([:live_vue])
    |> Enum.filter(&match?(%Alva.Resource.Signal{}, &1))
  end

  @doc """
  Returns a list of all public field names (attributes, calculations, relationships, aggregates) for the resource.
  """
  def public_fields(resource) do
    attrs = Ash.Resource.Info.public_attributes(resource) |> Enum.map(& &1.name)
    calcs = Ash.Resource.Info.public_calculations(resource) |> Enum.map(& &1.name)
    rels = Ash.Resource.Info.public_relationships(resource) |> Enum.map(& &1.name)
    aggs = Ash.Resource.Info.public_aggregates(resource) |> Enum.map(& &1.name)

    attrs ++ calcs ++ rels ++ aggs
  end

  defp normalize_collection(%Alva.Resource.Collection{source: [source]} = collection) do
    %{collection | source: source}
  end

  defp normalize_collection(%Alva.Resource.Collection{source: []} = collection) do
    %{collection | source: nil}
  end

  defp normalize_collection(collection), do: collection
end
