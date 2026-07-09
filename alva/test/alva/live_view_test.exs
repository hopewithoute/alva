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
      extensions: [Alva.Resource],
      validate_domain_inclusion?: false

    attributes do
      uuid_primary_key :id
    end

    actions do
      defaults [:create, :update, :destroy]
    end

    live_vue do
      event(:test_signal_event, name: "test_signal_event", action: :test_signal_action)
      event(:create_event, name: "create_event", action: :create)
      event(:update_event, name: "update_event", action: :update)
      event(:destroy_event, name: "destroy_event", action: :destroy)
      event(:upload_command, name: "upload_command", action: :upload_action)
      event(:unknown_action_command, name: "unknown_action_command", action: :unknown_action)

      subscription :test_stream do
        name "test_stream"
        resolve(:resolve_stream)
        kind :stream

        source event: :create_event
        source event: :update_event
        source event: :destroy_event
        insert(on: :create)
        update on: :update
        delete(on: :destroy)
        authorize_with(:test_authorize_action)
      end

      signal :test_signal do
        name "test_signal"
        on [:create]
        authorize_with(:test_authorize_action)
      end

      subscription(:test_error, name: "test_error", resolve: :resolve_error, kind: :stream)

      subscription(:test_forbidden,
        name: "test_forbidden",
        resolve: :resolve_error,
        kind: :stream
      )
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
    end

    def resolve_stream(_input, _socket) do
      {:ok, %{topics: ["test_stream_topic"], items: [%{id: "1"}]}}
    end

    def resolve_signal(_input, _socket) do
      {:ok, %{topics: [], items: []}}
    end

    def resolve_error(_input, _socket) do
      {:error, %RuntimeError{message: "Some internal error"}}
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
      assigns: %{__changed__: %{}},
      private: %{
        lifecycle: %Phoenix.LiveView.Lifecycle{},
        live_temp: %{}
      }
    }

    %{socket: socket}
  end

  describe "on_mount/4" do
    test "configures alva state and attaches hooks", %{socket: socket} do
      config = %{subscriptions: [:test_error, :unknown_sub], commands: []}
      {:cont, socket} = Alva.LiveView.on_mount(config, %{}, %{}, socket)

      assert %{otp_app: :alva, domains: _} = socket.private.alva

      # Hooks are attached
      assert Enum.any?(socket.private.lifecycle.handle_event, &(&1.id == :alva_handle_event))
      assert Enum.any?(socket.private.lifecycle.handle_info, &(&1.id == :alva_handle_info))
    end

    test "configures file uploads from commands", %{socket: socket} do
      config = %{
        subscriptions: [],
        commands: [:upload_command, :unknown_command, :unknown_action_command]
      }

      {:cont, socket} = Alva.LiveView.on_mount(config, %{}, %{}, socket)

      assert %{uploads: uploads} = socket.assigns
      assert Map.has_key?(uploads, :file)
      assert Map.has_key?(uploads, :files)
    end

    test "activates mount subscriptions", %{socket: socket} do
      config = %{subscriptions: [test_stream: [activate: :mount]]}
      {:cont, socket} = Alva.LiveView.on_mount(config, %{}, %{}, socket)

      # test_stream resolves topics
      assert %{otp_app: :alva} = socket.private.alva
    end
  end

  describe "handle_event hooks" do
    setup %{socket: socket} do
      config = %{subscriptions: [{:test_stream, [some_opt: 1]}, :test_error], commands: []}
      {:cont, socket} = Alva.LiveView.on_mount(config, %{}, %{}, socket)

      # Set user for authorization
      socket = Phoenix.Component.assign(socket, :current_user, "test_actor")

      # Initialize the stream manually for tests since after_render hook is not automatically invoked
      socket = Phoenix.LiveView.stream(socket, :test_stream, [])

      hook = Enum.find(socket.private.lifecycle.handle_event, &(&1.id == :alva_handle_event))
      %{socket: socket, handle_event: hook.function}
    end

    test "alva:activate_subscription", %{socket: socket, handle_event: handle_event} do
      params = %{"name" => "test_stream", "input" => %{}}

      assert {:halt, %{ok: true, data: %{topics: ["test_stream_topic"]}}, socket} =
               handle_event.("alva:activate_subscription", params, socket)

      # Now it should be in active subscriptions
      assert Map.has_key?(socket.private.alva.active_subscription_refs, :test_stream)
    end

    test "alva:deactivate_subscription", %{socket: socket, handle_event: handle_event} do
      # first activate
      {:halt, _, socket} =
        handle_event.("alva:activate_subscription", %{"name" => "test_stream"}, socket)

      # then deactivate
      assert {:halt, %{ok: true}, socket} =
               handle_event.("alva:deactivate_subscription", %{"name" => "test_stream"}, socket)

      assert not Map.has_key?(socket.private.alva.active_subscription_refs, :test_stream)
    end

    test "alva:activate_subscription success", %{socket: socket, handle_event: handle_event} do
      params = %{"name" => "test_stream", "input" => %{}}

      assert {:halt, %{ok: true, data: _}, _socket} =
               handle_event.("alva:activate_subscription", params, socket)
    end

    test "alva:load_more_subscription success", %{socket: socket, handle_event: handle_event} do
      params = %{"name" => "test_stream", "input" => %{}}

      assert {:halt, %{ok: true, data: _}, _socket} =
               handle_event.("alva:load_more_subscription", params, socket)
    end

    test "alva:load_more_subscription failure", %{socket: socket, handle_event: handle_event} do
      params = %{"name" => "unknown_stream", "input" => %{}}

      assert {:halt, %{ok: false, error: %{type: "not_found"}}, _socket} =
               handle_event.("alva:load_more_subscription", params, socket)
    end

    test "alva:load_more_subscription forbidden", %{socket: socket, handle_event: handle_event} do
      params = %{"name" => "test_forbidden", "input" => %{}}

      assert {:halt, %{ok: false, error: %{type: "forbidden"}}, _socket} =
               handle_event.("alva:load_more_subscription", params, socket)
    end

    test "alva:load_more_subscription error", %{socket: socket, handle_event: handle_event} do
      params = %{"name" => "test_error", "input" => %{}}

      assert {:halt, %{ok: false, error: _}, _socket} =
               handle_event.("alva:load_more_subscription", params, socket)
    end

    test "alva:deactivate_subscription success", %{socket: socket, handle_event: handle_event} do
      # First activate
      {:halt, _, socket} =
        handle_event.(
          "alva:activate_subscription",
          %{"name" => "test_stream", "input" => %{}},
          socket
        )

      # Activate again to get count > 1
      {:halt, _, socket} =
        handle_event.(
          "alva:activate_subscription",
          %{"name" => "test_stream", "input" => %{}},
          socket
        )

      # Deactivate once
      assert {:halt, %{ok: true}, socket} =
               handle_event.("alva:deactivate_subscription", %{"name" => "test_stream"}, socket)

      # Deactivate again
      assert {:halt, %{ok: true}, socket} =
               handle_event.("alva:deactivate_subscription", %{"name" => "test_stream"}, socket)

      # Deactivate when missing to hit _ -> refs
      assert {:halt, %{ok: true}, _socket} =
               handle_event.("alva:deactivate_subscription", %{"name" => "test_stream"}, socket)
    end

    test "alva:deactivate_subscription failure", %{socket: socket, handle_event: handle_event} do
      assert {:halt, %{ok: false}, _socket} =
               handle_event.(
                 "alva:deactivate_subscription",
                 %{"name" => "unknown_stream"},
                 socket
               )
    end

    test "alva:subscribe_signal success", %{socket: socket, handle_event: handle_event} do
      params = %{"name" => "test_signal", "input" => %{}}

      assert {:halt, %{ok: true}, socket} =
               handle_event.("alva:subscribe_signal", params, socket)

      assert Map.has_key?(socket.private.alva.active_signal_refs, :test_signal)
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

      assert not Map.has_key?(socket.private.alva.active_signal_refs, :test_signal)
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
      # We need an event that returns something other than unknown error
      # We can just map an event in our TestResource
      assert {:halt, %{ok: true}, _socket} = handle_event.("test_signal_event", %{}, socket)
    end

    test "dispatches to action", %{socket: socket, handle_event: handle_event} do
      assert {:halt, %{ok: true}, _socket} = handle_event.("test_signal_event", %{}, socket)
    end

    test "ignores unknown event", %{socket: socket, handle_event: handle_event} do
      assert {:cont, ^socket} = handle_event.("non_existent_event", %{}, socket)
    end

    test "halts on upload lifecycle events", %{socket: socket, handle_event: handle_event} do
      assert {:halt, ^socket} = handle_event.("alva.validate_upload", %{}, socket)
      assert {:halt, ^socket} = handle_event.("alva.save_upload", %{}, socket)
    end
  end

  describe "handle_info hooks" do
    setup %{socket: socket} do
      config = %{subscriptions: [:test_stream, :test_signal], commands: []}
      {:cont, socket} = Alva.LiveView.on_mount(config, %{}, %{}, socket)

      hook = Enum.find(socket.private.lifecycle.handle_info, &(&1.id == :alva_handle_info))

      # Activate stream manually to prepare socket
      hook_event =
        Enum.find(socket.private.lifecycle.handle_event, &(&1.id == :alva_handle_event))

      {:halt, _, socket} =
        hook_event.function.(
          "alva:activate_subscription",
          %{"name" => "test_stream", "input" => %{}},
          socket
        )

      {:halt, _, socket} =
        hook_event.function.(
          "alva:activate_subscription",
          %{"name" => "test_signal", "input" => %{}},
          socket
        )

      %{socket: socket, handle_info: hook.function}
    end

    test "ignores normal messages", %{socket: socket, handle_info: handle_info} do
      assert {:cont, ^socket} = handle_info.(:normal_message, socket)
    end

    test "processes stream insert notification", %{socket: socket, handle_info: handle_info} do
      notification = %Ash.Notifier.Notification{
        resource: Alva.LiveViewTest.TestResource,
        action: %{type: :create, name: :create},
        data: %Alva.LiveViewTest.TestResource{id: "1"}
      }

      assert {:halt, _socket} = handle_info.(notification, socket)
      # Assert the stream exists and stream_insert ran
      assert Map.has_key?(socket.assigns.streams, :test_stream)
    end

    test "processes stream update notification", %{socket: socket, handle_info: handle_info} do
      notification = %Ash.Notifier.Notification{
        resource: Alva.LiveViewTest.TestResource,
        action: %{type: :update, name: :update},
        data: %Alva.LiveViewTest.TestResource{id: "1"}
      }

      assert {:halt, _socket} = handle_info.(notification, socket)
    end

    test "processes stream delete notification", %{socket: socket, handle_info: handle_info} do
      notification = %Ash.Notifier.Notification{
        resource: Alva.LiveViewTest.TestResource,
        action: %{type: :destroy, name: :destroy},
        data: %Alva.LiveViewTest.TestResource{id: "1"}
      }

      assert {:halt, _socket} = handle_info.(notification, socket)
    end

    test "processes broadcast notification", %{socket: socket, handle_info: handle_info} do
      notification = %Ash.Notifier.Notification{
        resource: Alva.LiveViewTest.TestResource,
        action: %{type: :create, name: :create},
        data: %Alva.LiveViewTest.TestResource{id: "1"}
      }

      broadcast = %Phoenix.Socket.Broadcast{payload: notification}
      assert {:halt, _socket} = handle_info.(broadcast, socket)
    end

    test "ignores notification for other resources", %{socket: socket, handle_info: handle_info} do
      notification = %Ash.Notifier.Notification{
        resource: Alva.LiveViewTest.SomeOtherResource,
        action: %{type: :create, name: :create},
        data: %{id: "1"}
      }

      assert {:cont, ^socket} = handle_info.(notification, socket)
    end
  end
end
