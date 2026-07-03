defmodule Mix.Tasks.Alva.CodegenTest do
  use ExUnit.Case
  
  setup do
    # Create a temporary directory for output
    tmp_dir = "test/tmp/alva_codegen"
    File.mkdir_p!(tmp_dir)
    
    # Configure dummy domains for the test
    Application.put_env(:alva, :domains, [Mix.Tasks.Alva.CodegenTest.Domain])
    Application.put_env(:alva, :ash_domains, [Mix.Tasks.Alva.CodegenTest.Domain])
    Application.put_env(:alva, :output_dir, tmp_dir)
    
    on_exit(fn ->
      File.rm_rf!(tmp_dir)
      Application.delete_env(:alva, :domains)
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
      require_primary_key? false
    end

    actions do
      defaults [:read, :create, :update]
    end

    live_vue do
      event "test.create", action: :create
      event "test.read", action: :read
    end
  end

  defmodule Domain do
    use Ash.Domain, extensions: [Alva.Domain]
    resources do
      resource Resource
    end
  end

  test "generates events.ts and client.ts", %{tmp_dir: tmp_dir} do
    Mix.Tasks.Alva.Codegen.run([])
    
    events_path = Path.join(tmp_dir, "events.ts")
    client_path = Path.join(tmp_dir, "client.ts")
    
    assert File.exists?(events_path)
    assert File.exists?(client_path)
    
    events_content = File.read!(events_path)
    # Verify the structure rather than exact string formatting
    assert String.contains?(events_content, "export type AlvaEvents =")
    assert String.contains?(events_content, "test.create")
    assert String.contains?(events_content, "test.read")
    
    client_content = File.read!(client_path)
    assert String.contains?(client_content, "import type { AlvaEvents } from \"./events\"")
    assert String.contains?(client_content, "use_alva_api")
  end
end
