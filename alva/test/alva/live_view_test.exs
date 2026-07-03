defmodule Alva.LiveViewTest do
  use ExUnit.Case

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :alva
    plug(Plug.Session, store: :cookie, key: "_alva_key", signing_salt: "whatever123")
  end

  defmodule TestResource do
    use Ash.Resource,
      domain: Alva.LiveViewTest.TestDomain,
      validate_domain_inclusion?: false,
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
      create :upload_file do
        argument(:file, Ash.Type.File, allow_nil?: false)
        accept([])
      end
    end

    pub_sub do
      module(Alva.LiveViewTest.Endpoint)

      publish("student_created", :upload_file, "students")
    end

    live_vue do
      event("upload", action: :upload_file)

      stream :students do
        insert(on: "student_created")
      end

      signal("students.created",
        on: "student_created"
      )
    end
  end

  defmodule DummyLive do
    use Phoenix.LiveView
    use Alva.LiveView, domains: [Alva.LiveViewTest.TestDomain]

    def render(assigns) do
      assigns = assign(assigns, :has_file, Map.has_key?(Map.get(assigns, :uploads, %{}), :file))

      ~H"""
      <div id="upload-status"><%= @has_file %></div>
      """
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

    resources do
      resource(TestResource)
    end
  end

  setup_all do
    Application.put_env(:alva, Alva.LiveViewTest.Endpoint,
      secret_key_base: String.duplicate("a", 64),
      live_view: [signing_salt: String.duplicate("a", 16)],
      pubsub_server: Alva.PubSub,
      render_errors: [formats: [html: Phoenix.ErrorView], layout: false]
    )

    start_supervised!(Alva.LiveViewTest.Endpoint)
    :ok
  end

  setup do
    %{conn: Phoenix.ConnTest.build_conn()}
  end

  test "mount configures allow_upload for ash_storage arguments" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}},
      private: %{lifecycle: %Phoenix.LiveView.Lifecycle{}}
    }

    {:cont, socket} = Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, socket)

    assert socket.assigns.uploads != nil
  end

  test "subscribe/3 subscribes to a concrete PubSub topic and records route subscription" do
    start_supervised!({Phoenix.PubSub, name: Alva.LiveViewTest.RoutePubSub})

    socket = base_socket()
    socket = Alva.LiveView.subscribe(socket, "students", pubsub: Alva.LiveViewTest.RoutePubSub)

    assert "students" in Alva.LiveView.route_subscriptions(socket)

    Phoenix.PubSub.broadcast(
      Alva.LiveViewTest.RoutePubSub,
      "students",
      {:route_subscription_seen, self()}
    )

    assert_receive {:route_subscription_seen, _}
  end

  test "activates stream and signal projections by domain-unique name" do
    {:cont, socket} =
      Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, base_socket())

    socket =
      socket
      |> Alva.LiveView.activate_stream(:students)
      |> Alva.LiveView.activate_signal("students.created")

    assert Alva.LiveView.projection_active?(socket, :stream, :students)
    assert Alva.LiveView.projection_active?(socket, :signal, "students.created")
  end

  test "activation state is scoped to the LiveView socket" do
    {:cont, list_socket} =
      Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, base_socket())

    {:cont, notice_socket} =
      Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, base_socket())

    list_socket = Alva.LiveView.activate_stream(list_socket, :students)
    notice_socket = Alva.LiveView.activate_signal(notice_socket, "students.created")

    notification = student_created_notification()

    assert %{streams: [:students], signals: []} =
             Alva.LiveView.active_projections(list_socket, notification)

    assert %{streams: [], signals: ["students.created"]} =
             Alva.LiveView.active_projections(notice_socket, notification)
  end

  test "handle_info ignores inactive Ash.Notifier.Notification projections" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}},
      private: %{
        lifecycle: %Phoenix.LiveView.Lifecycle{},
        live_temp: %{push_events: []}
      }
    }

    {:cont, socket} = Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, socket)

    [%{function: callback}] = socket.private.lifecycle.handle_info

    assert {:cont, ^socket} = callback.(student_created_notification(), socket)
  end

  test "handle_info pushes active Ash.Notifier.Notification projections" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}},
      private: %{
        lifecycle: %Phoenix.LiveView.Lifecycle{},
        live_temp: %{push_events: []}
      }
    }

    {:cont, socket} = Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, socket)
    socket = Alva.LiveView.activate_signal(socket, "students.created")

    [%{function: callback}] = socket.private.lifecycle.handle_info

    notification = student_created_notification()

    {:halt, final_socket} = callback.(notification, socket)

    events_str = inspect(final_socket.private.live_temp.push_events)
    assert events_str =~ "ash_notification"
    assert events_str =~ "upload_file"
    assert events_str =~ "123"
  end

  test "handle_info accepts Phoenix PubSub broadcasts carrying Ash.Notifier.Notification payloads" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}},
      private: %{
        lifecycle: %Phoenix.LiveView.Lifecycle{},
        live_temp: %{push_events: []}
      }
    }

    {:cont, socket} = Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, socket)
    socket = Alva.LiveView.activate_stream(socket, :students)

    [%{function: callback}] = socket.private.lifecycle.handle_info

    broadcast = %Phoenix.Socket.Broadcast{
      topic: "students",
      event: "student_created",
      payload: student_created_notification()
    }

    {:halt, final_socket} = callback.(broadcast, socket)

    events_str = inspect(final_socket.private.live_temp.push_events)
    assert events_str =~ "ash_notification"
    assert events_str =~ "upload_file"
  end

  defp base_socket do
    %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}},
      private: %{lifecycle: %Phoenix.LiveView.Lifecycle{}}
    }
  end

  defp student_created_notification do
    %Ash.Notifier.Notification{
      resource: TestResource,
      action: %{name: :upload_file},
      data: %TestResource{id: "123", name: "test"}
    }
  end
end
