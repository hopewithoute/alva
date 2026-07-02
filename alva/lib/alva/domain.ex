defmodule Alva.Domain do
  @moduledoc """
  DSL extension for Ash.Domain to extract and verify Alva LiveVue events.
  """

  use Spark.Dsl.Extension,
    transformers: [Alva.Domain.Transformers.VerifyAndPersistEvents]
end
