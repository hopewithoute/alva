defmodule Alva.Resource.Info do
  @moduledoc """
  Introspection helpers for Alva.Resource DSL.
  """

  def events(resource) do
    Spark.Dsl.Extension.get_entities(resource, [:live_vue])
  end
end
