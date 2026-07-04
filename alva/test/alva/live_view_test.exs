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

      action :custom_envelope, :map do
        run(fn _input, _context ->
          {:ok, %{records: [%{id: Ash.UUID.generate(), name: "Envelope A"}], total: 1}}
        end)
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
      publish("student_created", :create, "students")
      publish("student_updated", :rename, "students")
      publish("student_deleted", :destroy, "students")
    end

    live_vue do
      event("upload", action: :upload_file)
      event("students.list", action: :read)
      event("students.custom_envelope", action: :custom_envelope)
      event("students.create", action: :create)
      event("students.rename", action: :rename)
      event("students.destroy", action: :destroy)

      stream :students do
        insert(on: "student_created")
        update(on: "student_updated")
        delete(on: "student_deleted")
      end

      collection :sales_orders do
        source(event: "students.list", mode: :reset)
        insert(on: "student_created", at: 0, limit: -10)
        update(on: "student_updated")
        delete(on: "student_deleted")
      end

      collection :enveloped_orders do
        source(event: "students.custom_envelope", mode: :reset)
        insert(on: "student_created")
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

    def sales_order_params(_socket), do: {:ok, %{"page" => %{"limit" => 1}}}
    def raw_sales_order_params, do: %{"page" => %{"limit" => 1}}
    def failing_params, do: {:error, :missing_context}
    def order_topics(_socket), do: {:ok, ["orders:new", "orders:tenant"]}
    def raw_order_topic, do: "orders:raw"
    def invalid_order_topics, do: [123]

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

    start_supervised!({Phoenix.PubSub, name: Alva.PubSub})
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

  test "manual collection activation accepts static source params" do
    create_student!("Manual Params A")
    create_student!("Manual Params B")

    {:cont, socket} =
      Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, base_socket())

    socket = Alva.LiveView.collection(socket, :sales_orders, params: %{"page" => %{"limit" => 1}})

    assert [_one_record] = stream_items(socket, :sales_orders)
  end

  test "collection activation streams records from an Ash page-like source result" do
    create_student!("Paged Source A")
    create_student!("Paged Source B")

    {:cont, socket} =
      Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, base_socket())

    socket = Alva.LiveView.collection(socket, :sales_orders, params: %{"page" => %{"limit" => 1}})

    assert [%{name: name}] = stream_items(socket, :sales_orders)
    assert name in ["Paged Source A", "Paged Source B"]
  end

  test "collection activation fails clearly for unsupported custom DTO envelopes" do
    {:cont, socket} =
      Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, base_socket())

    assert_raise ArgumentError,
                 ~r/Alva collection :enveloped_orders source event "students.custom_envelope" returned a custom envelope whose records could not be inferred/,
                 fn ->
                   Alva.LiveView.collection(socket, :enveloped_orders)
                 end
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

  test "declarative collection activation accepts static source params" do
    create_student!("Static Params A")
    create_student!("Static Params B")

    {:cont, socket} =
      Alva.LiveView.on_mount(
        {[Alva.LiveViewTest.TestDomain], [sales_orders: [params: %{"page" => %{"limit" => 1}}]]},
        %{},
        %{},
        base_socket()
      )

    assert [_one_record] = stream_items(socket, :sales_orders)
  end

  test "declarative collection activation resolves params callbacks on the LiveView module" do
    create_student!("Callback Params A")
    create_student!("Callback Params B")

    {:cont, socket} =
      Alva.LiveView.on_mount(
        {[Alva.LiveViewTest.TestDomain], [sales_orders: [params: :sales_order_params]]},
        %{},
        %{},
        base_socket(view: CollectionLive)
      )

    assert [_one_record] = stream_items(socket, :sales_orders)
  end

  test "collection params callbacks may return raw params" do
    create_student!("Raw Callback Params A")
    create_student!("Raw Callback Params B")

    {:cont, socket} =
      Alva.LiveView.on_mount(
        {[Alva.LiveViewTest.TestDomain], [sales_orders: [params: :raw_sales_order_params]]},
        %{},
        %{},
        base_socket(view: CollectionLive)
      )

    assert [_one_record] = stream_items(socket, :sales_orders)
  end

  test "collection params callback failure raises a clear activation error" do
    assert_raise ArgumentError,
                 ~r/Alva collection :sales_orders params callback :failing_params failed: :missing_context/,
                 fn ->
                   Alva.LiveView.on_mount(
                     {[Alva.LiveViewTest.TestDomain], [sales_orders: [params: :failing_params]]},
                     %{},
                     %{},
                     base_socket(view: CollectionLive)
                   )
                 end
  end

  test "declarative collection activation subscribes connected LiveViews to static topics" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        {[Alva.LiveViewTest.TestDomain], [sales_orders: [subscriptions: ["orders:new"]]]},
        %{},
        %{},
        connected_socket()
      )

    assert "orders:new" in Alva.LiveView.route_subscriptions(socket)

    Phoenix.PubSub.broadcast(Alva.PubSub, "orders:new", {:collection_subscription_seen, self()})
    assert_receive {:collection_subscription_seen, _}
  end

  test "declarative collection activation resolves subscription callbacks" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        {[Alva.LiveViewTest.TestDomain], [sales_orders: [subscriptions: [:order_topics]]]},
        %{},
        %{},
        connected_socket(view: CollectionLive)
      )

    assert "orders:new" in Alva.LiveView.route_subscriptions(socket)
    assert "orders:tenant" in Alva.LiveView.route_subscriptions(socket)
  end

  test "subscription callbacks may return a raw binary topic" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        {[Alva.LiveViewTest.TestDomain], [sales_orders: [subscriptions: [:raw_order_topic]]]},
        %{},
        %{},
        connected_socket(view: CollectionLive)
      )

    assert "orders:raw" in Alva.LiveView.route_subscriptions(socket)
  end

  test "subscription callback failure raises a clear activation error" do
    assert_raise ArgumentError,
                 ~r/Alva collection :sales_orders subscription callback :failing_params failed: :missing_context/,
                 fn ->
                   Alva.LiveView.on_mount(
                     {[Alva.LiveViewTest.TestDomain],
                      [sales_orders: [subscriptions: [:failing_params]]]},
                     %{},
                     %{},
                     connected_socket(view: CollectionLive)
                   )
                 end
  end

  test "subscription callbacks must resolve to binary topics" do
    assert_raise ArgumentError,
                 ~r/Alva collection :sales_orders subscription callback :invalid_order_topics must return a binary topic or list of binary topics/,
                 fn ->
                   Alva.LiveView.on_mount(
                     {[Alva.LiveViewTest.TestDomain],
                      [sales_orders: [subscriptions: [:invalid_order_topics]]]},
                     %{},
                     %{},
                     connected_socket(view: CollectionLive)
                   )
                 end
  end

  test "subscription callbacks fail loud before the LiveView is connected" do
    assert_raise ArgumentError,
                 ~r/Alva collection :sales_orders subscription callback :invalid_order_topics must return a binary topic or list of binary topics/,
                 fn ->
                   Alva.LiveView.on_mount(
                     {[Alva.LiveViewTest.TestDomain],
                      [sales_orders: [subscriptions: [:invalid_order_topics]]]},
                     %{},
                     %{},
                     base_socket(view: CollectionLive)
                   )
                 end
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

  test "successful create commands update active collections immediately" do
    socket = active_collection_socket()
    [%{function: callback}] = socket.private.lifecycle.handle_event

    {:halt, reply, final_socket} =
      callback.("students.create", %{"name" => "Buy no refresh"}, socket)

    assert reply.ok == true
    assert %{name: "Buy no refresh"} = reply.data

    assert [{_dom_id, 0, %{name: "Buy no refresh"}, -10, false}] =
             stream_inserts(final_socket, :sales_orders)

    refute Map.has_key?(final_socket.assigns, :sales_orders)
  end

  test "successful update commands update active collection items immediately" do
    student = create_student!("Before Rename")
    socket = active_collection_socket()
    [%{function: callback}] = socket.private.lifecycle.handle_event

    {:halt, reply, final_socket} =
      callback.("students.rename", %{"id" => student.id, "name" => "After Rename"}, socket)

    assert reply.ok == true

    assert Enum.any?(stream_inserts(final_socket, :sales_orders), fn
             {_dom_id, -1, %{id: id, name: "After Rename"}, nil, true} ->
               id == student.id

             _other ->
               false
           end)
  end

  test "successful destroy commands remove active collection items immediately" do
    student = create_student!("Destroy Me")
    socket = active_collection_socket()
    [%{function: callback}] = socket.private.lifecycle.handle_event

    {:halt, reply, final_socket} =
      callback.("students.destroy", %{"id" => student.id}, socket)

    assert reply.ok == true
    assert ["sales_orders-#{student.id}"] == stream_deletes(final_socket, :sales_orders)
  end

  test "PubSub echo after an immediate collection insert does not create duplicate stream records" do
    socket = active_collection_socket()
    [%{function: event_callback}] = socket.private.lifecycle.handle_event
    [%{function: info_callback}] = socket.private.lifecycle.handle_info

    {:halt, reply, socket} =
      event_callback.("students.create", %{"name" => "Echo Safe"}, socket)

    {:halt, final_socket} =
      info_callback.(
        %Ash.Notifier.Notification{
          resource: TestResource,
          action: %{name: :create},
          data: reply.data
        },
        socket
      )

    inserted_ids =
      final_socket
      |> stream_inserts(:sales_orders)
      |> Enum.map(fn {dom_id, _at, _item, _limit, _update_only} -> dom_id end)

    assert length(inserted_ids) == length(Enum.uniq(inserted_ids))
  end

  test "failed command results do not mutate active collections" do
    socket = active_collection_socket()
    [%{function: callback}] = socket.private.lifecycle.handle_event

    {:halt, reply, final_socket} =
      callback.("students.rename", %{"id" => Ash.UUID.generate(), "name" => "Missing"}, socket)

    assert reply.ok == false
    assert stream_inserts(final_socket, :sales_orders) == []
    assert stream_deletes(final_socket, :sales_orders) == []
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

  test "handle_info inserts matching active collection notifications through stream_insert options" do
    {:halt, final_socket} =
      collection_callback().(student_created_notification(), active_collection_socket())

    assert [{_dom_id, 0, %{id: "123", name: "test"}, -10, false}] =
             stream_inserts(final_socket, :sales_orders)

    refute Map.has_key?(final_socket.assigns, :sales_orders)
  end

  test "handle_info updates matching active collection notifications with update_only by default" do
    {:halt, final_socket} =
      collection_callback().(student_updated_notification(), active_collection_socket())

    assert [{_dom_id, -1, %{id: "123", name: "renamed"}, nil, true}] =
             stream_inserts(final_socket, :sales_orders)
  end

  test "handle_info deletes matching active collection notifications through stream_delete" do
    {:halt, final_socket} =
      collection_callback().(student_deleted_notification(), active_collection_socket())

    assert ["sales_orders-123"] = stream_deletes(final_socket, :sales_orders)
  end

  test "inactive collections ignore matching PubSub occurrences" do
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

    [%{function: callback}] = socket.private.lifecycle.handle_info

    assert {:cont, ^socket} = callback.(student_created_notification(), socket)
    refute Map.has_key?(socket.assigns, :streams)
  end

  defp base_socket(opts \\ []) do
    %Phoenix.LiveView.Socket{
      endpoint: Keyword.get(opts, :endpoint),
      transport_pid: Keyword.get(opts, :transport_pid),
      view: Keyword.get(opts, :view),
      assigns: %{__changed__: %{}},
      private: %{lifecycle: %Phoenix.LiveView.Lifecycle{}}
    }
  end

  defp connected_socket(opts \\ []) do
    opts
    |> Keyword.put_new(:endpoint, Alva.LiveViewTest.Endpoint)
    |> Keyword.put_new(:transport_pid, self())
    |> base_socket()
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

  defp active_collection_socket do
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

    Alva.LiveView.collection(socket, :sales_orders)
  end

  defp stream_callback do
    socket = active_stream_socket()
    [%{function: callback}] = socket.private.lifecycle.handle_info
    callback
  end

  defp collection_callback do
    socket = active_collection_socket()
    [%{function: callback}] = socket.private.lifecycle.handle_info
    callback
  end

  defp stream_items(socket, name) do
    socket.assigns.streams
    |> Map.fetch!(name)
    |> Map.fetch!(:inserts)
    |> Enum.map(fn {_dom_id, _at, item, _limit, _update_only} -> item end)
  end

  defp stream_inserts(socket, name) do
    socket.assigns.streams
    |> Map.fetch!(name)
    |> Map.fetch!(:inserts)
  end

  defp stream_deletes(socket, name) do
    socket.assigns.streams
    |> Map.fetch!(name)
    |> Map.fetch!(:deletes)
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
