defmodule TestDomain do
  use Ash.Domain, validate_config_inclusion?: false
end

defmodule Alva.Resource.Verifiers.VerifyActionsTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  test "compiles successfully when actions are valid and public" do
    assert_compile("""
    defmodule TestResource.Valid do
      use Ash.Resource,
        domain: TestDomain,
        validate_domain_inclusion?: false,
        extensions: [Alva.Resource]

      resource do
        require_primary_key? false
      end

      actions do
        defaults [:read]
        
        create :create do
          accept []
        end
      end

      live_vue do
        event :valid_read, name: "valid.read", action: :read
        event :valid_create, name: "valid.create", action: :create
      end
    end
    """)
  end

  test "compiles successfully with collection and signal projections" do
    assert_compile("""
    defmodule TestResource.RealtimeValid do
      use Ash.Resource,
        domain: TestDomain,
        validate_domain_inclusion?: false,
        extensions: [Alva.Resource]

      resource do
        require_primary_key? false
      end

      actions do
        defaults [:read]
      end

      live_vue do
        event :valid_realtime_read, name: "valid.realtime.read", action: :read

        collection :students do
          source event: :valid_realtime_read, mode: :reset
          insert on: :create
          update on: :update
          delete on: :destroy
        end

        signal :students_import_completed,
          name: "students.import_completed",
          on: :import_completed
      end
    end
    """)

    assert [
             %Alva.Resource.Collection{
               name: :students,
               source: %Alva.Resource.CollectionSource{
                 event: :valid_realtime_read,
                 mode: :reset
               },
               operations: [
                 %Alva.Resource.CollectionOperation{op: :insert, on: :create},
                 %Alva.Resource.CollectionOperation{op: :update, on: :update},
                 %Alva.Resource.CollectionOperation{op: :delete, on: :destroy}
               ]
             }
           ] =
             Alva.Registry.collections(TestResource.RealtimeValid)

    assert [
             %Alva.Resource.Signal{
               key: :students_import_completed,
               name: "students.import_completed"
             }
           ] =
             Alva.Registry.signals(TestResource.RealtimeValid)
  end

  test "compiles successfully with collection source and operation projections" do
    assert_compile("""
    defmodule TestResource.CollectionValid do
      use Ash.Resource,
        domain: TestDomain,
        validate_domain_inclusion?: false,
        extensions: [Alva.Resource],
        notifiers: [Ash.Notifier.PubSub]

      resource do
        require_primary_key? false
      end

      actions do
        defaults [:read]

        create :create do
          accept []
        end
      end

      pub_sub do
        module TestPubSub

        publish "student_created", :create, "students"
      end

      live_vue do
        event :students_list, name: "students.list", action: :read

        collection :students do
          source event: :students_list, mode: :reset
          insert on: :create
        end
      end
    end
    """)

    assert [
             %Alva.Resource.Collection{
               name: :students,
               source: %Alva.Resource.CollectionSource{event: :students_list, mode: :reset},
               operations: [
                 %Alva.Resource.CollectionOperation{op: :insert, on: :create}
               ]
             }
           ] = Alva.Registry.collections(TestResource.CollectionValid)
  end

  test "emits a warning when collection has only a source" do
    import ExUnit.CaptureLog

    log =
      capture_log(fn ->
        compile_module("""
        defmodule TestResource.SourceOnlyCollection do
          use Ash.Resource,
            domain: TestDomain,
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
            end
          end
        end
        """)
      end)

    assert log =~
             "Alva Extension: Collection :students has no insert/update/delete mappings and will not update from PubSub."
  end

  test "compiles successfully when projections reference declared pubsub publications" do
    assert_compile("""
    defmodule TestResource.PubSubRealtimeValid do
      use Ash.Resource,
        domain: TestDomain,
        validate_domain_inclusion?: false,
        extensions: [Alva.Resource],
        notifiers: [Ash.Notifier.PubSub]

      resource do
        require_primary_key? false
      end

      actions do
        defaults [:read]

        create :create do
          accept []
        end
      end

      pub_sub do
        module TestPubSub

        publish "student_created", :create, "students"
        publish :read, "students_read"
      end

      live_vue do
        event :valid_pubsub_read, name: "valid.pubsub.read", action: :read

        collection :students do
          source event: :valid_pubsub_read, mode: :reset
          insert on: :create
          update on: :read
        end

        signal :students_read,
          name: "students.read",
          on: :read
      end
    end
    """)
  end

  test "fails to compile when action does not exist" do
    stderr =
      capture_io(:stderr, fn ->
        compile_module("""
        defmodule TestResource.MissingAction do
          use Ash.Resource,
            domain: TestDomain,
            validate_domain_inclusion?: false,
            extensions: [Alva.Resource]

          resource do
            require_primary_key? false
          end

          actions do
            defaults [:read]
          end

          live_vue do
            event :missing, name: "missing", action: :missing
          end
        end
        """)
      end)

    assert stderr =~ "Action :missing does not exist"
  end

  test "emits a warning when action returns an empty DTO" do
    import ExUnit.CaptureLog

    log =
      capture_log(fn ->
        compile_module("""
        defmodule TestResource.EmptyDtoAction do
          use Ash.Resource,
            domain: TestDomain,
            validate_domain_inclusion?: false,
            extensions: [Alva.Resource]

          resource do
            require_primary_key? false
          end

          actions do
            read :empty_read do
              # No attributes defined in resource, so returns empty DTO
            end
          end

          live_vue do
            event :empty, name: "empty", action: :empty_read
          end
        end
        """)
      end)

    assert log =~
             "Alva Extension: Event \"empty\" maps to action :empty_read which returns an empty DTO. Vue will receive an empty payload."
  end

  test "fails to compile when action is not public" do
    stderr =
      capture_io(:stderr, fn ->
        compile_module("""
        defmodule TestResource.PrivateAction do
          use Ash.Resource,
            domain: TestDomain,
            validate_domain_inclusion?: false,
            extensions: [Alva.Resource]

          resource do
            require_primary_key? false
          end

          actions do
            read :internal_read do
              public? false
            end
          end

          live_vue do
            event :internal, name: "internal", action: :internal_read
          end
        end
        """)
      end)

    assert stderr =~ "must be public? true"
  end

  test "fails to compile when legacy stream declarations are used" do
    stderr =
      capture_io(:stderr, fn ->
        compile_module("""
        defmodule TestResource.BlankStreamTrigger do
          use Ash.Resource,
            domain: TestDomain,
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
              insert on: ""
            end
          end
        end
        """)
      end)

    assert stderr =~ "Alva stream projections have been removed"
  end

  test "fails to compile when collection source is missing" do
    stderr =
      capture_io(:stderr, fn ->
        compile_module("""
        defmodule TestResource.CollectionMissingSource do
          use Ash.Resource,
            domain: TestDomain,
            validate_domain_inclusion?: false,
            extensions: [Alva.Resource]

          resource do
            require_primary_key? false
          end

          actions do
            defaults [:read]
          end

          live_vue do
            collection :students do
              insert on: :create
            end
          end
        end
        """)
      end)

    assert stderr =~ "Collection :students must declare exactly one source event."
  end

  test "fails to compile when collection source event is not declared" do
    stderr =
      capture_io(:stderr, fn ->
        compile_module("""
        defmodule TestResource.CollectionUnknownSourceEvent do
          use Ash.Resource,
            domain: TestDomain,
            validate_domain_inclusion?: false,
            extensions: [Alva.Resource]

          resource do
            require_primary_key? false
          end

          actions do
            defaults [:read]
          end

          live_vue do
            collection :students do
              source event: :students_list, mode: :reset
            end
          end
        end
        """)
      end)

    assert stderr =~
             "Collection :students source event :students_list must reference a declared live_vue event declaration key."
  end

  test "fails to compile when collection source event uses a browser-facing name" do
    stderr =
      capture_io(:stderr, fn ->
        compile_module("""
        defmodule TestResource.CollectionStringSourceEvent do
          use Ash.Resource,
            domain: TestDomain,
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
              source event: "students.list", mode: :reset
            end
          end
        end
        """)
      end)

    assert stderr =~
             "Collection :students source event must be an event declaration key atom"
  end

  test "fails to compile when collection trigger uses an event declaration key" do
    stderr =
      capture_io(:stderr, fn ->
        compile_module("""
        defmodule TestResource.CollectionEventKeyTrigger do
          use Ash.Resource,
            domain: TestDomain,
            validate_domain_inclusion?: false,
            extensions: [Alva.Resource],
            notifiers: [Ash.Notifier.PubSub]

          resource do
            require_primary_key? false
          end

          actions do
            defaults [:read]

            create :create do
              accept []
            end
          end

          pub_sub do
            module TestPubSub

            publish "student_created", :create, "students"
          end

          live_vue do
            event :students_list, name: "students.list", action: :read

            collection :students do
              source event: :students_list, mode: :reset
              insert on: :students_list
            end
          end
        end
        """)
      end)

    assert stderr =~ "looks like a live_vue event declaration key"
  end

  test "fails to compile when collection operation trigger is blank" do
    stderr =
      capture_io(:stderr, fn ->
        compile_module("""
        defmodule TestResource.BlankCollectionTrigger do
          use Ash.Resource,
            domain: TestDomain,
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
              insert on: ""
            end
          end
        end
        """)
      end)

    assert stderr =~ "Collection projection occurrence key must be a non-empty atom"
  end

  test "fails to compile when signal projection trigger is blank" do
    stderr =
      capture_io(:stderr, fn ->
        compile_module("""
        defmodule TestResource.BlankSignalTrigger do
          use Ash.Resource,
            domain: TestDomain,
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
              name: "students.import_completed",
              on: ""
          end
        end
        """)
      end)

    assert stderr =~ "Signal projection occurrence key must be a non-empty atom"
  end

  test "fails to compile when signal trigger uses a browser-facing event name" do
    stderr =
      capture_io(:stderr, fn ->
        compile_module("""
        defmodule TestResource.SignalBrowserNameTrigger do
          use Ash.Resource,
            domain: TestDomain,
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
              name: "students.import_completed",
              on: "orders.fulfill"
          end
        end
        """)
      end)

    assert stderr =~ "browser-facing live_vue event name"
  end

  test "fails to compile when collection trigger uses a concrete topic string" do
    stderr =
      capture_io(:stderr, fn ->
        compile_module("""
        defmodule TestResource.CollectionTopicTrigger do
          use Ash.Resource,
            domain: TestDomain,
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
              insert on: "students:all"
            end
          end
        end
        """)
      end)

    assert stderr =~ "concrete PubSub topic"
  end

  test "fails to compile when legacy stream declarations are used even with pubsub" do
    stderr =
      capture_io(:stderr, fn ->
        compile_module("""
        defmodule TestResource.UnknownStreamPublication do
          use Ash.Resource,
            domain: TestDomain,
            validate_domain_inclusion?: false,
            extensions: [Alva.Resource],
            notifiers: [Ash.Notifier.PubSub]

          resource do
            require_primary_key? false
          end

          actions do
            defaults [:read]

            create :create do
              accept []
            end
          end

          pub_sub do
            module TestPubSub

            publish "student_created", :create, "students"
          end

          live_vue do
            stream :students do
              insert on: :student_cretaed
            end
          end
        end
        """)
      end)

    assert stderr =~ "Alva stream projections have been removed"
  end

  test "fails to compile when signal trigger does not match a declared pubsub publication" do
    stderr =
      capture_io(:stderr, fn ->
        compile_module("""
        defmodule TestResource.UnknownSignalPublication do
          use Ash.Resource,
            domain: TestDomain,
            validate_domain_inclusion?: false,
            extensions: [Alva.Resource],
            notifiers: [Ash.Notifier.PubSub]

          resource do
            require_primary_key? false
          end

          actions do
            defaults [:read]
          end

          pub_sub do
            module TestPubSub

            publish :read, "students_read"
          end

          live_vue do
            signal :students_import_completed,
              name: "students.import_completed",
              on: :student_import_completed
          end
        end
        """)
      end)

    assert stderr =~ "Signal projection occurrence key"
    assert stderr =~ "does not match a declared Ash PubSub occurrence key"
    assert stderr =~ ":read"
  end

  test "fails to compile when signal trigger uses a raw pubsub event string" do
    stderr =
      capture_io(:stderr, fn ->
        compile_module("""
        defmodule TestResource.SignalRawPubSubTrigger do
          use Ash.Resource,
            domain: TestDomain,
            validate_domain_inclusion?: false,
            extensions: [Alva.Resource],
            notifiers: [Ash.Notifier.PubSub]

          resource do
            require_primary_key? false
          end

          actions do
            defaults [:read]

            create :create do
              accept []
            end
          end

          pub_sub do
            module TestPubSub

            publish "student_created", :create, "students"
          end

          live_vue do
            signal :students_import_completed,
              name: "students.import_completed",
              on: "student_created"
          end
        end
        """)
      end)

    assert stderr =~ "raw PubSub event string"
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
    # Clean up compiled modules if any
    Enum.each(
      [
        TestResource.Valid,
        TestResource.RealtimeValid,
        TestResource.CollectionValid,
        TestResource.SourceOnlyCollection,
        TestResource.PubSubRealtimeValid,
        TestResource.MissingAction,
        TestResource.PrivateAction,
        TestResource.BlankStreamTrigger,
        TestResource.CollectionMissingSource,
        TestResource.CollectionUnknownSourceEvent,
        TestResource.CollectionStringSourceEvent,
        TestResource.CollectionEventKeyTrigger,
        TestResource.BlankCollectionTrigger,
        TestResource.BlankSignalTrigger,
        TestResource.SignalBrowserNameTrigger,
        TestResource.CollectionTopicTrigger,
        TestResource.UnknownStreamPublication,
        TestResource.UnknownSignalPublication,
        TestResource.SignalRawPubSubTrigger
      ],
      fn mod ->
        :code.purge(mod)
        :code.delete(mod)
      end
    )
  end
end
