defmodule Alva.DispatcherUncoveredTest do
  use ExUnit.Case, async: false

  defmodule ErrorResource do
    use Ash.Resource,
      domain: Alva.DispatcherUncoveredTest.ErrorDomain,
      extensions: [Alva.Resource],
      data_layer: Ash.DataLayer.Ets

    alva do
      event(:test_create_error, name: "test_create", action: :create_err)
      event(:test_update_error, name: "test_update", action: :update_err)
      event(:test_destroy_error, name: "test_destroy", action: :destroy_err)
      event(:test_read_one_error, name: "test_read_one", action: :read_one_err)
      event(:test_read_error, name: "test_read", action: :read_err)
      event(:test_read_lookup_err, name: "test_read_lookup_err", action: :read_err, lookup: :id)
      event(:test_get_empty, name: "test_get_empty", action: :get_empty)
      event(:test_get_error, name: "test_get", action: :get_err)
      event(:test_get_ok, name: "test_get_ok", action: :get_ok)
      event(:test_list_string, name: "test_list_string", action: :test_list_string)
      event(:test_destroy_ok, name: "test_destroy_ok", action: :destroy_ok)
      event(:test_action_error, name: "test_action", action: :action_err)
      event(:test_unsupported, name: "test_unsupported", action: :read)
    end

    actions do
      defaults [:read]

      create :create_err do
        manual fn _, _ -> {:error, "create error"} end
      end

      create :create_ok do
      end

      update :update_err do
        require_atomic? false
        manual fn _, _ -> {:error, "update error"} end
      end

      destroy :destroy_err do
        manual fn _, _ -> {:error, "destroy error"} end
      end

      destroy :destroy_ok do
      end

      read :read_one_err do
        get? true
        argument :id, :uuid, allow_nil?: false

        prepare fn query, _ ->
          Ash.Query.add_error(query, "read_one error")
        end
      end

      read :get_empty do
        get? true
        argument :id, :uuid, allow_nil?: false

        manual fn _, _, _ ->
          {:ok, []}
        end
      end

      read :read_err do
        prepare fn query, _ ->
          Ash.Query.add_error(query, "read error")
        end
      end

      read :get_err do
        get? true
        argument :id, :uuid, allow_nil?: false

        prepare fn query, _ ->
          Ash.Query.add_error(query, "get error")
        end
      end

      read :get_ok do
        get? true
        argument :id, :uuid, allow_nil?: false

        manual fn query, _, _ ->
          {:ok, [%__MODULE__{id: Ash.UUID.generate()}]}
        end
      end

      action :test_list_string, {:array, :string} do
        run fn _, _ -> {:ok, ["string"]} end
      end

      action :action_err do
        run fn _, _ -> {:error, "action error"} end
      end
    end

    attributes do
      uuid_primary_key :id
    end
  end

  defmodule ErrorDomain do
    use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

    resources do
      resource ErrorResource
    end
  end

  setup do
    original = Application.get_env(:alva, :ash_domains, [])
    Application.put_env(:alva, :ash_domains, [Alva.DispatcherUncoveredTest.ErrorDomain])

    try do
      :persistent_term.erase({{Alva.Registry, :registry}, :alva})
    rescue
      _ -> :ok
    end

    on_exit(fn ->
      Application.put_env(:alva, :ash_domains, original)

      try do
        :persistent_term.erase({{Alva.Registry, :registry}, :alva})
      rescue
        _ -> :ok
      end
    end)

    :ok
  end

  test "unwrap param when event name is in payload" do
    assert %{ok: false, error: %{type: "conflict"}} =
             Alva.Dispatcher.dispatch("test_create", %{"test_create" => %{}}, otp_app: :alva)
  end

  test "create outer error" do
    assert %{ok: false, error: %{type: "conflict"}} =
             Alva.Dispatcher.dispatch("test_create", %{}, otp_app: :alva)
  end

  test "update outer error" do
    record = ErrorResource |> Ash.Changeset.for_create(:create_ok) |> Ash.create!()

    assert %{ok: false, error: %{type: "conflict"}} =
             Alva.Dispatcher.dispatch("test_update", %{"id" => record.id}, otp_app: :alva)
  end

  test "update inner error" do
    assert %{ok: false, error: %{type: "not_found"}} =
             Alva.Dispatcher.dispatch("test_update", %{"id" => Ash.UUID.generate()},
               otp_app: :alva
             )
  end

  test "destroy inner error" do
    record = ErrorResource |> Ash.Changeset.for_create(:create_ok) |> Ash.create!()

    assert %{ok: false, error: %{type: "conflict"}} =
             Alva.Dispatcher.dispatch("test_destroy", %{"id" => record.id}, otp_app: :alva)
  end

  test "destroy ok returns record" do
    record = ErrorResource |> Ash.Changeset.for_create(:create_ok) |> Ash.create!()

    assert %{ok: true} =
             Alva.Dispatcher.dispatch("test_destroy_ok", %{"id" => record.id}, otp_app: :alva)
  end

  test "read_one inner error" do
    assert %{ok: false, error: _} =
             Alva.Dispatcher.dispatch("test_read_one", %{"id" => Ash.UUID.generate()},
               otp_app: :alva
             )
  end

  test "read inner error" do
    assert %{ok: false, error: _} = Alva.Dispatcher.dispatch("test_read", %{}, otp_app: :alva)
  end

  test "get returns not found" do
    assert %{ok: false, error: _} =
             Alva.Dispatcher.dispatch("test_get", %{"id" => Ash.UUID.generate()}, otp_app: :alva)
  end

  test "read lookup inner error" do
    assert %{ok: false, error: _} =
             Alva.Dispatcher.dispatch("test_read_lookup_err", %{"id" => Ash.UUID.generate()},
               otp_app: :alva
             )
  end

  test "get empty returns not found" do
    assert %{ok: false, error: %{type: "not_found"}} =
             Alva.Dispatcher.dispatch("test_get_empty", %{"id" => Ash.UUID.generate()},
               otp_app: :alva
             )
  end

  test "get returns ok" do
    assert %{ok: true} =
             Alva.Dispatcher.dispatch("test_get_ok", %{"id" => Ash.UUID.generate()},
               otp_app: :alva
             )
  end

  test "action inner error" do
    assert %{ok: false, error: %{type: "unknown"}} =
             Alva.Dispatcher.dispatch("test_action", %{}, otp_app: :alva)
  end

  test "sort parse input invalid" do
    assert %{ok: false, error: _} =
             Alva.Dispatcher.dispatch("test_read", %{sort: "invalid_format"}, otp_app: :alva)
  end

  test "find_event_in_domains Map.fetch error" do
    assert %{ok: false, error: %{type: "unknown", message: "Unknown event: missing_event"}} =
             Alva.Dispatcher.dispatch("missing_event", %{})
  end

  test "find_event_in_domains missing returns error" do
    assert %{ok: false, error: %{type: "unknown"}} =
             Alva.Dispatcher.dispatch("non_existent_event", %{},
               domains: [Alva.DispatcherUncoveredTest.ErrorDomain]
             )
  end

  test "test_list_string" do
    assert %{ok: true, data: ["string"]} =
             Alva.Dispatcher.dispatch("test_list_string", %{}, otp_app: :alva)
  end
end
