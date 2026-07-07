defmodule Mix.Tasks.Alva.CodegenTest do
  use ExUnit.Case

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
      extensions: [Alva.Resource]

    resource do
      require_primary_key?(false)
    end

    actions do
      defaults([:read, :create, :update])

      create :upload do
        accept([])
        argument(:media, Ash.Type.File, allow_nil?: false)
      end
    end

    live_vue do
      event(:test_create, name: "test.create", action: :create)
      event(:test_read, name: "test.read", action: :read)
      event(:test_upload, name: "test.upload", action: :upload)
    end
  end

  defmodule Domain do
    use Ash.Domain, extensions: [Alva.Domain]

    resources do
      resource(Resource)
    end
  end

  test "generates events.ts and client.ts", %{tmp_dir: tmp_dir} do
    Mix.Tasks.Alva.Codegen.run([])

    events_path = Path.join(tmp_dir, "events.ts")
    client_path = Path.join(tmp_dir, "client.ts")

    types_path = Path.join(tmp_dir, "types.ts")
    assert File.exists?(events_path)
    assert File.exists?(client_path)
    assert File.exists?(types_path)

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
  end
end
