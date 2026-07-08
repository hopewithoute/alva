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

    map = Alva.Registry.alva_event_map(TestDomain.Success)
    key_map = Alva.Registry.alva_event_key_map(TestDomain.Success)
    assert map["a.read"] |> elem(0) == TestResource.A
    assert map["b.read"] |> elem(0) == TestResource.B
    assert key_map[:a_read] |> elem(0) == TestResource.A
    assert key_map[:b_read] |> elem(0) == TestResource.B
  end

  test "compiles successfully and creates collection and signal maps" do
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

        collection :students do
          source event: :realtime_read, mode: :reset
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

    event_map = Alva.Registry.alva_event_map(TestDomain.Realtime)
    collection_map = Alva.Registry.alva_collection_map(TestDomain.Realtime)
    signal_map = Alva.Registry.alva_signal_map(TestDomain.Realtime)

    assert event_map["realtime.read"] |> elem(0) == TestResource.Realtime
    assert collection_map[:students] |> elem(0) == TestResource.Realtime
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

    collection_map = Alva.Registry.alva_collection_map(TestDomain.CollectionRealtime)

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

  test "fails to compile when duplicate application event name exists across configured domains" do
    Application.put_env(:alva, :ash_domains, [TestDomain.HostA, TestDomain.HostB])

    on_exit(fn ->
      Application.delete_env(:alva, :ash_domains)
    end)

    assert_raise Spark.Error.DslError,
                 ~r/Duplicate application event name "dup.read" in :alva across/,
                 fn ->
                   compile_module("""
                   defmodule TestResource.HostDupA do
                     use Ash.Resource,
                       domain: TestDomain.HostA,
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

                   defmodule TestResource.HostDupB do
                     use Ash.Resource,
                       domain: TestDomain.HostB,
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

                   defmodule TestDomain.HostA do
                     use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

                     resources do
                       resource TestResource.HostDupA
                     end
                   end

                   defmodule TestDomain.HostB do
                     use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

                     resources do
                       resource TestResource.HostDupB
                     end
                   end
                   """)
                 end
  end

  test "fails to compile when duplicate application collection key exists across configured domains" do
    Application.put_env(:alva, :ash_domains, [
      TestDomain.HostCollectionA,
      TestDomain.HostCollectionB
    ])

    on_exit(fn ->
      Application.delete_env(:alva, :ash_domains)
    end)

    assert_raise Spark.Error.DslError,
                 ~r/Duplicate application collection key :shared_orders in :alva across/,
                 fn ->
                   compile_module("""
                   defmodule TestResource.HostCollectionDupA do
                     use Ash.Resource,
                       domain: TestDomain.HostCollectionA,
                       validate_domain_inclusion?: false,
                       extensions: [Alva.Resource]

                     resource do
                       require_primary_key? false
                     end

                     actions do
                       defaults [:read]
                     end

                     live_vue do
                       event :list_a, name: "collection.a.list", action: :read

                       collection :shared_orders do
                         source event: :list_a, mode: :reset
                       end
                     end
                   end

                   defmodule TestResource.HostCollectionDupB do
                     use Ash.Resource,
                       domain: TestDomain.HostCollectionB,
                       validate_domain_inclusion?: false,
                       extensions: [Alva.Resource]

                     resource do
                       require_primary_key? false
                     end

                     actions do
                       defaults [:read]
                     end

                     live_vue do
                       event :list_b, name: "collection.b.list", action: :read

                       collection :shared_orders do
                         source event: :list_b, mode: :reset
                       end
                     end
                   end

                   defmodule TestDomain.HostCollectionA do
                     use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

                     resources do
                       resource TestResource.HostCollectionDupA
                     end
                   end

                   defmodule TestDomain.HostCollectionB do
                     use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

                     resources do
                       resource TestResource.HostCollectionDupB
                     end
                   end
                   """)
                 end
  end

  test "fails to compile when duplicate application signal key exists across configured domains" do
    Application.put_env(:alva, :ash_domains, [
      TestDomain.HostSignalKeyA,
      TestDomain.HostSignalKeyB
    ])

    on_exit(fn ->
      Application.delete_env(:alva, :ash_domains)
    end)

    assert_raise Spark.Error.DslError,
                 ~r/Duplicate application signal key :shared_signal in :alva across/,
                 fn ->
                   compile_module("""
                   defmodule TestResource.HostSignalKeyDupA do
                     use Ash.Resource,
                       domain: TestDomain.HostSignalKeyA,
                       validate_domain_inclusion?: false,
                       extensions: [Alva.Resource]

                     resource do
                       require_primary_key? false
                     end

                     actions do
                       defaults [:read]
                     end

                     live_vue do
                       signal :shared_signal, name: "signals.a", on: :created
                     end
                   end

                   defmodule TestResource.HostSignalKeyDupB do
                     use Ash.Resource,
                       domain: TestDomain.HostSignalKeyB,
                       validate_domain_inclusion?: false,
                       extensions: [Alva.Resource]

                     resource do
                       require_primary_key? false
                     end

                     actions do
                       defaults [:read]
                     end

                     live_vue do
                       signal :shared_signal, name: "signals.b", on: :updated
                     end
                   end

                   defmodule TestDomain.HostSignalKeyA do
                     use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

                     resources do
                       resource TestResource.HostSignalKeyDupA
                     end
                   end

                   defmodule TestDomain.HostSignalKeyB do
                     use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

                     resources do
                       resource TestResource.HostSignalKeyDupB
                     end
                   end
                   """)
                 end
  end

  test "fails to compile when duplicate application signal exposed name exists across configured domains" do
    Application.put_env(:alva, :ash_domains, [
      TestDomain.HostSignalNameA,
      TestDomain.HostSignalNameB
    ])

    on_exit(fn ->
      Application.delete_env(:alva, :ash_domains)
    end)

    assert_raise Spark.Error.DslError,
                 ~r/Duplicate application signal exposed name "signals.shared" in :alva across/,
                 fn ->
                   compile_module("""
                   defmodule TestResource.HostSignalNameDupA do
                     use Ash.Resource,
                       domain: TestDomain.HostSignalNameA,
                       validate_domain_inclusion?: false,
                       extensions: [Alva.Resource]

                     resource do
                       require_primary_key? false
                     end

                     actions do
                       defaults [:read]
                     end

                     live_vue do
                       signal :signal_a, name: "signals.shared", on: :created
                     end
                   end

                   defmodule TestResource.HostSignalNameDupB do
                     use Ash.Resource,
                       domain: TestDomain.HostSignalNameB,
                       validate_domain_inclusion?: false,
                       extensions: [Alva.Resource]

                     resource do
                       require_primary_key? false
                     end

                     actions do
                       defaults [:read]
                     end

                     live_vue do
                       signal :signal_b, name: "signals.shared", on: :updated
                     end
                   end

                   defmodule TestDomain.HostSignalNameA do
                     use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

                     resources do
                       resource TestResource.HostSignalNameDupA
                     end
                   end

                   defmodule TestDomain.HostSignalNameB do
                     use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

                     resources do
                       resource TestResource.HostSignalNameDupB
                     end
                   end
                   """)
                 end
  end

  test "fails to compile when legacy stream declarations are used" do
    stderr =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        compile_module("""
        defmodule TestResource.StreamLegacy do
          use Ash.Resource,
            domain: TestDomain.StreamRemoved,
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

        defmodule TestDomain.StreamRemoved do
          use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

          resources do
            resource TestResource.StreamLegacy
          end
        end
        """)
      end)

    assert stderr =~ "Alva stream projections have been removed"
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
        TestDomain.HostA,
        TestResource.HostDupA,
        TestResource.HostDupB,
        TestDomain.HostB,
        TestDomain.HostCollectionA,
        TestResource.HostCollectionDupA,
        TestDomain.HostCollectionB,
        TestResource.HostCollectionDupB,
        TestDomain.HostSignalKeyA,
        TestResource.HostSignalKeyDupA,
        TestDomain.HostSignalKeyB,
        TestResource.HostSignalKeyDupB,
        TestDomain.HostSignalNameA,
        TestResource.HostSignalNameDupA,
        TestDomain.HostSignalNameB,
        TestResource.HostSignalNameDupB,
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
