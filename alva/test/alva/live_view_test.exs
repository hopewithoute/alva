defmodule Alva.LiveViewTest do
  use ExUnit.Case

  defmodule MockEndpoint do
    def config(:otp_app), do: :alva
    def config(:pubsub_server), do: Alva.TestPubSub
  end

  defmodule TestResource do
    use Ash.Resource,
      domain: Alva.LiveViewTest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      notifiers: [Ash.Notifier.PubSub],
      authorizers: [Ash.Policy.Authorizer],
      extensions: [Alva.Resource],
      validate_domain_inclusion?: false

    policies do
      policy action(:test_forbidden_action) do
        forbid_if always()
      end

      policy always() do
        authorize_if always()
      end
    end

    attributes do
      uuid_primary_key :id
    end

    actions do
      defaults [:create, :update, :destroy]
    end

    alva do
      event(:test_signal_event, name: "test_signal_event", action: :test_signal_action)
      event(:create_event, name: "create_event", action: :create)
      event(:update_event, name: "update_event", action: :update)
      event(:destroy_event, name: "destroy_event", action: :destroy)
      event(:upload_command, name: "upload_command", action: :upload_action)

      signal :test_signal do
        name "test_signal"
        on :create
        authorize_with(:test_authorize_action)
      end

      signal :test_signal_forbidden do
        name "test_signal_forbidden"
        on :create
        authorize_with(:test_forbidden_action)
      end
    end

    actions do
      defaults [:read, :create, :update, :destroy]

      read :test_stream_action do
        pagination keyset?: true, offset?: true
      end

      action :test_signal_action, :struct do
        run fn _, _ -> {:ok, %{}} end
      end

      action :upload_action, :struct do
        argument :file, Ash.Type.File
        argument :files, {:array, Ash.Type.File}
        argument :text, :string
        run fn _, _ -> {:ok, %{}} end
      end

      action :test_authorize_action, :struct do
        run fn _, _ -> {:ok, %{}} end
      end

      action :test_forbidden_action, :struct do
        run fn _, _ -> {:ok, %{}} end
      end
    end

    def resolve_signal(_input, _socket) do
      {:ok, %{topics: [], items: []}}
    end
  end

  defmodule SomeOtherResource do
    use Ash.Resource,
      domain: Alva.LiveViewTest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false
  end

  defmodule TestDomain do
    use Ash.Domain,
      extensions: [Alva.Domain],
      validate_config_inclusion?: false

    resources do
      resource Alva.LiveViewTest.TestResource
      resource Alva.LiveViewTest.SomeOtherResource
    end
  end

  setup_all do
    start_supervised!({Phoenix.PubSub, name: Alva.TestPubSub})
    Application.put_env(:alva, :ash_domains, [Alva.LiveViewTest.TestDomain])

    on_exit(fn ->
      Application.put_env(:alva, :ash_domains, [])
    end)

    :ok
  end

  setup do
    socket = %Phoenix.LiveView.Socket{
      endpoint: MockEndpoint,
      assigns: %{__changed__: %{}, streams: %{}},
      private: %{
        lifecycle: %Phoenix.LiveView.Lifecycle{},
        live_temp: %{}
      }
    }

    %{socket: socket}
  end

  describe "on_mount/4" do
    test "configures alva state and attaches hooks", %{socket: socket} do
      config = %{uploads: []}
      {:cont, socket} = Alva.LiveView.on_mount(config, %{}, %{}, socket)

      assert %{otp_app: :alva, domains: _} = socket.private.alva

      # Hooks are attached
      assert Enum.any?(socket.private.lifecycle.handle_event, &(&1.id == :alva_handle_event))
      assert Enum.any?(socket.private.lifecycle.handle_info, &(&1.id == :alva_handle_info))
    end

    test "configures file uploads from uploads directive", %{socket: socket} do
      config = %{
        uploads: [:upload_command, :unknown_command, :unknown_action_command]
      }

      {:cont, socket} = Alva.LiveView.on_mount(config, %{}, %{}, socket)

      assert %{uploads: uploads} = socket.assigns
      assert Map.has_key?(uploads, :file)
      assert Map.has_key?(uploads, :files)
    end
  end

  describe "handle_event hooks" do
    setup %{socket: socket} do
      config = %{uploads: []}
      {:cont, socket} = Alva.LiveView.on_mount(config, %{}, %{}, socket)

      # Set user for authorization
      socket = Phoenix.Component.assign(socket, :current_user, "test_actor")

      hook = Enum.find(socket.private.lifecycle.handle_event, &(&1.id == :alva_handle_event))
      %{socket: socket, handle_event: hook.function}
    end

    test "alva:subscribe_signal success", %{socket: socket, handle_event: handle_event} do
      params = %{"name" => "test_signal", "input" => %{}}

      assert {:halt, %{ok: true}, socket} =
               handle_event.("alva:subscribe_signal", params, socket)

      assert active_signal?(socket, :test_signal)
    end

    test "alva:subscribe_signal forbidden", %{socket: socket, handle_event: handle_event} do
      params = %{"name" => "test_signal_forbidden", "input" => %{}}

      assert {:halt, %{ok: false, error: %{type: "forbidden"}}, _socket} =
               handle_event.("alva:subscribe_signal", params, socket)
    end

    test "alva:subscribe_signal not found", %{socket: socket, handle_event: handle_event} do
      params = %{"name" => "unknown_signal", "input" => %{}}

      assert {:halt, %{ok: false, error: %{type: "not_found"}}, _socket} =
               handle_event.("alva:subscribe_signal", params, socket)
    end

    test "alva:unsubscribe_signal success", %{socket: socket, handle_event: handle_event} do
      # First subscribe
      {:halt, _, socket} =
        handle_event.("alva:subscribe_signal", %{"name" => "test_signal", "input" => %{}}, socket)

      # Then unsubscribe
      assert {:halt, %{ok: true}, socket} =
               handle_event.("alva:unsubscribe_signal", %{"name" => "test_signal"}, socket)

      assert not active_signal?(socket, :test_signal)
    end

    test "upload lifecycle events", %{socket: socket, handle_event: handle_event} do
      assert {:halt, _socket} = handle_event.("alva.validate_upload", %{}, socket)
      assert {:halt, _socket} = handle_event.("alva.save_upload", %{}, socket)
    end

    test "dispatches unknown events to Alva.Dispatcher", %{
      socket: socket,
      handle_event: handle_event
    } do
      # Test an event that doesn't exist
      assert {:cont, _socket} = handle_event.("unknown_event", %{}, socket)

      # Test an event that does exist
      assert {:halt, %{ok: true}, _socket} = handle_event.("test_signal_event", %{}, socket)
    end
  end

  describe "handle_info hooks" do
    setup %{socket: socket} do
      config = %{uploads: []}
      {:cont, socket} = Alva.LiveView.on_mount(config, %{}, %{}, socket)

      # Setup mock signals to test sync operations
      socket =
        update_in(
          socket.private.alva,
          &Map.put(&1, :active_signals, %{
            "test_signal" => %{
              resource: Alva.LiveViewTest.TestResource,
              signal: %{name: "test_signal", on: [:create], expose_metadata: []},
              topics: ["test_topic"],
              params: %{}
            }
          })
        )

      hook = Enum.find(socket.private.lifecycle.handle_info, &(&1.id == :alva_handle_info))
      %{socket: socket, handle_info: hook.function}
    end

    test "ignores normal messages", %{socket: socket, handle_info: handle_info} do
      assert {:cont, ^socket} = handle_info.(:normal_message, socket)
    end

    test "ignores notification for other resources", %{socket: socket, handle_info: handle_info} do
      broadcast = %Phoenix.Socket.Broadcast{
        payload: %Ash.Notifier.Notification{
          resource: Alva.LiveViewTest.SomeOtherResource,
          action: %{type: :create, name: :create},
          data: %{id: "1"}
        }
      }

      assert {:cont, ^socket} = handle_info.(broadcast, socket)
    end

    test "processes notification that matches signals", %{
      socket: socket,
      handle_info: handle_info
    } do
      broadcast = %Phoenix.Socket.Broadcast{
        payload: %Ash.Notifier.Notification{
          resource: Alva.LiveViewTest.TestResource,
          action: %{type: :create, name: :create},
          data: %{id: "123"}
        }
      }

      assert {:halt, _result_socket} = handle_info.(broadcast, socket)
    end
  end

  defp active_signal?(socket, key) do
    socket.private.alva
    |> Map.get(:active_signals, %{})
    |> Map.has_key?(to_string(key))
  end
end
