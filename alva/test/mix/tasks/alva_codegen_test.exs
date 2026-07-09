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

      signal :test_signal do
        name("test_signal")
        on(:create)
        authorize_with(:read)
      end
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

  test "generates events.ts, composables, and index.ts", %{tmp_dir: tmp_dir} do
    Mix.Tasks.Alva.Codegen.run([])

    events_path = Path.join(tmp_dir, "events.ts")
    composables_dir = Path.join(tmp_dir, "composables")
    use_alva_api_path = Path.join(composables_dir, "useAlvaApi.ts")
    use_alva_form_path = Path.join(composables_dir, "useAlvaForm.ts")
    use_alva_upload_path = Path.join(composables_dir, "useAlvaUpload.ts")
    index_path = Path.join(tmp_dir, "index.ts")
    types_path = Path.join(tmp_dir, "types.ts")
    signals_path = Path.join(tmp_dir, "signals.ts")

    assert File.exists?(events_path)
    assert File.exists?(use_alva_api_path)
    assert File.exists?(use_alva_form_path)
    assert File.exists?(use_alva_upload_path)
    assert File.exists?(index_path)
    assert File.exists?(types_path)
    assert File.exists?(signals_path)

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

    use_alva_api_content = File.read!(use_alva_api_path)
    assert String.contains?(use_alva_api_content, "import { useLiveVue } from \"live_vue\"")
    assert String.contains?(use_alva_api_content, "import type { AlvaEvents } from \"../events\"")
    assert String.contains?(use_alva_api_content, ~s("test.create"))
    assert String.contains?(use_alva_api_content, "live.pushEvent")

    index_content = File.read!(index_path)

    assert String.contains?(
             index_content,
             "export { useAlvaApi } from \"./composables/useAlvaApi\""
           )

    assert String.contains?(index_content, "export type { AlvaEvents } from \"./events\"")

    signals_content = File.read!(signals_path)
    assert String.contains?(signals_content, ~s("test_signal"))
    assert String.contains?(signals_content, ~s(payload: Types.Resource;))

    ash_path = Path.join(composables_dir, "ash.ts")
    assert File.exists?(ash_path)

    ash_content = File.read!(ash_path)
    assert String.contains?(ash_content, "import { onUnmounted } from \"vue\"")
    assert String.contains?(ash_content, "import { useLiveVue, useLiveEvent } from \"live_vue\"")
    assert String.contains?(ash_content, "import type { AlvaSignals } from \"../signals\"")
    assert String.contains?(ash_content, "name: K,")
    assert String.contains?(ash_content, ~s(alva:subscribe_signal))
    assert String.contains?(ash_content, ~s(alva:unsubscribe_signal))

    use_alva_form_content = File.read!(use_alva_form_path)
    assert String.contains?(use_alva_form_content, "import { reactive } from \"vue\"")
    assert String.contains?(use_alva_form_content, "import { useLiveForm")

    assert String.contains?(
             use_alva_form_content,
             "import type { AlvaEvents } from \"../events\""
           )

    assert String.contains?(use_alva_form_content, "export function useAlvaForm")
    assert String.contains?(use_alva_form_content, "submitEvent: K,")

    use_alva_upload_content = File.read!(use_alva_upload_path)

    assert String.contains?(
             use_alva_upload_content,
             "import { computed, ref, watch } from \"vue\""
           )

    assert String.contains?(
             use_alva_upload_content,
             "import { useLiveUpload, useLiveVue } from \"live_vue\""
           )

    assert String.contains?(use_alva_upload_content, "export function useAlvaUpload")
  end
end
