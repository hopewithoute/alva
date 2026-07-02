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
      [TestResource.Valid, TestResource.MissingAction, TestResource.PrivateAction],
      fn mod ->
        :code.purge(mod)
        :code.delete(mod)
      end
    )
  end
end
