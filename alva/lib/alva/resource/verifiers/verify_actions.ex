defmodule Alva.Resource.Verifiers.VerifyActions do
  @moduledoc false

  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    projections = Spark.Dsl.Extension.get_entities(dsl_state, [:live_vue])
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
          "Action #{inspect(event.action)} must be public? true to be exposed via live_vue."
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
      path: [:live_vue, :event, event.key],
      message: message
  end
end
