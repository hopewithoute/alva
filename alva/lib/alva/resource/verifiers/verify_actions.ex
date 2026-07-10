defmodule Alva.Resource.Verifiers.VerifyActions do
  @moduledoc since: "0.1.0"
  @moduledoc """
  A Spark DSL verifier for `Alva.Resource`.

  This verifier ensures that all events declared in the `alva do ... end` block point to
  valid, existing Ash actions. It specifically checks that:

    * The specified action exists.
    * The specified action is configured as `public?(true)`.
    * The action's return type is not empty (warns if the DTO would be empty).
  """

  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    projections = Spark.Dsl.Extension.get_entities(dsl_state, [:alva])
    events = Enum.filter(projections, &match?(%Alva.Resource.Event{}, &1))

    module = Spark.Dsl.Extension.get_persisted(dsl_state, :module)

    Enum.each(events, fn event ->
      action = Ash.Resource.Info.action(dsl_state, event.action)

      if is_nil(action) do
        raise_dsl_error(module, event, "Action #{inspect(event.action)} does not exist.")
      end

      unless action.public? do
        raise_dsl_error(
          module,
          event,
          "Action #{inspect(event.action)} must be public? true to be exposed via alva."
        )
      end

      if empty_dto?(dsl_state, action) do
        require Logger

        Logger.warning(
          "Alva Extension: Event #{inspect(event.name)} maps to action #{inspect(event.action)} which returns an empty DTO. Vue will receive an empty payload."
        )
      end
    end)

    :ok
  end

  defp empty_dto?(dsl_state, action) do
    if action.type == :action do
      is_nil(action.returns)
    else
      public_fields_count(dsl_state) == 0
    end
  end

  defp public_fields_count(dsl_state) do
    Alva.Registry.public_fields(dsl_state) |> length()
  end

  defp raise_dsl_error(module, event, message) do
    raise Spark.Error.DslError,
      module: module,
      path: [:alva, :event, event.key],
      message: message
  end
end
