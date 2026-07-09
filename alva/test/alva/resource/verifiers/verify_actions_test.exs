defmodule Alva.Resource.Verifiers.VerifyActionsTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  # We need to stub Spark.Dsl.Extension for our test since the real one expects a real struct.
  # But VerifyActions calls Spark.Dsl.Extension.get_entities and get_persisted, and Ash.Resource.Info.action.
  # It's easier to just build a real module and capture the error!

  test "verifies action exists" do
    output =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.eval_quoted(
          quote do
            defmodule MissingActionResource do
              use Ash.Resource,
                domain: nil,
                extensions: [Alva.Resource],
                data_layer: Ash.DataLayer.Ets

              live_vue do
                event(:test, name: "test", action: :missing_action)
              end

              actions do
                defaults [:read]
              end

              attributes do
                uuid_primary_key :id
              end
            end
          end
        )
      end)

    assert output =~ "Action :missing_action does not exist"
  end

  test "verifies action is public" do
    output =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.eval_quoted(
          quote do
            defmodule PrivateActionResource do
              use Ash.Resource,
                domain: nil,
                extensions: [Alva.Resource],
                data_layer: Ash.DataLayer.Ets

              live_vue do
                event(:test, name: "test", action: :private_read)
              end

              actions do
                read :private_read do
                  public? false
                end
              end

              attributes do
                uuid_primary_key :id
              end
            end
          end
        )
      end)

    assert output =~ "Action :private_read must be public? true to be exposed via live_vue"
  end

  test "logs warning for empty dto on regular resource" do
    log =
      capture_log(fn ->
        defmodule EmptyDtoResource do
          use Ash.Resource,
            domain: nil,
            extensions: [Alva.Resource],
            data_layer: Ash.DataLayer.Ets

          live_vue do
            event(:test, name: "test", action: :read)
          end

          actions do
            defaults [:read]
          end

          # No public attributes
          attributes do
            uuid_primary_key :id, public?: false
          end
        end
      end)

    assert log =~ "Event \"test\" maps to action :read which returns an empty DTO"
  end

  test "logs warning for empty dto on generic action" do
    log =
      capture_log(fn ->
        defmodule EmptyDtoGenericResource do
          use Ash.Resource,
            domain: nil,
            extensions: [Alva.Resource],
            data_layer: Ash.DataLayer.Ets

          live_vue do
            event(:test, name: "test", action: :say_hello)
          end

          actions do
            defaults [:read]

            action :say_hello do
              run fn _, _ -> {:ok, nil} end
            end
          end

          attributes do
            uuid_primary_key :id
          end
        end
      end)

    assert log =~ "Event \"test\" maps to action :say_hello which returns an empty DTO"
  end
end
