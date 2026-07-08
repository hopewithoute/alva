defmodule Alva.Domain.Transformers.VerifyAndPersistEventsTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  test "returns true for Ash.Domain.Transformers.DefineResources" do
    assert Alva.Domain.Transformers.VerifyAndPersistEvents.after?(Ash.Domain.Transformers.DefineResources)
    refute Alva.Domain.Transformers.VerifyAndPersistEvents.after?(SomeOtherTransformer)
  end

  test "verifies event name uniqueness across resources" do
    assert_raise Spark.Error.DslError, ~r/Duplicate event name "test" found in resource Res2/, fn ->
      Code.eval_quoted(quote do
        defmodule Res1 do
          use Ash.Resource, domain: DuplicateNameDomain, extensions: [Alva.Resource], data_layer: Ash.DataLayer.Ets
          live_vue do
            event :test1, name: "test", action: :read
          end
          actions do
            defaults [:read]
          end
          attributes do
            uuid_primary_key :id
          end
        end

        defmodule Res2 do
          use Ash.Resource, domain: DuplicateNameDomain, extensions: [Alva.Resource], data_layer: Ash.DataLayer.Ets
          live_vue do
            event :test2, name: "test", action: :read
          end
          actions do
            defaults [:read]
          end
          attributes do
            uuid_primary_key :id
          end
        end

        defmodule DuplicateNameDomain do
          use Ash.Domain, extensions: [Alva.Domain]

          resources do
            resource Res1
            resource Res2
          end
        end
      end)
    end
  end
end
