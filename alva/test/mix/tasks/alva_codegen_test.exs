defmodule Mix.Tasks.Alva.CodegenTest do
  use ExUnit.Case

  defmodule Endpoint do
  end

  setup do
    # Create a temporary directory for output
    tmp_dir = "test/tmp/alva_codegen"
    File.mkdir_p!(tmp_dir)

    Application.put_env(:alva, :ash_domains, [Mix.Tasks.Alva.CodegenTest.Domain])
    Application.put_env(:alva, :output_dir, tmp_dir)

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
      Application.delete_env(:alva, :ash_domains)
      Application.delete_env(:alva, :output_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  defmodule Resource do
    use Ash.Resource,
      domain: Mix.Tasks.Alva.CodegenTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [Alva.Resource],
      notifiers: [Ash.Notifier.PubSub]

    ets do
      private?(true)
    end

    resource do
      require_primary_key?(false)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    actions do
      defaults([:read, :create, :update])

      create :upload do
        accept([])
        argument(:media, Ash.Type.File, allow_nil?: false)
      end
    end

    pub_sub do
      module(Mix.Tasks.Alva.CodegenTest.Endpoint)
      prefix("codegen_resource")
      publish(:create, ["created"])
    end

    live_vue do
      event(:test_create, name: "test.create", action: :create)
      event(:test_read, name: "test.read", action: :read)
      event(:test_upload, name: "test.upload", action: :upload)

      subscription :test_stream do
        name("test_stream")
        kind(:stream)
        source(event: :test_read)
        scope(%{
          id: %{type: :uuid, required?: true, allow_nil?: false},
          page: :map,
          cursor: %{type: :string, required?: false, allow_nil?: false},
          customer_query: %{type: :string, required?: false, allow_nil?: true}
        })
        insert(on: :create)
        resolve(:resolve_test_stream_scope)
      end

      subscription :test_signal do
        name("test_signal")
        kind(:signal)
        on(:create)
        scope(%{
          audience: %{type: :string, required?: true, allow_nil?: false},
          tenant_id: %{type: :uuid, required?: false, allow_nil?: true}
        })
        resolve(:resolve_test_signal_scope)
      end
    end

    def resolve_test_stream_scope(_input, _socket) do
      {:ok, %{topics: ["codegen_resource:created"], items: []}}
    end

    def resolve_test_signal_scope(_input, _socket) do
      {:ok, %{topics: ["codegen_resource:created"]}}
    end
  end

  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

    resources do
      resource(Resource)
    end
  end

  test "generates events.ts and client.ts", %{tmp_dir: tmp_dir} do
    Mix.Tasks.Alva.Codegen.run([])

    events_path = Path.join(tmp_dir, "events.ts")
    client_path = Path.join(tmp_dir, "client.ts")
    types_path = Path.join(tmp_dir, "types.ts")
    subscriptions_path = Path.join(tmp_dir, "subscriptions.ts")

    assert File.exists?(events_path)
    assert File.exists?(client_path)
    assert File.exists?(types_path)
    assert File.exists?(subscriptions_path)

    events_content = File.read!(events_path)
    # Verify the structure rather than exact string formatting
    assert String.contains?(events_content, "export type AlvaEvents =")
    assert String.contains?(events_content, "test.create")
    assert String.contains?(events_content, "AlvaResult<Types.Resource>")
    # Verify input shape generation is hooked up (the Resource actions have no arguments in test)
    assert String.contains?(events_content, "input:")
    assert String.contains?(events_content, ~s(media: string;))
    refute String.contains?(events_content, ~s(media: File;))

    types_content = File.read!(types_path)
    assert String.contains?(types_content, "export type AlvaResult")
    assert String.contains?(types_content, "export interface Resource")

    client_content = File.read!(client_path)
    assert String.contains?(client_content, "const base_api = useAlvaApi<AlvaEvents>();")

    assert String.contains?(
             client_content,
             "function create_deep_proxy(path: string[] = []): any {"
           )

    assert String.contains?(client_content, ~s(prop === "call"))
    assert String.contains?(client_content, "return base_api.call;")
    assert String.contains?(client_content, ~s(prop === "on"))
    assert String.contains?(client_content, "return base_api.on;")
    assert String.contains?(client_content, "export const ashCall = createAlvaApi().call;")

    subscriptions_content = File.read!(subscriptions_path)
    assert String.contains?(subscriptions_content, ~s("test_stream"))
    assert String.contains?(subscriptions_content, ~s(kind: "stream"))
    assert String.contains?(subscriptions_content, ~s(id: string;))
    assert String.contains?(subscriptions_content, ~s(page?: Record<string, any> | null;))
    assert String.contains?(subscriptions_content, ~s(cursor?: string;))
    assert String.contains?(subscriptions_content, ~s(customer_query?: string | null;))
    assert String.contains?(subscriptions_content, ~s(item: Types.Resource;))
    assert String.contains?(subscriptions_content, ~s("test_signal"))
    assert String.contains?(subscriptions_content, ~s(kind: "signal"))
    assert String.contains?(subscriptions_content, ~s(audience: string;))
    assert String.contains?(subscriptions_content, ~s(tenant_id?: string | null;))
    assert String.contains?(subscriptions_content, ~s(payload: Types.Resource;))
  end
end
