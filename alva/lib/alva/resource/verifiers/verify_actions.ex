defmodule Alva.Resource.Verifiers.VerifyActions do
  @moduledoc false

  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    events = Spark.Dsl.Extension.get_entities(dsl_state, [:live_vue])
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
    end)

    :ok
  end

  defp raise_dsl_error(module, event, message) do
    raise Spark.Error.DslError,
      module: module,
      path: [:live_vue, :event, event.name],
      message: message
  end
end
