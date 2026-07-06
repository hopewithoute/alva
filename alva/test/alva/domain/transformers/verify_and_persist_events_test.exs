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
        event :a_read, name: "a.read", action: :read
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
        event :b_read, name: "b.read", action: :read
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
    key_map = Alva.Domain.Info.alva_event_key_map(TestDomain.Success)
    assert map["a.read"] |> elem(0) == TestResource.A
    assert map["b.read"] |> elem(0) == TestResource.B
    assert key_map[:a_read] |> elem(0) == TestResource.A
    assert key_map[:b_read] |> elem(0) == TestResource.B
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
        event :realtime_read, name: "realtime.read", action: :read

        stream :students do
          insert on: :create
          update on: :update
          delete on: :destroy
        end

        signal :students_import_completed,
          name: "students.import_completed",
          on: :import_completed
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
    assert signal_map[:students_import_completed] |> elem(0) == TestResource.Realtime
  end

  test "compiles successfully and creates collection map" do
    assert_compile("""
    defmodule TestResource.CollectionRealtime do
      use Ash.Resource,
        domain: TestDomain.CollectionRealtime,
        validate_domain_inclusion?: false,
        extensions: [Alva.Resource]

      resource do
        require_primary_key? false
      end

      actions do
        defaults [:read]
      end

      live_vue do
        event :students_list, name: "students.list", action: :read

        collection :students do
          source event: :students_list, mode: :reset
          insert on: :create
        end
      end
    end

    defmodule TestDomain.CollectionRealtime do
      use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

      resources do
        resource TestResource.CollectionRealtime
      end
    end
    """)

    collection_map = Alva.Domain.Info.alva_collection_map(TestDomain.CollectionRealtime)

    assert collection_map[:students] |> elem(0) == TestResource.CollectionRealtime
    assert %Alva.Resource.Collection{} = collection_map[:students] |> elem(1)
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
                       event :dup_a_read, name: "dup.read", action: :read
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
                       event :dup_b_read, name: "dup.read", action: :read
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
                         insert on: :create
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
                         insert on: :other_create
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

  test "fails to compile when duplicate collection exists" do
    assert_raise Spark.Error.DslError,
                 ~r/Duplicate collection name :students found in resource/,
                 fn ->
                   compile_module("""
                   defmodule TestResource.CollectionDupA do
                     use Ash.Resource,
                       domain: TestDomain.CollectionDuplicate,
                       validate_domain_inclusion?: false,
                       extensions: [Alva.Resource]

                     resource do
                       require_primary_key? false
                     end

                     actions do
                       defaults [:read]
                     end

                     live_vue do
                       event :students_a, name: "students.a", action: :read

                       collection :students do
                         source event: :students_a, mode: :reset
                       end
                     end
                   end

                   defmodule TestResource.CollectionDupB do
                     use Ash.Resource,
                       domain: TestDomain.CollectionDuplicate,
                       validate_domain_inclusion?: false,
                       extensions: [Alva.Resource]

                     resource do
                       require_primary_key? false
                     end

                     actions do
                       defaults [:read]
                     end

                     live_vue do
                       event :students_b, name: "students.b", action: :read

                       collection :students do
                         source event: :students_b, mode: :reset
                       end
                     end
                   end

                   defmodule TestDomain.CollectionDuplicate do
                     use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

                     resources do
                       resource TestResource.CollectionDupA
                       resource TestResource.CollectionDupB
                     end
                   end
                   """)
                 end
  end

  test "fails to compile when duplicate signal exists" do
    assert_raise Spark.Error.DslError,
                 ~r/Duplicate signal exposed name "students.import_completed" found in resource/,
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
                       signal :students_import_completed_a,
                         name: "students.import_completed",
                         on: :import_completed
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
                       signal :students_import_completed_b,
                         name: "students.import_completed",
                         on: :other_import_completed
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

  test "fails to compile when duplicate signal key exists" do
    assert_raise Spark.Error.DslError,
                 ~r/Duplicate signal key :students_import_completed found in resource/,
                 fn ->
                   compile_module("""
                   defmodule TestResource.SignalKeyDupA do
                     use Ash.Resource,
                       domain: TestDomain.SignalKeyDuplicate,
                       validate_domain_inclusion?: false,
                       extensions: [Alva.Resource]

                     resource do
                       require_primary_key? false
                     end

                     actions do
                       defaults [:read]
                     end

                     live_vue do
                       signal :students_import_completed,
                         name: "students.import_completed.a",
                         on: :import_completed
                     end
                   end

                   defmodule TestResource.SignalKeyDupB do
                     use Ash.Resource,
                       domain: TestDomain.SignalKeyDuplicate,
                       validate_domain_inclusion?: false,
                       extensions: [Alva.Resource]

                     resource do
                       require_primary_key? false
                     end

                     actions do
                       defaults [:read]
                     end

                     live_vue do
                       signal :students_import_completed,
                         name: "students.import_completed.b",
                         on: :other_import_completed
                     end
                   end

                   defmodule TestDomain.SignalKeyDuplicate do
                     use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

                     resources do
                       resource TestResource.SignalKeyDupA
                       resource TestResource.SignalKeyDupB
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
        TestDomain.CollectionRealtime,
        TestResource.CollectionRealtime,
        TestDomain.StreamDuplicate,
        TestResource.StreamDupA,
        TestResource.StreamDupB,
        TestDomain.CollectionDuplicate,
        TestResource.CollectionDupA,
        TestResource.CollectionDupB,
        TestDomain.SignalDuplicate,
        TestResource.SignalDupA,
        TestResource.SignalDupB,
        TestDomain.SignalKeyDuplicate,
        TestResource.SignalKeyDupA,
        TestResource.SignalKeyDupB
      ],
      fn mod ->
        :code.purge(mod)
        :code.delete(mod)
      end
    )
  end
end
