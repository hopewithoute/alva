defmodule Alva.Domain do
  @moduledoc since: "0.1.0"
  @moduledoc """
  DSL extension for `Ash.Domain` to extract and verify Alva events and signals.

  In the V2 architecture, domain-level event/signal resolution is handled
  dynamically by `Alva.Registry` at runtime. This module exists primarily
  for backwards compatibility and compile-time verification.

  See `Alva.Registry` for the current runtime resolution path, and
  `Alva.Resource` for defining events and signals.
  """

  use Spark.Dsl.Extension,
    transformers: [Alva.Domain.Transformers.VerifyAndPersistEvents]
end
