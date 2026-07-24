defmodule Alva.RegistryTest do
  use ExUnit.Case, async: false

  alias Alva.Registry

  defmodule TestResource do
    use Ash.Resource,
      domain: nil,
      extensions: [Alva.Resource],
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    alva do
      event(:test_event, name: "my_event", action: :read)
      signal(:test_signal, name: "dup_signal", authorize_with: :read, on: ["updated"])
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

    alva do
      event(:test_event_dup, name: "my_event", action: :read)
      signal(:test_signal_dup, name: "dup_signal", authorize_with: :read, on: ["updated"])
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

    assert Registry.file_upload_arguments(EmptyDomain) == []
  end

  test "events and public fields for resource" do
    events = Registry.events(TestResource)
    assert [_] = events

    assert Registry.public_fields(TestResource) == [:id]
  end

  defmodule SingleResource do
    use Ash.Resource,
      domain: nil,
      extensions: [Alva.Resource],
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    alva do
      event(:get_item, name: "item.get", action: :read)
      signal(:on_item_updated, name: "item.updated", authorize_with: :read, on: ["updated"])
    end

    actions do
      defaults [:read]
    end

    attributes do
      uuid_primary_key :id
    end
  end

  defmodule SingleDomain do
    use Ash.Domain, extensions: [Alva.Domain], validate_config_inclusion?: false

    resources do
      resource Alva.RegistryTest.SingleResource
    end
  end

  defmodule EndpointWithOtpApp do
    def otp_app, do: :alva
  end

  defmodule EndpointWithConfig do
    def config(:otp_app), do: :alva
  end

  defmodule EndpointWithConfigError do
    def config(:otp_app), do: raise(ArgumentError, "no config")
  end

  test "fetch_event and fetch_signal work on valid registry" do
    Application.put_env(:alva, :ash_domains, [SingleDomain])
    :persistent_term.erase({{Alva.Registry, :registry}, :alva})

    reg = Registry.registry(:alva)
    assert reg.otp_app == :alva
    assert reg.domains == [SingleDomain]

    assert {:ok, SingleResource, %Alva.Resource.Event{name: "item.get"}} =
             Registry.fetch_event(:alva, "item.get")

    assert Registry.fetch_event(:alva, "nonexistent") == :error

    assert {:ok, SingleResource, %Alva.Resource.Signal{name: "item.updated"}} =
             Registry.fetch_signal(:alva, "item.updated")

    assert Registry.fetch_signal(:alva, "nonexistent") == :error

    assert Registry.signals(SingleResource) |> length() == 1
  end

  test "verify_host_app_signal_uniqueness! throws error on duplicate signals" do
    signal_map = Registry.alva_signal_map(TestDomainDup)

    assert_raise Spark.Error.DslError, ~r/Duplicate application signal name/, fn ->
      Registry.verify_host_app_signal_uniqueness!(TestDomainDup, signal_map)
    end
  end

  test "otp_app/1 handles endpoint structures" do
    assert Registry.otp_app(EndpointWithOtpApp) == :alva
    assert Registry.otp_app(EndpointWithConfig) == :alva
    assert Registry.otp_app(EndpointWithConfigError) == nil
    assert Registry.otp_app(%{endpoint: EndpointWithOtpApp}) == :alva
  end

  defmodule FileUploadRes1 do
    use Ash.Resource,
      domain: nil,
      extensions: [Alva.Resource],
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    resource do
      require_primary_key?(false)
    end

    alva do
      event(:upload, name: "upload.file1", action: :create)
    end

    actions do
      create :create do
        public?(true)
        argument :file, Ash.Type.File
      end
    end
  end

  defmodule FileUploadRes2 do
    use Ash.Resource,
      domain: nil,
      extensions: [Alva.Resource],
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    resource do
      require_primary_key?(false)
    end

    alva do
      event(:upload2, name: "upload.file2", action: :create)
    end

    actions do
      create :create do
        public?(true)
        argument :file, {:array, Ash.Type.File}
      end
    end
  end

  defmodule FileDomain1 do
    use Ash.Domain, extensions: [Alva.Domain], validate_config_inclusion?: false

    resources do
      resource Alva.RegistryTest.FileUploadRes1
    end
  end

  defmodule FileDomain2 do
    use Ash.Domain, extensions: [Alva.Domain], validate_config_inclusion?: false

    resources do
      resource Alva.RegistryTest.FileUploadRes2
    end
  end

  test "file_upload_arguments detects conflicting arguments" do
    Application.put_env(:alva, :ash_domains, [FileDomain1, FileDomain2])
    :persistent_term.erase({{Alva.Registry, :registry}, :alva})

    assert_raise ArgumentError, ~r/Conflicting file upload arguments found/, fn ->
      Registry.registry(:alva)
    end
  end
end
