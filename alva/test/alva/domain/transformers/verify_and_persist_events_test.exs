defmodule Alva.Domain.Transformers.VerifyAndPersistEventsTest do
  use ExUnit.Case

  test "compiles successfully and creates event map" do
    assert_compile("""
    defmodule TestResource.A do
      use Ash.Resource,
        domain: TestDomain.Success,
        validate_domain_inclusion?: false,
        extensions: [Alva.Resource]

      resource do
        require_primary_key? false
      end

      actions do
        defaults [:read]
        read :list
      end

      live_vue do
        event "a.read", action: :read
      end
    end

    defmodule TestResource.B do
      use Ash.Resource,
        domain: TestDomain.Success,
        validate_domain_inclusion?: false,
        extensions: [Alva.Resource]

      resource do
        require_primary_key? false
      end

      actions do
        defaults [:read]
      end

      live_vue do
        event "b.read", action: :read
      end
    end

    defmodule TestDomain.Success do
      use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

      resources do
        resource TestResource.A
        resource TestResource.B
      end
    end
    """)

    map = Alva.Domain.Info.alva_event_map(TestDomain.Success)
    assert map["a.read"] |> elem(0) == TestResource.A
    assert map["b.read"] |> elem(0) == TestResource.B
  end

  test "fails to compile when duplicate event exists" do
    assert_raise Spark.Error.DslError,
                 ~r/Duplicate event name "dup.read" found in resource/,
                 fn ->
                   compile_module("""
                   defmodule TestResource.DupA do
                     use Ash.Resource,
                       domain: TestDomain.Duplicate,
                       validate_domain_inclusion?: false,
                       extensions: [Alva.Resource]

                     resource do
                       require_primary_key? false
                     end

                     actions do
                       defaults [:read]
                     end

                     live_vue do
                       event "dup.read", action: :read
                     end
                   end

                   defmodule TestResource.DupB do
                     use Ash.Resource,
                       domain: TestDomain.Duplicate,
                       validate_domain_inclusion?: false,
                       extensions: [Alva.Resource]

                     resource do
                       require_primary_key? false
                     end

                     actions do
                       defaults [:read]
                     end

                     live_vue do
                       event "dup.read", action: :read
                     end
                   end

                   defmodule TestDomain.Duplicate do
                     use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

                     resources do
                       resource TestResource.DupA
                       resource TestResource.DupB
                     end
                   end
                   """)
                 end
  end

  setup_all do
    Code.compiler_options(ignore_module_conflict: true)
    :ok
  end

  # Helpers to compile modules dynamically in tests
  defp assert_compile(code) do
    assert [_ | _] = Code.compile_string(code)
  end

  defp compile_module(code) do
    Code.compile_string(code)
  after
    Enum.each(
      [
        TestDomain.Success,
        TestResource.A,
        TestResource.B,
        TestDomain.Duplicate,
        TestResource.DupA,
        TestResource.DupB
      ],
      fn mod ->
        :code.purge(mod)
        :code.delete(mod)
      end
    )
  end
end
