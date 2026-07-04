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
      read :read do
        primary?(true)
        pagination(offset?: true, required?: false)
      end

      create :upload_file do
        argument(:file, Ash.Type.File, allow_nil?: false)
        accept([])
      end

      create :create do
        accept([:name])
      end

      update :rename do
        accept([:name])
      end

      destroy(:destroy)
    end

    pub_sub do
      module(Alva.LiveViewTest.Endpoint)

      publish("student_created", :upload_file, "students")
      publish("student_updated", :rename, "students")
      publish("student_deleted", :destroy, "students")
    end

    live_vue do
      event("upload", action: :upload_file)
      event("students.list", action: :read)

      stream :students do
        insert(on: "student_created")
        update(on: "student_updated")
        delete(on: "student_deleted")
      end

      collection :sales_orders do
        source(event: "students.list", mode: :reset)
        insert(on: "student_created")
        update(on: "student_updated")
        delete(on: "student_deleted")
      end

      signal("students.created",
        on: "student_created",
        expose_metadata: [:sync_token]
      )
    end
  end

  defmodule OtherResource do
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
      create :create do
        accept([])
      end
    end

    pub_sub do
      module(Alva.LiveViewTest.Endpoint)

      publish("student_created", :create, "other_students")
    end

    live_vue do
      stream :other_students do
        insert(on: "student_created")
      end

      signal("other_students.created",
        on: "student_created"
      )
    end
  end

  defmodule JobResource do
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

    actions do
      create :complete do
        accept([])
      end
    end

    pub_sub do
      module(Alva.LiveViewTest.Endpoint)

      publish("job_completed", :complete, "jobs")
    end

    live_vue do
      signal("jobs.completed",
        on: "job_completed"
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

  defmodule CollectionLive do
    use Phoenix.LiveView
    use Alva.LiveView, domains: [Alva.LiveViewTest.TestDomain], collections: [:sales_orders]

    def render(assigns) do
      ~H"""
      <div id="sales-orders">
        <div :for={{dom_id, order} <- @streams.sales_orders} id={dom_id}>
          <%= order.name %>
        </div>
      </div>
      """
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

    resources do
      resource(TestResource)
      resource(OtherResource)
      resource(JobResource)
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

  test "activates collection manually by dispatching its source event into a LiveView stream" do
    create_student!("Manual Collection A")

    {:cont, socket} =
      Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, base_socket())

    socket = Alva.LiveView.collection(socket, :sales_orders)

    assert Alva.LiveView.projection_active?(socket, :collection, :sales_orders)
    assert [%{name: "Manual Collection A"}] = stream_items(socket, :sales_orders)
    refute Map.has_key?(socket.assigns, :sales_orders)
  end

  test "declarative collections activate only allowlisted collection names" do
    create_student!("Declarative Collection A")

    {:cont, socket} =
      Alva.LiveView.on_mount(
        {[Alva.LiveViewTest.TestDomain], [:sales_orders]},
        %{},
        %{},
        base_socket()
      )

    assert Alva.LiveView.projection_active?(socket, :collection, :sales_orders)
    assert [%{name: "Declarative Collection A"}] = stream_items(socket, :sales_orders)
    refute Alva.LiveView.projection_active?(socket, :stream, :students)
  end

  test "mounting a domain does not activate collections by default" do
    create_student!("Inactive Collection A")

    {:cont, socket} =
      Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, base_socket())

    refute Alva.LiveView.projection_active?(socket, :collection, :sales_orders)
    refute Map.has_key?(socket.assigns, :streams)
  end

  test "unknown collection activation fails with an actionable error" do
    {:cont, socket} =
      Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, base_socket())

    assert_raise ArgumentError,
                 ~r/Unknown Alva collection projection :missing_orders/,
                 fn -> Alva.LiveView.collection(socket, :missing_orders) end
  end

  test "render can pass an activated collection from @streams into markup" do
    create_student!("Rendered Collection A")

    {:cont, socket} =
      Alva.LiveView.on_mount(
        {[Alva.LiveViewTest.TestDomain], [:sales_orders]},
        %{},
        %{},
        base_socket()
      )

    assert Phoenix.LiveViewTest.rendered_to_string(CollectionLive.render(socket.assigns)) =~
             "Rendered Collection A"
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

  test "active projections only match notifications from the projection resource" do
    {:cont, socket} =
      Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, base_socket())

    socket =
      socket
      |> Alva.LiveView.activate_stream(:other_students)
      |> Alva.LiveView.activate_signal("other_students.created")

    assert %{streams: [], signals: []} =
             Alva.LiveView.active_projections(socket, student_created_notification())
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

  test "handle_info pushes active signal notifications with semantic event names" do
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

    assert [["students.created", %{id: "123", name: "test"}]] =
             final_socket.private.live_temp.push_events

    refute inspect(final_socket.private.live_temp.push_events) =~ "ash_notification"
    refute inspect(final_socket.private.live_temp.push_events) =~ "__metadata__"
  end

  test "signal payload exposes opted metadata under meta without leaking raw Ash internals" do
    socket =
      %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}},
        private: %{
          lifecycle: %Phoenix.LiveView.Lifecycle{},
          live_temp: %{push_events: []}
        }
      }
      |> then(fn socket ->
        {:cont, socket} = Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, socket)
        socket
      end)
      |> Alva.LiveView.activate_signal("students.created")

    [%{function: callback}] = socket.private.lifecycle.handle_info

    {:halt, final_socket} = callback.(student_created_notification_with_metadata(), socket)

    assert [["students.created", %{id: "123", name: "test", meta: %{sync_token: "tok_123"}}]] =
             final_socket.private.live_temp.push_events

    refute inspect(final_socket.private.live_temp.push_events) =~ "__metadata__"
  end

  test "signal delivery wraps nil payloads for async completion callbacks" do
    final_socket = push_job_signal(nil)

    assert [["jobs.completed", %{}]] = final_socket.private.live_temp.push_events
  end

  test "signal delivery wraps scalar payloads before pushing to LiveView" do
    final_socket = push_job_signal("done")

    assert [["jobs.completed", %{data: "done"}]] = final_socket.private.live_temp.push_events
  end

  test "signal delivery wraps list payloads before pushing to LiveView" do
    final_socket = push_job_signal([%{id: "a"}, %{id: "b"}])

    assert [["jobs.completed", %{data: [%{id: "a"}, %{id: "b"}]}]] =
             final_socket.private.live_temp.push_events
  end

  test "stream query appends command read results into an active route collection" do
    first = create_student!("Append A")
    second = create_student!("Append B")

    socket =
      active_stream_socket()
      |> Alva.LiveView.bind_stream_query("students.list", :students, mode: :append)

    [%{function: callback}] = socket.private.lifecycle.handle_event

    {:halt, reply, final_socket} =
      callback.(student_list_event(), %{"page" => %{"limit" => 2, "offset" => 0}}, socket)

    assert reply.ok == true
    assert reply.meta.pagination.limit == 2
    assert reply.meta.pagination.offset == 0

    inserted_ids = Enum.map(final_socket.assigns.students, & &1.id)
    assert first.id in inserted_ids
    assert second.id in inserted_ids
  end

  test "stream query prepends command read results into an active route collection" do
    create_student!("Prepend A")

    socket =
      active_stream_socket()
      |> Alva.LiveView.bind_stream_query("students.list", :students, mode: :prepend)

    [%{function: callback}] = socket.private.lifecycle.handle_event

    {:halt, reply, final_socket} =
      callback.(student_list_event(), %{"page" => %{"limit" => 1, "offset" => 0}}, socket)

    assert reply.ok == true
    assert [%{}] = final_socket.assigns.students
  end

  test "stream query passes collection limits to Phoenix stream operations" do
    create_student!("Limit A")

    socket =
      active_stream_socket()
      |> Alva.LiveView.bind_stream_query("students.list", :students, mode: :append, limit: -10)

    [%{function: callback}] = socket.private.lifecycle.handle_event

    {:halt, reply, final_socket} =
      callback.(student_list_event(), %{"page" => %{"limit" => 1, "offset" => 0}}, socket)

    assert reply.ok == true
    assert [%{}] = final_socket.assigns.students
  end

  test "stream query resets an active route collection for refresh flows" do
    create_student!("Refresh A")

    socket =
      active_stream_socket()
      |> Alva.LiveView.bind_stream_query("students.list", :students, mode: :reset)

    [%{function: callback}] = socket.private.lifecycle.handle_event

    {:halt, reply, final_socket} =
      callback.(student_list_event(), %{"page" => %{"limit" => 1, "offset" => 0}}, socket)

    assert reply.ok == true
    assert [%{name: "Refresh A"}] = final_socket.assigns.students
  end

  test "unbound command read results behave as normal replies without stream mutation" do
    create_student!("Unbound A")

    socket = active_stream_socket()
    [%{function: callback}] = socket.private.lifecycle.handle_event

    {:halt, reply, final_socket} =
      callback.(student_list_event(), %{"page" => %{"limit" => 1, "offset" => 0}}, socket)

    assert reply.ok == true
    assert final_socket.assigns.students == []
  end

  test "signal-only delivery does not mutate a route collection" do
    socket =
      %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}},
        private: %{
          lifecycle: %Phoenix.LiveView.Lifecycle{},
          live_temp: %{push_events: []}
        }
      }
      |> then(fn socket ->
        {:cont, socket} = Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, socket)
        socket
      end)
      |> Phoenix.Component.assign(:students, [])
      |> Alva.LiveView.activate_signal("students.created")

    [%{function: callback}] = socket.private.lifecycle.handle_info

    {:halt, final_socket} = callback.(student_created_notification(), socket)

    assert [["students.created", %{id: "123", name: "test"}]] =
             final_socket.private.live_temp.push_events

    assert final_socket.assigns.students == []
  end

  test "the same occurrence can update a stream and push a signal when both are active" do
    socket =
      active_stream_socket()
      |> Alva.LiveView.activate_signal("students.created")

    [%{function: callback}] = socket.private.lifecycle.handle_info

    {:halt, final_socket} = callback.(student_created_notification(), socket)

    assert [["students.created", %{id: "123", name: "test"}]] =
             final_socket.private.live_temp.push_events

    assert [%{id: "123", name: "test"}] =
             final_socket.assigns.students
  end

  test "handle_info inserts matching active stream notifications into the route collection" do
    {:halt, final_socket} =
      stream_callback().(student_created_notification(), active_stream_socket())

    assert [%{id: "123", name: "test"}] =
             final_socket.assigns.students
  end

  test "handle_info updates matching active stream notifications through stream_insert" do
    {:halt, final_socket} =
      stream_callback().(student_updated_notification(), active_stream_socket())

    assert [%{id: "123", name: "renamed"}] =
             final_socket.assigns.students
  end

  test "handle_info deletes matching active stream notifications from the route collection" do
    {:halt, final_socket} =
      stream_callback().(student_deleted_notification(), active_stream_socket())

    assert final_socket.assigns.students == []
  end

  test "two activated pages receive the same collection update through the stream path" do
    callback = stream_callback()
    page_one = active_stream_socket()
    page_two = active_stream_socket()
    notification = student_created_notification()

    {:halt, page_one} = callback.(notification, page_one)
    {:halt, page_two} = callback.(notification, page_two)

    assert [%{id: "123", name: "test"}] =
             page_one.assigns.students

    assert [%{id: "123", name: "test"}] =
             page_two.assigns.students
  end

  test "handle_info accepts Phoenix PubSub broadcasts carrying Ash.Notifier.Notification payloads" do
    socket = active_stream_socket()
    [%{function: callback}] = socket.private.lifecycle.handle_info

    broadcast = %Phoenix.Socket.Broadcast{
      topic: "students",
      event: "student_created",
      payload: student_created_notification()
    }

    {:halt, final_socket} = callback.(broadcast, socket)

    assert [%{id: "123", name: "test"}] =
             final_socket.assigns.students
  end

  defp base_socket do
    %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}},
      private: %{lifecycle: %Phoenix.LiveView.Lifecycle{}}
    }
  end

  defp active_stream_socket do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        [Alva.LiveViewTest.TestDomain],
        %{},
        %{},
        %Phoenix.LiveView.Socket{
          assigns: %{__changed__: %{}},
          private: %{
            lifecycle: %Phoenix.LiveView.Lifecycle{},
            live_temp: %{push_events: []}
          }
        }
      )

    socket
    |> Phoenix.Component.assign(:students, [])
    |> Alva.LiveView.activate_stream(:students)
  end

  defp stream_callback do
    socket = active_stream_socket()
    [%{function: callback}] = socket.private.lifecycle.handle_info
    callback
  end

  defp stream_items(socket, name) do
    socket.assigns.streams
    |> Map.fetch!(name)
    |> Map.fetch!(:inserts)
    |> Enum.map(fn {_dom_id, _at, item, _limit, _update_only} -> item end)
  end

  defp push_job_signal(data) do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}},
      private: %{
        lifecycle: %Phoenix.LiveView.Lifecycle{},
        live_temp: %{push_events: []}
      }
    }

    {:cont, socket} = Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, socket)
    socket = Alva.LiveView.activate_signal(socket, "jobs.completed")

    [%{function: callback}] = socket.private.lifecycle.handle_info

    {:halt, final_socket} =
      callback.(
        %Ash.Notifier.Notification{
          resource: JobResource,
          action: %{name: :complete},
          data: data
        },
        socket
      )

    final_socket
  end

  defp create_student!(name) do
    Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: name}))
  end

  defp student_list_event do
    "students.list"
  end

  defp student_created_notification do
    %Ash.Notifier.Notification{
      resource: TestResource,
      action: %{name: :upload_file},
      data: %{id: "123", name: "test"}
    }
  end

  defp student_created_notification_with_metadata do
    %Ash.Notifier.Notification{
      resource: TestResource,
      action: %{name: :upload_file},
      data: %{
        id: "123",
        name: "test",
        __metadata__: %{sync_token: "tok_123", hidden: "nope"}
      }
    }
  end

  defp student_updated_notification do
    %Ash.Notifier.Notification{
      resource: TestResource,
      action: %{name: :rename},
      data: %{id: "123", name: "renamed"}
    }
  end

  defp student_deleted_notification do
    %Ash.Notifier.Notification{
      resource: TestResource,
      action: %{name: :destroy},
      data: %{id: "123", name: "test"}
    }
  end
end
