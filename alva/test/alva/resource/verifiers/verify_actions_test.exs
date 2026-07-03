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
        event "valid.read", action: :read
        event "valid.create", action: :create
      end
    end
    """)
  end

  test "compiles successfully with stream and signal projections" do
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
        event "valid.realtime.read", action: :read

        stream :students do
          insert on: "student_created"
          update on: "student_updated"
          delete on: "student_deleted"
        end

        signal "students.import_completed",
          on: "student_import_completed"
      end
    end
    """)

    assert [%Alva.Resource.Stream{name: :students}] =
             Alva.Resource.Info.streams(TestResource.RealtimeValid)

    assert [%Alva.Resource.Signal{name: "students.import_completed"}] =
             Alva.Resource.Info.signals(TestResource.RealtimeValid)
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
        event "valid.pubsub.read", action: :read

        stream :students do
          insert on: "student_created"
          update on: "read"
        end

        signal "students.read",
          on: "read"
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
            event "missing", action: :missing
          end
        end
        """)
      end)

    assert stderr =~ "Action :missing does not exist"
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
            event "internal", action: :internal_read
          end
        end
        """)
      end)

    assert stderr =~ "must be public? true"
  end

  test "fails to compile when stream projection trigger is blank" do
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

    assert stderr =~ "Stream projection trigger must be a non-empty string"
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
            signal "students.import_completed",
              on: ""
          end
        end
        """)
      end)

    assert stderr =~ "Signal projection trigger must be a non-empty string"
  end

  test "fails to compile when stream trigger does not match a declared pubsub publication" do
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
              insert on: "student_cretaed"
            end
          end
        end
        """)
      end)

    assert stderr =~ "Stream projection trigger"
    assert stderr =~ "does not match a declared Ash PubSub publication"
    assert stderr =~ "student_created"
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
            signal "students.import_completed",
              on: "student_import_completed"
          end
        end
        """)
      end)

    assert stderr =~ "Signal projection trigger"
    assert stderr =~ "does not match a declared Ash PubSub publication"
    assert stderr =~ "read"
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
        TestResource.PubSubRealtimeValid,
        TestResource.MissingAction,
        TestResource.PrivateAction,
        TestResource.BlankStreamTrigger,
        TestResource.BlankSignalTrigger,
        TestResource.UnknownStreamPublication,
        TestResource.UnknownSignalPublication
      ],
      fn mod ->
        :code.purge(mod)
        :code.delete(mod)
      end
    )
  end
end
