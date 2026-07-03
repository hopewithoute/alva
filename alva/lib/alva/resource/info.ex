defmodule Alva.Resource.Info do
  @moduledoc """
  Introspection helpers for Alva.Resource DSL.
  """

  def events(resource) do
    resource
    |> Spark.Dsl.Extension.get_entities([:live_vue])
    |> Enum.filter(&match?(%Alva.Resource.Event{}, &1))
  end

  def streams(resource) do
    resource
    |> Spark.Dsl.Extension.get_entities([:live_vue])
    |> Enum.filter(&match?(%Alva.Resource.Stream{}, &1))
  end

  def signals(resource) do
    resource
    |> Spark.Dsl.Extension.get_entities([:live_vue])
    |> Enum.filter(&match?(%Alva.Resource.Signal{}, &1))
  end
end
