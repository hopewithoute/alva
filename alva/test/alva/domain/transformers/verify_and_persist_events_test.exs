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

  test "compiles successfully and creates stream and signal maps" do
    assert_compile("""
    defmodule TestResource.Realtime do
      use Ash.Resource,
        domain: TestDomain.Realtime,
        validate_domain_inclusion?: false,
        extensions: [Alva.Resource]

      resource do
        require_primary_key? false
      end

      actions do
        defaults [:read]
      end

      live_vue do
        event "realtime.read", action: :read

        stream :students do
          insert on: "student_created"
          update on: "student_updated"
          delete on: "student_deleted"
        end

        signal "students.import_completed",
          on: "student_import_completed"
      end
    end

    defmodule TestDomain.Realtime do
      use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

      resources do
        resource TestResource.Realtime
      end
    end
    """)

    event_map = Alva.Domain.Info.alva_event_map(TestDomain.Realtime)
    stream_map = Alva.Domain.Info.alva_stream_map(TestDomain.Realtime)
    signal_map = Alva.Domain.Info.alva_signal_map(TestDomain.Realtime)

    assert event_map["realtime.read"] |> elem(0) == TestResource.Realtime
    assert stream_map[:students] |> elem(0) == TestResource.Realtime
    assert signal_map["students.import_completed"] |> elem(0) == TestResource.Realtime
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

  test "fails to compile when duplicate stream exists" do
    assert_raise Spark.Error.DslError,
                 ~r/Duplicate stream name :students found in resource/,
                 fn ->
                   compile_module("""
                   defmodule TestResource.StreamDupA do
                     use Ash.Resource,
                       domain: TestDomain.StreamDuplicate,
                       validate_domain_inclusion?: false,
                       extensions: [Alva.Resource]

                     resource do
                       require_primary_key? false
                     end

                     actions do
                       defaults [:read]
                     end

                     live_vue do
                       stream :students do
                         insert on: "student_created"
                       end
                     end
                   end

                   defmodule TestResource.StreamDupB do
                     use Ash.Resource,
                       domain: TestDomain.StreamDuplicate,
                       validate_domain_inclusion?: false,
                       extensions: [Alva.Resource]

                     resource do
                       require_primary_key? false
                     end

                     actions do
                       defaults [:read]
                     end

                     live_vue do
                       stream :students do
                         insert on: "other_student_created"
                       end
                     end
                   end

                   defmodule TestDomain.StreamDuplicate do
                     use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

                     resources do
                       resource TestResource.StreamDupA
                       resource TestResource.StreamDupB
                     end
                   end
                   """)
                 end
  end

  test "fails to compile when duplicate signal exists" do
    assert_raise Spark.Error.DslError,
                 ~r/Duplicate signal name "students.import_completed" found in resource/,
                 fn ->
                   compile_module("""
                   defmodule TestResource.SignalDupA do
                     use Ash.Resource,
                       domain: TestDomain.SignalDuplicate,
                       validate_domain_inclusion?: false,
                       extensions: [Alva.Resource]

                     resource do
                       require_primary_key? false
                     end

                     actions do
                       defaults [:read]
                     end

                     live_vue do
                       signal "students.import_completed",
                         on: "student_import_completed"
                     end
                   end

                   defmodule TestResource.SignalDupB do
                     use Ash.Resource,
                       domain: TestDomain.SignalDuplicate,
                       validate_domain_inclusion?: false,
                       extensions: [Alva.Resource]

                     resource do
                       require_primary_key? false
                     end

                     actions do
                       defaults [:read]
                     end

                     live_vue do
                       signal "students.import_completed",
                         on: "other_student_import_completed"
                     end
                   end

                   defmodule TestDomain.SignalDuplicate do
                     use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

                     resources do
                       resource TestResource.SignalDupA
                       resource TestResource.SignalDupB
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
        TestResource.DupB,
        TestDomain.Realtime,
        TestResource.Realtime,
        TestDomain.StreamDuplicate,
        TestResource.StreamDupA,
        TestResource.StreamDupB,
        TestDomain.SignalDuplicate,
        TestResource.SignalDupA,
        TestResource.SignalDupB
      ],
      fn mod ->
        :code.purge(mod)
        :code.delete(mod)
      end
    )
  end
end
