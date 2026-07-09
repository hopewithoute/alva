defmodule Alva.RegistryTest do
  use ExUnit.Case, async: false

  alias Alva.Registry

  defmodule TestResource do
    use Ash.Resource,
      domain: nil,
      extensions: [Alva.Resource],
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    live_vue do
      event(:test_event, name: "my_event", action: :read)
    end

    actions do
      defaults [:read]
    end

    attributes do
      uuid_primary_key :id
    end
  end

  defmodule TestResourceDup do
    use Ash.Resource,
      domain: nil,
      extensions: [Alva.Resource],
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    live_vue do
      event(:test_event_dup, name: "my_event", action: :read)
    end

    actions do
      defaults [:read]
    end

    attributes do
      uuid_primary_key :id
    end
  end

  defmodule TestDomain do
    use Ash.Domain, extensions: [Alva.Domain], validate_config_inclusion?: false

    resources do
      resource Alva.RegistryTest.TestResource
    end
  end

  defmodule TestDomainDup do
    use Ash.Domain, extensions: [Alva.Domain], validate_config_inclusion?: false

    resources do
      resource Alva.RegistryTest.TestResourceDup
    end
  end

  setup do
    old_domains = Application.get_env(:alva, :ash_domains, [])
    Application.put_env(:alva, :ash_domains, [TestDomain, TestDomainDup])

    :persistent_term.erase({Alva.Registry, :registry})
    :persistent_term.erase({{Alva.Registry, :registry}, :alva})

    on_exit(fn ->
      Application.put_env(:alva, :ash_domains, old_domains)
    end)

    :ok
  end

  test "registry/1 throws error due to duplicate event across domains" do
    assert_raise ArgumentError, ~r/Duplicate application event name/, fn ->
      Registry.registry(:alva)
    end
  end

  test "verify_host_app_command_uniqueness! throws error when called on compilation" do
    # During compilation of TestDomainDup, current entries has duplicates with TestDomain
    current_entries = Registry.alva_event_map(TestDomainDup)

    assert_raise Spark.Error.DslError, ~r/Duplicate application event name/, fn ->
      Registry.verify_host_app_command_uniqueness!(TestDomainDup, current_entries)
    end
  end

  test "otp_app/1 handles various inputs" do
    assert Registry.otp_app(FakeMissingModuleApp) == nil
    assert Registry.otp_app(nil) == nil
    assert Registry.otp_app("invalid") == nil
  end

  test "alva_event_map and others return defaults for empty domain" do
    defmodule EmptyDomain do
      use Ash.Domain, validate_config_inclusion?: false
    end

    assert Registry.alva_event_map(EmptyDomain) == %{}
    assert Registry.alva_event_key_map(EmptyDomain) == %{}
    assert Registry.file_upload_arguments(EmptyDomain) == []
  end

  test "events and public fields for resource" do
    events = Registry.events(TestResource)
    assert length(events) == 1

    assert Registry.public_fields(TestResource) == [:id]
  end
end
