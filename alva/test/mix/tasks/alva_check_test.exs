defmodule Mix.Tasks.Alva.CheckTest do
  use ExUnit.Case

  alias Mix.Tasks.Alva.Check

  setup do
    tmp_dir = "test/tmp/alva_check"
    File.mkdir_p!(tmp_dir)

    Application.put_env(:alva, :ash_domains, [Mix.Tasks.Alva.CheckTest.Domain])
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
      domain: Mix.Tasks.Alva.CheckTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [Alva.Resource]

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
      defaults([:read, :create])
    end

    alva do
      event(:test_create, name: "test.create", action: :create)
    end
  end

  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

    resources do
      resource(Resource)
    end
  end

  test "runs mix alva.check without error", %{tmp_dir: _tmp_dir} do
    assert :ok == Check.run([])
  end
end
