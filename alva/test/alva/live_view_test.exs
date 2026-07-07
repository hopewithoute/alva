defmodule Alva.LiveViewTest do
  use ExUnit.Case

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :alva
    plug(Plug.Session, store: :cookie, key: "_alva_key", signing_salt: "whatever123")
  end

  defmodule Router do
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
      event(:upload, name: "upload", action: :upload_file)
      event(:students_list, name: "students.list", action: :read)
      event(:students_custom_envelope, name: "students.custom_envelope", action: :custom_envelope)
      event(:students_create, name: "students.create", action: :create)
      event(:students_rename, name: "students.rename", action: :rename)
      event(:students_destroy, name: "students.destroy", action: :destroy)

      collection :students do
        source(event: :students_list, mode: :reset)
        insert(on: :upload_file)
        insert(on: :create)
        update(on: :rename)
        delete(on: :destroy)
      end

      collection :sales_orders do
        source(event: :students_list, mode: :reset)
        insert(on: :upload_file, at: 0, limit: -10)
        insert(on: :create, at: 0, limit: -10)
        update(on: :rename)
        delete(on: :destroy)
      end

      collection :priority_orders do
        source(event: :students_list, mode: :reset)
        insert(on: :create)
      end

      collection :enveloped_orders do
        source(event: :students_custom_envelope, mode: :reset)
        insert(on: :upload_file)
        insert(on: :create)
      end

      signal(:students_created,
        name: "students.created",
        on: :upload_file,
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
      defaults([:read])

      create :create do
        accept([])
      end
    end

    pub_sub do
      module(Alva.LiveViewTest.Endpoint)

      publish("student_created", :create, "other_students")
    end

    live_vue do
      event(:other_students_list, name: "other_students.list", action: :read)

      collection :other_students do
        source(event: :other_students_list, mode: :reset)
        insert(on: :create)
      end

      signal(:other_students_created,
        name: "other_students.created",
        on: :create
      )
    end
  end

  defmodule ScopedResource do
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
      attribute(:tenant, :string, public?: true)
    end

    actions do
      create :create do
        accept([:tenant])
      end
    end

    pub_sub do
      module(Alva.LiveViewTest.Endpoint)
      prefix("scoped")

      publish("scoped_created", :create, ["tenant", :tenant])
    end

    live_vue do
      signal(:scoped_created,
        name: "scoped.created",
        on: :create
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
      signal(:jobs_completed,
        name: "jobs.completed",
        on: :complete
      )
    end
  end

  defmodule MultiTopicResource do
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
      create :create do
        accept([])
      end
    end

    pub_sub do
      module(Alva.LiveViewTest.Endpoint)

      publish("multi_topic_created", :create, ["students", ["all", "tenant"]])
    end

    live_vue do
      signal(:multi_topic_students_created,
        name: "students.multi_topic_created",
        on: :create
      )
    end
  end

  defmodule AmbiguousResource do
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
      create :create do
        accept([])
      end
    end

    pub_sub do
      module(Alva.LiveViewTest.Endpoint)

      publish("ambiguous_created", :create, "students:all")
      publish("ambiguous_created", :create, "students:tenant")
    end

    live_vue do
      signal(:ambiguous_students_created,
        name: "students.ambiguous_created",
        on: :create
      )
    end
  end

  defmodule SharedKeyPrimaryResource do
    use Ash.Resource,
      domain: Alva.LiveViewTest.SharedKeyPrimaryDomain,
      validate_domain_inclusion?: false,
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
      read :read do
        primary?(true)
      end

      create :create do
        accept([:name])
      end
    end

    live_vue do
      event(:shared_list, name: "primary.shared.list", action: :read)

      collection :primary_orders do
        source(event: :shared_list, mode: :reset)
      end
    end
  end

  defmodule SharedKeySecondaryResource do
    use Ash.Resource,
      domain: Alva.LiveViewTest.SharedKeySecondaryDomain,
      validate_domain_inclusion?: false,
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
      read :read do
        primary?(true)
      end

      create :create do
        accept([:name])
      end
    end

    live_vue do
      event(:shared_list, name: "secondary.shared.list", action: :read)

      collection :secondary_orders do
        source(event: :shared_list, mode: :reset)
      end
    end
  end

  defmodule DummyLive do
    use Phoenix.LiveView
    use Alva.LiveView

    def render(assigns) do
      assigns = assign(assigns, :has_file, Map.has_key?(Map.get(assigns, :uploads, %{}), :file))

      ~H"""
      <div id="upload-status"><%= @has_file %></div>
      """
    end
  end

  defmodule CollectionLive do
    use Phoenix.LiveView
    use Alva.LiveView, collections: [:sales_orders]

    def sales_order_params(_socket), do: {:ok, %{"page" => %{"limit" => 1}}}
    def raw_sales_order_params, do: %{"page" => %{"limit" => 1}}
    def failing_params, do: {:error, :missing_context}

    def route_aware_sales_order_source_input(socket) do
      limit =
        socket
        |> Alva.LiveView.route_params()
        |> Map.get("limit", "1")
        |> String.to_integer()

      {:ok, %{"page" => %{"limit" => limit}}}
    end

    def sales_order_route_reload_input(socket) do
      {:ok, %{"page" => %{"limit" => route_limit(socket, "sales_limit")}}}
    end

    def priority_order_route_reload_input(socket) do
      {:ok, %{"page" => %{"limit" => route_limit(socket, "priority_limit")}}}
    end

    def order_topics(_socket), do: {:ok, ["orders:new", "orders:tenant"]}
    def raw_order_topic, do: "orders:raw"
    def ok_raw_order_topic(_socket), do: {:ok, "orders:ok"}
    def duplicate_order_topics(_socket), do: {:ok, ["orders:new", "orders:new", "orders:tenant"]}
    def invalid_order_topics, do: [123]
    def student_topics(_socket), do: {:ok, ["students", "students:tenant"]}
    def shared_student_topics(_socket), do: {:ok, ["students", "students"]}
    def raw_student_topic, do: "students:raw"
    def invalid_student_topics, do: [123]
    def no_topics(_socket), do: {:ok, []}
    def nil_topics, do: nil
    def scoped_signal_topics(_socket), do: {:ok, ["scoped:tenant:alpha"]}

    def route_scoped_student_topics(socket) do
      tenant =
        socket
        |> Alva.LiveView.route_params()
        |> Map.get("tenant", "alpha")

      {:ok, ["students:tenant:#{tenant}"]}
    end

    def route_scoped_student_topics_or_fail(socket) do
      case socket |> Alva.LiveView.route_params() |> Map.get("tenant", "alpha") do
        "explode" -> {:error, :missing_context}
        tenant -> {:ok, ["students:tenant:#{tenant}"]}
      end
    end

    defp route_limit(socket, key) do
      socket
      |> Alva.LiveView.route_params()
      |> Map.get(key, "1")
      |> String.to_integer()
    end

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

  defmodule PageEventLive do
    use Phoenix.LiveView

    use Alva.LiveView,
      page_events: [
        {"page.echo", :echo_page_event},
        {"page.invalid", :invalid_page_event}
      ]

    def echo_page_event(%{"name" => name}, socket) do
      socket = Phoenix.Component.assign(socket, :echoed_name, name)
      {:reply, %{ok: true, data: %{name: name}}, socket}
    end

    def invalid_page_event(_params, socket) do
      {:noreply, socket}
    end

    def render(assigns) do
      assigns = Phoenix.Component.assign(assigns, :echoed_name, Map.get(assigns, :echoed_name))

      ~H"""
      <div id="page-event-echo"><%= @echoed_name %></div>
      """
    end
  end

  defmodule PageStateLive do
    use Phoenix.LiveView

    use Alva.LiveView,
      page_state: :support_page_state

    def support_page_state(socket) do
      params = Alva.LiveView.route_params(socket)

      %{
        active_conversation_id: normalize_optional_string(Map.get(params, "conversation_id")),
        connected_customer_name: normalize_optional_string(Map.get(params, "customer_name"))
      }
    end

    def invalid_page_state(_socket), do: :invalid

    def render(assigns) do
      assigns =
        Phoenix.Component.assign(assigns, %{
          active_conversation_id: Map.get(assigns, :active_conversation_id),
          connected_customer_name: Map.get(assigns, :connected_customer_name)
        })

      ~H"""
      <div id="page-state-conversation"><%= @active_conversation_id %></div>
      <div id="page-state-customer"><%= @connected_customer_name %></div>
      """
    end

    defp normalize_optional_string(value) do
      value
      |> to_string()
      |> String.trim()
      |> case do
        "" -> nil
        trimmed -> trimmed
      end
    rescue
      Protocol.UndefinedError -> nil
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

    resources do
      resource(TestResource)
      resource(OtherResource)
      resource(ScopedResource)
      resource(JobResource)
      resource(MultiTopicResource)
      resource(AmbiguousResource)
    end
  end

  defmodule SharedKeyPrimaryDomain do
    use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

    resources do
      resource(SharedKeyPrimaryResource)
    end
  end

  defmodule SharedKeySecondaryDomain do
    use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

    resources do
      resource(SharedKeySecondaryResource)
    end
  end

  setup_all do
    Application.put_env(:alva, Alva.LiveViewTest.Endpoint,
      secret_key_base: String.duplicate("a", 64),
      live_view: [signing_salt: String.duplicate("a", 16)],
      pubsub_server: Alva.PubSub,
      render_errors: [formats: [html: Phoenix.ErrorView], layout: false]
    )

    Application.put_env(:alva, :ash_domains, [
      Alva.LiveViewTest.TestDomain,
      Alva.LiveViewTest.SharedKeyPrimaryDomain,
      Alva.LiveViewTest.SharedKeySecondaryDomain
    ])

    on_exit(fn ->
      Application.delete_env(:alva, :ash_domains)
    end)

    start_supervised!({Phoenix.PubSub, name: Alva.PubSub})
    start_supervised!(Alva.LiveViewTest.Endpoint)
    :ok
  end

  setup do
    %{conn: Phoenix.ConnTest.build_conn()}
  end

  test "mount configures allow_upload for ash_storage arguments" do
    socket = base_socket()

    {:cont, socket} = Alva.LiveView.on_mount(%{}, %{}, %{}, socket)

    assert socket.assigns.uploads != nil
  end

  test "route_subscriptions/1 reports declarative projection topics on disconnected sockets" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [:sales_orders],
          signals: [:students_created],
          route_subscriptions: [
            {:sales_orders, []},
            {:students_created, :route_scoped_student_topics}
          ]
        },
        %{"tenant" => "alpha"},
        %{},
        base_socket(view: CollectionLive, router: Router)
      )

    assert ["students:tenant:alpha"] == Alva.LiveView.route_subscriptions(socket)
  end

  test "activates collection and signal projections by declaration key" do
    {:cont, socket} =
      Alva.LiveView.on_mount(%{}, %{}, %{}, base_socket())

    socket =
      socket
      |> Alva.LiveView.collection(:students)
      |> Alva.LiveView.activate_signal(:students_created)

    assert Alva.LiveView.projection_active?(socket, :collection, :students)
    assert Alva.LiveView.projection_active?(socket, :signal, :students_created)
  end

  test "activates collection manually by dispatching its source event into a LiveView stream" do
    create_student!("Manual Collection A")

    {:cont, socket} =
      Alva.LiveView.on_mount(%{}, %{}, %{}, base_socket())

    socket = Alva.LiveView.collection(socket, :sales_orders)

    assert Alva.LiveView.projection_active?(socket, :collection, :sales_orders)
    assert [%{name: "Manual Collection A"}] = stream_items(socket, :sales_orders)
    refute Map.has_key?(socket.assigns, :sales_orders)
  end

  test "manual collection activation accepts static source input" do
    create_student!("Manual Params A")
    create_student!("Manual Params B")

    {:cont, socket} =
      Alva.LiveView.on_mount(%{}, %{}, %{}, base_socket())

    socket =
      Alva.LiveView.collection(socket, :sales_orders, source_input: %{"page" => %{"limit" => 1}})

    assert [_one_record] = stream_items(socket, :sales_orders)
    assert active_collection_source_input(socket, :sales_orders) == %{"page" => %{"limit" => 1}}
  end

  test "collection source events resolve within the owning resource when mounted domains share an event key" do
    create_shared_primary!("Primary Shared")
    create_shared_secondary!("Secondary Shared")

    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [:secondary_orders]
        },
        %{},
        %{},
        base_socket()
      )

    names = Enum.map(stream_items(socket, :secondary_orders), & &1.name)

    assert "Secondary Shared" in names
    refute "Primary Shared" in names
  end

  test "manual collection activation still accepts params as a source input alias" do
    create_student!("Alias Params A")
    create_student!("Alias Params B")

    {:cont, socket} =
      Alva.LiveView.on_mount(%{}, %{}, %{}, base_socket())

    socket = Alva.LiveView.collection(socket, :sales_orders, params: %{"page" => %{"limit" => 1}})

    assert [_one_record] = stream_items(socket, :sales_orders)
  end

  test "collection activation streams records from an Ash page-like source result" do
    create_student!("Paged Source A")
    create_student!("Paged Source B")

    {:cont, socket} =
      Alva.LiveView.on_mount(%{}, %{}, %{}, base_socket())

    socket =
      Alva.LiveView.collection(socket, :sales_orders, source_input: %{"page" => %{"limit" => 1}})

    assert [%{name: name}] = stream_items(socket, :sales_orders)
    assert name in ["Paged Source A", "Paged Source B"]
  end

  test "collection activation fails clearly for unsupported custom DTO envelopes" do
    {:cont, socket} =
      Alva.LiveView.on_mount(%{}, %{}, %{}, base_socket())

    assert_raise ArgumentError,
                 ~r/Alva collection :enveloped_orders source event :students_custom_envelope returned a custom envelope whose records could not be inferred/,
                 fn ->
                   Alva.LiveView.collection(socket, :enveloped_orders)
                 end
  end

  test "declarative collections activate only allowlisted collection names" do
    create_student!("Declarative Collection A")

    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{collections: [:sales_orders]},
        %{},
        %{},
        base_socket()
      )

    assert Alva.LiveView.projection_active?(socket, :collection, :sales_orders)
    assert [%{name: "Declarative Collection A"}] = stream_items(socket, :sales_orders)
    refute Alva.LiveView.projection_active?(socket, :collection, :students)
  end

  test "declarative collection activation accepts static source input" do
    create_student!("Static Params A")
    create_student!("Static Params B")

    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [sales_orders: [source_input: %{"page" => %{"limit" => 1}}]]
        },
        %{},
        %{},
        base_socket()
      )

    assert [_one_record] = stream_items(socket, :sales_orders)
    assert active_collection_source_input(socket, :sales_orders) == %{"page" => %{"limit" => 1}}
  end

  test "legacy tuple mount config fails loudly" do
    assert_raise ArgumentError,
                 ~r/no longer supports legacy tuple mount config/,
                 fn ->
                   apply(Alva.LiveView, :on_mount, [
                     {[Alva.LiveViewTest.TestDomain], [:sales_orders]},
                     %{},
                     %{},
                     base_socket()
                   ])
                 end
  end

  test "keyword-list mount config fails loudly" do
    assert_raise ArgumentError,
                 ~r/maps must be passed as a map, not a keyword list/,
                 fn ->
                   apply(Alva.LiveView, :on_mount, [
                     [domains: [Alva.LiveViewTest.TestDomain], collections: [:sales_orders]],
                     %{},
                     %{},
                     base_socket()
                   ])
                 end
  end

  test "runtime mount config rejects page-scoped domains" do
    assert_raise ArgumentError,
                 ~r/no longer accepts `domains:`/,
                 fn ->
                   Alva.LiveView.on_mount(
                     %{domains: [Alva.LiveViewTest.TestDomain], collections: [:sales_orders]},
                     %{},
                     %{},
                     base_socket()
                   )
                 end
  end

  test "runtime mount config rejects browser-facing signal names" do
    assert_raise ArgumentError,
                 ~r/no longer accepts browser-facing string names/,
                 fn ->
                   Alva.LiveView.on_mount(
                     %{
                       signals: ["students.created"]
                     },
                     %{},
                     %{},
                     base_socket()
                   )
                 end
  end

  test "runtime mount config rejects tuple signal entries" do
    assert_raise ArgumentError,
                 ~r/only accepts atom declaration keys/,
                 fn ->
                   Alva.LiveView.on_mount(
                     %{
                       signals: [{:students_created, []}]
                     },
                     %{},
                     %{},
                     base_socket()
                   )
                 end
  end

  test "route_params/1 defaults to an empty map before route params are observed" do
    assert Alva.LiveView.route_params(base_socket()) == %{}
  end

  test "use Alva.LiveView injects a default no-op handle_params/3" do
    socket = base_socket()

    assert {:noreply, ^socket} = DummyLive.handle_params(%{}, "/", socket)
  end


  test "route_params/1 returns the latest route params known to Alva" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{},
        %{"limit" => "2", "status" => "open"},
        %{},
        base_socket()
      )

    assert Alva.LiveView.route_params(socket) == %{"limit" => "2", "status" => "open"}
  end

  test "declarative collection activation resolves source input callbacks on the LiveView module" do
    create_student!("Callback Params A")
    create_student!("Callback Params B")

    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [sales_orders: [source_input: :sales_order_params]]
        },
        %{},
        %{},
        base_socket(view: CollectionLive)
      )

    assert [_one_record] = stream_items(socket, :sales_orders)
  end

  test "collection source input callbacks may derive input from route params" do
    create_student!("Route Params A")
    create_student!("Route Params B")

    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [sales_orders: [source_input: :route_aware_sales_order_source_input]],
          route_subscriptions: [{:sales_orders, []}]
        },
        %{"limit" => "1"},
        %{},
        base_socket(view: CollectionLive)
      )

    assert [_one_record] = stream_items(socket, :sales_orders)
    assert active_collection_source_input(socket, :sales_orders) == %{"page" => %{"limit" => 1}}
  end

  test "collection source input callbacks may return raw maps" do
    create_student!("Raw Callback Params A")
    create_student!("Raw Callback Params B")

    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [sales_orders: [source_input: :raw_sales_order_params]]
        },
        %{},
        %{},
        base_socket(view: CollectionLive)
      )

    assert [_one_record] = stream_items(socket, :sales_orders)
  end

  test "reload_collection/2 refreshes an active collection with its stored source input" do
    create_student!("Refresh Stored A")

    {:cont, socket} =
      Alva.LiveView.on_mount(%{}, %{}, %{}, base_socket())

    socket =
      Alva.LiveView.collection(socket, :sales_orders, source_input: %{"page" => %{"limit" => 2}})

    create_student!("Refresh Stored B")

    socket = Alva.LiveView.reload_collection(socket, :sales_orders)

    rendered = Phoenix.LiveViewTest.rendered_to_string(CollectionLive.render(socket.assigns))

    assert rendered =~ "Refresh Stored A"
    assert rendered =~ "Refresh Stored B"
    assert active_collection_source_input(socket, :sales_orders) == %{"page" => %{"limit" => 2}}
  end

  test "reload_collection/3 refreshes an active collection with the provided source input" do
    create_student!("Refresh Override A")
    create_student!("Refresh Override B")

    {:cont, socket} =
      Alva.LiveView.on_mount(%{}, %{}, %{}, base_socket())

    socket =
      Alva.LiveView.collection(socket, :sales_orders, source_input: %{"page" => %{"limit" => 1}})

    socket =
      Alva.LiveView.reload_collection(socket, :sales_orders,
        source_input: %{"page" => %{"limit" => 2}}
      )

    rendered = Phoenix.LiveViewTest.rendered_to_string(CollectionLive.render(socket.assigns))

    assert rendered =~ "Refresh Override A"
    assert rendered =~ "Refresh Override B"
    assert active_collection_source_input(socket, :sales_orders) == %{"page" => %{"limit" => 2}}
  end

  test "reload_collection/2 fails clearly for an inactive collection" do
    {:cont, socket} =
      Alva.LiveView.on_mount(%{}, %{}, %{}, base_socket())

    assert_raise ArgumentError,
                 ~r/Alva collection :sales_orders is not active on this LiveView and cannot be reloaded/,
                 fn ->
                   Alva.LiveView.reload_collection(socket, :sales_orders)
                 end
  end

  test "reload_collection/2 fails clearly for an unknown collection" do
    {:cont, socket} =
      Alva.LiveView.on_mount(%{}, %{}, %{}, base_socket())

    assert_raise ArgumentError,
                 ~r/Unknown Alva collection projection :missing_orders/,
                 fn ->
                   Alva.LiveView.reload_collection(socket, :missing_orders)
                 end
  end

  test "reload_on: :route_change attaches route lifecycle handling and refreshes changed collections" do
    create_student!("Route Reload A")
    create_student!("Route Reload B")

    telemetry_handler_id = "alva-dispatch-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach(
        telemetry_handler_id,
        [:alva, :dispatch, :stop],
        fn _event, _measurements, metadata, pid ->
          send(pid, {:dispatch_seen, metadata.event_name, metadata.params})
        end,
        self()
      )

    on_exit(fn -> :telemetry.detach(telemetry_handler_id) end)

    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [
            sales_orders: [
              source_input: :sales_order_route_reload_input,
              reload_on: :route_change
            ]
          ],
          route_subscriptions: [{:sales_orders, []}]
        },
        %{"sales_limit" => "1"},
        %{},
        base_socket(view: CollectionLive, router: Router)
      )

    assert [%{function: callback}] = socket.private.lifecycle.handle_params

    drain_dispatch_events()

    assert {:cont, socket} = callback.(%{"sales_limit" => "2"}, "/orders?sales_limit=2", socket)
    assert_receive {:dispatch_seen, "students.list", %{"page" => %{"limit" => 2}}}

    rendered = Phoenix.LiveViewTest.rendered_to_string(CollectionLive.render(socket.assigns))

    assert rendered =~ "Route Reload A"
    assert rendered =~ "Route Reload B"
    assert active_collection_source_input(socket, :sales_orders) == %{"page" => %{"limit" => 2}}
    assert Alva.LiveView.route_params(socket) == %{"sales_limit" => "2"}
  end

  test "reload_on: :route_change skips refresh when source input is unchanged" do
    create_student!("Route Stable A")

    telemetry_handler_id = "alva-dispatch-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach(
        telemetry_handler_id,
        [:alva, :dispatch, :stop],
        fn _event, _measurements, metadata, pid ->
          send(pid, {:dispatch_seen, metadata.event_name, metadata.params})
        end,
        self()
      )

    on_exit(fn -> :telemetry.detach(telemetry_handler_id) end)

    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [
            sales_orders: [
              source_input: :sales_order_route_reload_input,
              reload_on: :route_change
            ]
          ],
          route_subscriptions: [{:sales_orders, []}]
        },
        %{"sales_limit" => "1"},
        %{},
        base_socket(view: CollectionLive, router: Router)
      )

    [%{function: callback}] = socket.private.lifecycle.handle_params

    drain_dispatch_events()

    assert {:cont, socket} =
             callback.(%{"sales_limit" => "1", "tab" => "summary"}, "/orders?tab=summary", socket)

    refute_receive {:dispatch_seen, "students.list", _}, 50
    assert Alva.LiveView.route_params(socket) == %{"sales_limit" => "1", "tab" => "summary"}
    assert active_collection_source_input(socket, :sales_orders) == %{"page" => %{"limit" => 1}}
  end

  test "callback route_subscriptions attach route lifecycle handling and diff topics on route change" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          signals: [:students_created],
          route_subscriptions: [
            {:students_created, :route_scoped_student_topics}
          ]
        },
        %{"tenant" => "alpha"},
        %{},
        connected_socket(view: CollectionLive, router: Router)
      )

    assert ["students:tenant:alpha"] == Alva.LiveView.route_subscriptions(socket)
    [%{function: callback}] = socket.private.lifecycle.handle_params

    Phoenix.PubSub.broadcast(
      Alva.PubSub,
      "students:tenant:alpha",
      {:initial_route_subscription_seen, self()}
    )

    assert_receive {:initial_route_subscription_seen, _}

    assert {:cont, socket} = callback.(%{"tenant" => "beta"}, "/orders?tenant=beta", socket)

    assert ["students:tenant:beta"] == Alva.LiveView.route_subscriptions(socket)
    assert Alva.LiveView.route_params(socket) == %{"tenant" => "beta"}

    Phoenix.PubSub.broadcast(
      Alva.PubSub,
      "students:tenant:alpha",
      {:stale_route_subscription_seen, self()}
    )

    refute_receive {:stale_route_subscription_seen, _}, 50

    Phoenix.PubSub.broadcast(
      Alva.PubSub,
      "students:tenant:beta",
      {:fresh_route_subscription_seen, self()}
    )

    assert_receive {:fresh_route_subscription_seen, _}
  end

  test "route topic diffs preserve imperative collection subscriptions on shared topics" do
    create_student!("Imperative Shared Topic")

    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [:sales_orders],
          signals: [:students_created],
          route_subscriptions: [
            {:sales_orders, []},
            {:students_created, :route_scoped_student_topics}
          ]
        },
        %{"tenant" => "alpha"},
        %{},
        connected_socket(view: CollectionLive, router: Router)
      )

    socket =
      Alva.LiveView.collection(socket, :sales_orders, subscriptions: ["students:tenant:alpha"])

    [%{function: callback}] = socket.private.lifecycle.handle_params

    assert {:cont, socket} = callback.(%{"tenant" => "beta"}, "/orders?tenant=beta", socket)
    assert ["students:tenant:beta"] == Alva.LiveView.route_subscriptions(socket)

    Phoenix.PubSub.broadcast(
      Alva.PubSub,
      "students:tenant:alpha",
      {:imperative_collection_subscription_seen, self()}
    )

    assert_receive {:imperative_collection_subscription_seen, _}

    Phoenix.PubSub.broadcast(
      Alva.PubSub,
      "students:tenant:beta",
      {:fresh_route_subscription_seen, self()}
    )

    assert_receive {:fresh_route_subscription_seen, _}
  end

  test "callback route_subscriptions fail loudly during route lifecycle recompute" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          signals: [:students_created],
          route_subscriptions: [
            {:students_created, :route_scoped_student_topics_or_fail}
          ]
        },
        %{"tenant" => "alpha"},
        %{},
        connected_socket(view: CollectionLive, router: Router)
      )

    [%{function: callback}] = socket.private.lifecycle.handle_params

    assert_raise ArgumentError,
                 ~r/Alva route subscription callback :route_scoped_student_topics_or_fail failed: :missing_context/,
                 fn ->
                   callback.(%{"tenant" => "explode"}, "/orders?tenant=explode", socket)
                 end
  end

  test "multiple route-change collections refresh independently based on their source input" do
    create_student!("Route Multi A")
    create_student!("Route Multi B")

    telemetry_handler_id = "alva-dispatch-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach(
        telemetry_handler_id,
        [:alva, :dispatch, :stop],
        fn _event, _measurements, metadata, pid ->
          send(pid, {:dispatch_seen, metadata.event_name, metadata.params})
        end,
        self()
      )

    on_exit(fn -> :telemetry.detach(telemetry_handler_id) end)

    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [
            sales_orders: [
              source_input: :sales_order_route_reload_input,
              reload_on: :route_change
            ],
            priority_orders: [
              source_input: :priority_order_route_reload_input,
              reload_on: :route_change
            ]
          ],
          route_subscriptions: [
            {:sales_orders, []},
            {:priority_orders, []}
          ]
        },
        %{"sales_limit" => "1", "priority_limit" => "1"},
        %{},
        base_socket(view: CollectionLive, router: Router)
      )

    [%{function: callback}] = socket.private.lifecycle.handle_params

    drain_dispatch_events()

    assert {:cont, socket} =
             callback.(
               %{"sales_limit" => "2", "priority_limit" => "1"},
               "/orders?sales_limit=2&priority_limit=1",
               socket
             )

    assert_receive {:dispatch_seen, "students.list", %{"page" => %{"limit" => 2}}}
    refute_receive {:dispatch_seen, "students.list", _}, 50

    assert active_collection_source_input(socket, :sales_orders) == %{"page" => %{"limit" => 2}}

    assert active_collection_source_input(socket, :priority_orders) == %{
             "page" => %{"limit" => 1}
           }
  end

  test "collection source input callback failure raises a clear activation error" do
    assert_raise ArgumentError,
                 ~r/Alva collection :sales_orders source input callback :failing_params failed: :missing_context/,
                 fn ->
                   Alva.LiveView.on_mount(
                     %{
                       collections: [sales_orders: [source_input: :failing_params]]
                     },
                     %{},
                     %{},
                     base_socket(view: CollectionLive)
                   )
                 end
  end

  test "active collections and signals infer deterministic route subscriptions by default" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [:sales_orders],
          signals: [:students_created]
        },
        %{},
        %{},
        connected_socket()
      )

    assert Alva.LiveView.projection_active?(socket, :collection, :sales_orders)
    assert Alva.LiveView.projection_active?(socket, :signal, :students_created)
    assert ["students"] == Enum.sort(Alva.LiveView.route_subscriptions(socket))

    Phoenix.PubSub.broadcast(Alva.PubSub, "students", {:inferred_route_subscription_seen, self()})
    assert_receive {:inferred_route_subscription_seen, _}
  end

  test "a collection with one static publication infers route subscriptions" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [:priority_orders]
        },
        %{},
        %{},
        connected_socket()
      )

    assert Alva.LiveView.projection_active?(socket, :collection, :priority_orders)
    assert ["students"] == Alva.LiveView.route_subscriptions(socket)
  end

  test "a signal with one static publication infers route subscriptions" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          signals: [:jobs_completed]
        },
        %{},
        %{},
        connected_socket()
      )

    assert Alva.LiveView.projection_active?(socket, :signal, :jobs_completed)
    assert ["jobs"] == Alva.LiveView.route_subscriptions(socket)
  end

  test "a single publication may expand into multiple static route subscriptions" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          signals: [:multi_topic_students_created]
        },
        %{},
        %{},
        connected_socket()
      )

    assert Alva.LiveView.projection_active?(socket, :signal, :multi_topic_students_created)

    assert ["students:all", "students:tenant"] ==
             Enum.sort(Alva.LiveView.route_subscriptions(socket))
  end

  test "route_subscriptions override only the named projection and keep inference for the rest" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [:sales_orders],
          signals: [:students_created],
          route_subscriptions: [
            {:sales_orders, ["orders:new"]}
          ]
        },
        %{},
        %{},
        connected_socket()
      )

    assert ["orders:new", "students"] == Enum.sort(Alva.LiveView.route_subscriptions(socket))
  end

  test "route_subscriptions callbacks may return topic lists" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [:sales_orders],
          route_subscriptions: [
            {:sales_orders, :order_topics}
          ]
        },
        %{},
        %{},
        connected_socket(view: CollectionLive)
      )

    assert ["orders:new", "orders:tenant"] == Enum.sort(Alva.LiveView.route_subscriptions(socket))
  end

  test "route_subscriptions callbacks may return a raw binary topic" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [:sales_orders],
          route_subscriptions: [
            {:sales_orders, :raw_order_topic}
          ]
        },
        %{},
        %{},
        connected_socket(view: CollectionLive)
      )

    assert ["orders:raw"] == Alva.LiveView.route_subscriptions(socket)
  end

  test "route_subscriptions callbacks may return {:ok, binary_topic}" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [:sales_orders],
          route_subscriptions: [
            {:sales_orders, :ok_raw_order_topic}
          ]
        },
        %{},
        %{},
        connected_socket(view: CollectionLive)
      )

    assert ["orders:ok"] == Alva.LiveView.route_subscriptions(socket)
  end

  test "route_subscriptions callbacks may return [] as an authoritative dynamic opt-out" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [:sales_orders],
          route_subscriptions: [
            {:sales_orders, :no_topics}
          ]
        },
        %{},
        %{},
        connected_socket(view: CollectionLive)
      )

    assert Alva.LiveView.projection_active?(socket, :collection, :sales_orders)
    assert [] == Alva.LiveView.route_subscriptions(socket)
  end

  test "route_subscriptions callbacks normalize duplicate topics before subscribing" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [:sales_orders],
          route_subscriptions: [
            {:sales_orders, :duplicate_order_topics}
          ]
        },
        %{},
        %{},
        connected_socket(view: CollectionLive)
      )

    assert ["orders:new", "orders:tenant"] == Enum.sort(Alva.LiveView.route_subscriptions(socket))
  end

  test "route_subscriptions accept an explicit binary topic for a signal projection" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          signals: [:students_created],
          route_subscriptions: [
            {:students_created, "students:direct"}
          ]
        },
        %{},
        %{},
        connected_socket()
      )

    assert Alva.LiveView.projection_active?(socket, :signal, :students_created)
    assert ["students:direct"] == Alva.LiveView.route_subscriptions(socket)

    Phoenix.PubSub.broadcast(
      Alva.PubSub,
      "students:direct",
      {:explicit_signal_route_subscription_seen, self()}
    )

    assert_receive {:explicit_signal_route_subscription_seen, _}
  end

  test "route_subscriptions allow an explicit empty list to opt out of realtime wiring" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [:sales_orders],
          route_subscriptions: [
            {:sales_orders, []}
          ]
        },
        %{},
        %{},
        connected_socket()
      )

    assert Alva.LiveView.projection_active?(socket, :collection, :sales_orders)
    assert [] == Alva.LiveView.route_subscriptions(socket)
  end

  test "declarative signals activate semantic callbacks during mount" do
    socket = %Phoenix.LiveView.Socket{
      endpoint: Alva.LiveViewTest.Endpoint,
      assigns: %{__changed__: %{}},
      private: %{
        lifecycle: %Phoenix.LiveView.Lifecycle{},
        live_temp: %{push_events: []}
      }
    }

    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          signals: [:students_created]
        },
        %{},
        %{},
        socket
      )

    assert Alva.LiveView.projection_active?(socket, :signal, :students_created)

    [%{function: callback}] = socket.private.lifecycle.handle_info

    {:halt, final_socket} = callback.(student_created_notification(), socket)

    assert [["students.created", %{id: "123", name: "test"}]] =
             final_socket.private.live_temp.push_events
  end

  test "projection keyed route_subscriptions wire active collections and signals" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [:sales_orders],
          signals: [:students_created],
          route_subscriptions: [
            {:sales_orders, ["orders:new"]},
            {:students_created, :student_topics}
          ]
        },
        %{},
        %{},
        connected_socket(view: CollectionLive)
      )

    assert Alva.LiveView.projection_active?(socket, :collection, :sales_orders)
    assert Alva.LiveView.projection_active?(socket, :signal, :students_created)
    assert "orders:new" in Alva.LiveView.route_subscriptions(socket)
    assert "students" in Alva.LiveView.route_subscriptions(socket)
    assert "students:tenant" in Alva.LiveView.route_subscriptions(socket)

    Phoenix.PubSub.broadcast(
      Alva.PubSub,
      "orders:new",
      {:projection_route_subscription_seen, self()}
    )

    assert_receive {:projection_route_subscription_seen, _}
  end

  test "route_subscriptions fail loud when a projection is not active" do
    assert_raise ArgumentError,
                 ~r/Alva route_subscriptions entry :students_created must reference an active Collection or Signal projection/,
                 fn ->
                   Alva.LiveView.on_mount(
                     %{
                       route_subscriptions: [
                         {:students_created, ["students"]}
                       ]
                     },
                     %{},
                     %{},
                     connected_socket()
                   )
                 end
  end

  test "route_subscriptions fail loud on duplicate projection entries" do
    assert_raise ArgumentError,
                 ~r/Alva route_subscriptions contains duplicate entries for :sales_orders/,
                 fn ->
                   Alva.LiveView.on_mount(
                     %{
                       collections: [:sales_orders],
                       route_subscriptions: [
                         {:sales_orders, ["orders:new"]},
                         {:sales_orders, ["orders:tenant"]}
                       ]
                     },
                     %{},
                     %{},
                     connected_socket()
                   )
                 end
  end

  test "route_subscriptions callbacks fail loud on callback failure" do
    assert_raise ArgumentError,
                 ~r/Alva route subscription callback :failing_params failed: :missing_context/,
                 fn ->
                   Alva.LiveView.on_mount(
                     %{
                       collections: [:sales_orders],
                       route_subscriptions: [
                         {:sales_orders, :failing_params}
                       ]
                     },
                     %{},
                     %{},
                     connected_socket(view: CollectionLive)
                   )
                 end
  end

  test "route_subscriptions callbacks must resolve to binary topics" do
    assert_raise ArgumentError,
                 ~r/Alva route subscription callback :invalid_order_topics must return a binary topic or list of binary topics/,
                 fn ->
                   Alva.LiveView.on_mount(
                     %{
                       collections: [:sales_orders],
                       route_subscriptions: [
                         {:sales_orders, :invalid_order_topics}
                       ]
                     },
                     %{},
                     %{},
                     connected_socket(view: CollectionLive)
                   )
                 end
  end

  test "route_subscriptions callbacks fail loudly when they return nil" do
    assert_raise ArgumentError,
                 ~r/Alva route subscription callback :nil_topics must return a binary topic or list of binary topics, got: nil/,
                 fn ->
                   Alva.LiveView.on_mount(
                     %{
                       collections: [:sales_orders],
                       route_subscriptions: [
                         {:sales_orders, :nil_topics}
                       ]
                     },
                     %{},
                     %{},
                     connected_socket(view: CollectionLive)
                   )
                 end
  end

  test "shared callback topics subscribe once while preserving collection and signal semantics" do
    socket = %Phoenix.LiveView.Socket{
      endpoint: Alva.LiveViewTest.Endpoint,
      transport_pid: self(),
      view: CollectionLive,
      assigns: %{__changed__: %{}},
      private: %{
        lifecycle: %Phoenix.LiveView.Lifecycle{},
        live_temp: %{push_events: []}
      }
    }

    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          collections: [:sales_orders],
          signals: [:students_created],
          route_subscriptions: [
            {:sales_orders, :shared_student_topics},
            {:students_created, :shared_student_topics}
          ]
        },
        %{},
        %{},
        socket
      )

    assert ["students"] == Alva.LiveView.route_subscriptions(socket)

    [%{function: callback}] = socket.private.lifecycle.handle_info

    {:halt, final_socket} = callback.(student_created_notification(), socket)

    assert [{_dom_id, 0, %{id: "123", name: "test"}, -10, false}] =
             stream_inserts(final_socket, :sales_orders)

    assert [["students.created", %{id: "123", name: "test"}]] =
             final_socket.private.live_temp.push_events
  end

  test "automatic route subscription inference fails loudly for dynamic publication topics" do
    assert_raise ArgumentError,
                 ~r/Alva could not infer deterministic route_subscriptions for Signal "scoped.created"/,
                 fn ->
                   Alva.LiveView.on_mount(
                     %{
                       signals: [:scoped_created]
                     },
                     %{},
                     %{},
                     connected_socket()
                   )
                 end
  end

  test "automatic route subscription inference fails loudly for ambiguous publications" do
    assert_raise ArgumentError,
                 ~r/Alva could not infer deterministic route_subscriptions for Signal "students.ambiguous_created" from trigger :create because multiple Ash PubSub publications match/,
                 fn ->
                   Alva.LiveView.on_mount(
                     %{
                       signals: [:ambiguous_students_created]
                     },
                     %{},
                     %{},
                     connected_socket()
                   )
                 end
  end

  test "automatic route subscription inference fails loudly when collection topic wiring depends on page scope" do
    assert_raise ArgumentError,
                 ~r/Alva could not infer deterministic route_subscriptions for Collection :sales_orders because its source_input callback :route_aware_sales_order_source_input may depend on Page Scope route params/,
                 fn ->
                   Alva.LiveView.on_mount(
                     %{
                       collections: [
                         sales_orders: [source_input: :route_aware_sales_order_source_input]
                       ]
                     },
                     %{"limit" => "1"},
                     %{},
                     base_socket(view: CollectionLive)
                   )
                 end
  end

  test "dynamic publication projections can use callback route_subscriptions overrides" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{
          signals: [:scoped_created],
          route_subscriptions: [
            {:scoped_created, :scoped_signal_topics}
          ]
        },
        %{},
        %{},
        connected_socket(view: CollectionLive)
      )

    assert Alva.LiveView.projection_active?(socket, :signal, :scoped_created)
    assert ["scoped:tenant:alpha"] == Alva.LiveView.route_subscriptions(socket)
  end

  test "on_mount fails loudly when collections and signals share a projection key" do
    assert_raise ArgumentError,
                 ~r/cannot activate the same projection key in both `collections:` and `signals:`: :sales_orders/,
                 fn ->
                   Alva.LiveView.on_mount(
                     %{
                       collections: [:sales_orders],
                       signals: [:sales_orders]
                     },
                     %{},
                     %{},
                     base_socket()
                   )
                 end
  end

  test "mounting a domain does not activate collections by default" do
    create_student!("Inactive Collection A")

    {:cont, socket} =
      Alva.LiveView.on_mount(%{}, %{}, %{}, base_socket())

    refute Alva.LiveView.projection_active?(socket, :collection, :sales_orders)
    refute Map.has_key?(socket.assigns, :streams)
  end

  test "unknown collection activation fails with an actionable error" do
    {:cont, socket} =
      Alva.LiveView.on_mount(%{}, %{}, %{}, base_socket())

    assert_raise ArgumentError,
                 ~r/Unknown Alva collection projection :missing_orders/,
                 fn -> Alva.LiveView.collection(socket, :missing_orders) end
  end

  test "render can pass an activated collection from @streams into markup" do
    create_student!("Rendered Collection A")

    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{collections: [:sales_orders]},
        %{},
        %{},
        base_socket()
      )

    assert Phoenix.LiveViewTest.rendered_to_string(CollectionLive.render(socket.assigns)) =~
             "Rendered Collection A"
  end

  test "activation state is scoped to the LiveView socket" do
    {:cont, list_socket} =
      Alva.LiveView.on_mount(%{}, %{}, %{}, base_socket())

    {:cont, notice_socket} =
      Alva.LiveView.on_mount(%{}, %{}, %{}, base_socket())

    list_socket = Alva.LiveView.collection(list_socket, :students)
    notice_socket = Alva.LiveView.activate_signal(notice_socket, :students_created)

    notification = student_created_notification()

    assert %{collections: [:students], signals: []} =
             Alva.LiveView.active_projections(list_socket, notification)

    assert %{collections: [], signals: [:students_created]} =
             Alva.LiveView.active_projections(notice_socket, notification)
  end

  test "active projections only match notifications from the projection resource" do
    {:cont, socket} =
      Alva.LiveView.on_mount(%{}, %{}, %{}, base_socket())

    socket =
      socket
      |> Alva.LiveView.collection(:other_students)
      |> Alva.LiveView.activate_signal(:other_students_created)

    assert %{collections: [], signals: []} =
             Alva.LiveView.active_projections(socket, student_created_notification())
  end

  test "handle_info ignores inactive Ash.Notifier.Notification projections" do
    socket = %Phoenix.LiveView.Socket{
      endpoint: Alva.LiveViewTest.Endpoint,
      assigns: %{__changed__: %{}},
      private: %{
        lifecycle: %Phoenix.LiveView.Lifecycle{},
        live_temp: %{push_events: []}
      }
    }

    {:cont, socket} = Alva.LiveView.on_mount(%{}, %{}, %{}, socket)

    [%{function: callback}] = socket.private.lifecycle.handle_info

    assert {:cont, ^socket} = callback.(student_created_notification(), socket)
  end

  test "handle_info pushes active signal notifications with semantic event names" do
    socket = %Phoenix.LiveView.Socket{
      endpoint: Alva.LiveViewTest.Endpoint,
      assigns: %{__changed__: %{}},
      private: %{
        lifecycle: %Phoenix.LiveView.Lifecycle{},
        live_temp: %{push_events: []}
      }
    }

    {:cont, socket} = Alva.LiveView.on_mount(%{}, %{}, %{}, socket)
    socket = Alva.LiveView.activate_signal(socket, :students_created)

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
        endpoint: Alva.LiveViewTest.Endpoint,
        assigns: %{__changed__: %{}},
        private: %{
          lifecycle: %Phoenix.LiveView.Lifecycle{},
          live_temp: %{push_events: []}
        }
      }
      |> then(fn socket ->
        {:cont, socket} = Alva.LiveView.on_mount(%{}, %{}, %{}, socket)
        socket
      end)
      |> Alva.LiveView.activate_signal(:students_created)

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

  test "unbound command read results behave as normal replies without collection mutation" do
    create_student!("Unbound A")

    socket = active_students_collection_socket()
    inserts_before = stream_inserts(socket, :students)
    [%{function: callback}] = socket.private.lifecycle.handle_event

    {:halt, reply, final_socket} =
      callback.(student_list_event(), %{"page" => %{"limit" => 1, "offset" => 0}}, socket)

    assert reply.ok == true
    assert stream_inserts(final_socket, :students) == inserts_before
  end

  test "successful create commands update active collections via pubsub" do
    socket = active_collection_socket()
    [%{function: callback}] = socket.private.lifecycle.handle_event
    [%{function: info_callback}] = socket.private.lifecycle.handle_info

    {:halt, reply, socket} =
      callback.("students.create", %{"name" => "Buy no refresh"}, socket)

    assert reply.ok == true
    assert %{name: "Buy no refresh"} = reply.data

    {:halt, final_socket} =
      info_callback.(
        %Ash.Notifier.Notification{
          resource: TestResource,
          action: %{name: :create},
          data: reply.data
        },
        socket
      )

    assert [{_dom_id, 0, %{name: "Buy no refresh"}, -10, false}] =
             stream_inserts(final_socket, :sales_orders)

    refute Map.has_key?(final_socket.assigns, :sales_orders)
  end

  test "successful update commands update active collection items via pubsub" do
    student = create_student!("Before Rename")
    socket = active_collection_socket()
    [%{function: callback}] = socket.private.lifecycle.handle_event
    [%{function: info_callback}] = socket.private.lifecycle.handle_info

    {:halt, reply, socket} =
      callback.("students.rename", %{"id" => student.id, "name" => "After Rename"}, socket)

    assert reply.ok == true

    {:halt, final_socket} =
      info_callback.(
        %Ash.Notifier.Notification{
          resource: TestResource,
          action: %{name: :rename},
          data: reply.data
        },
        socket
      )

    assert Enum.any?(stream_inserts(final_socket, :sales_orders), fn
             {_dom_id, -1, %{id: id, name: "After Rename"}, nil, true} ->
               id == student.id

             _other ->
               false
           end)
  end

  test "successful destroy commands remove active collection items via pubsub" do
    student = create_student!("Destroy Me")
    socket = active_collection_socket()
    [%{function: callback}] = socket.private.lifecycle.handle_event
    [%{function: info_callback}] = socket.private.lifecycle.handle_info

    {:halt, reply, socket} =
      callback.("students.destroy", %{"id" => student.id}, socket)

    assert reply.ok == true

    {:halt, final_socket} =
      info_callback.(
        %Ash.Notifier.Notification{
          resource: TestResource,
          action: %{name: :destroy},
          data: reply.data
        },
        socket
      )

    assert ["sales_orders-#{student.id}"] == stream_deletes(final_socket, :sales_orders)
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

  test "declared page_events halt with callback replies and socket updates" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{page_events: [{"page.echo", :echo_page_event}]},
        %{},
        %{},
        base_socket(view: PageEventLive)
      )

    [%{function: callback}] = socket.private.lifecycle.handle_event

    assert {:halt, %{ok: true, data: %{name: "Ada"}}, final_socket} =
             callback.("page.echo", %{"name" => "Ada"}, socket)

    assert final_socket.assigns.echoed_name == "Ada"
  end

  test "page_events fail loudly when callbacks do not return reply tuples" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{page_events: [{"page.invalid", :invalid_page_event}]},
        %{},
        %{},
        base_socket(view: PageEventLive)
      )

    [%{function: callback}] = socket.private.lifecycle.handle_event

    assert_raise ArgumentError,
                 ~r/page event "page.invalid" callback :invalid_page_event must return \{:reply, map, socket\}/,
                 fn ->
                   callback.("page.invalid", %{}, socket)
                 end
  end

  test "page_state derives assigns during mount and route lifecycle changes" do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{page_state: :support_page_state},
        %{"conversation_id" => "conv-1", "customer_name" => "Ada"},
        %{},
        base_socket(view: PageStateLive, router: Router)
      )

    assert socket.assigns.active_conversation_id == "conv-1"
    assert socket.assigns.connected_customer_name == "Ada"

    [%{function: callback}] = socket.private.lifecycle.handle_params

    assert {:cont, socket} =
             callback.(
               %{"conversation_id" => "conv-2", "customer_name" => "Grace"},
               "/support?conversation_id=conv-2&customer_name=Grace",
               socket
             )

    assert socket.assigns.active_conversation_id == "conv-2"
    assert socket.assigns.connected_customer_name == "Grace"
  end

  test "page_state fails loudly when callbacks do not return maps" do
    assert_raise ArgumentError,
                 ~r/page_state callback :invalid_page_state must return a map/,
                 fn ->
                   Alva.LiveView.on_mount(
                     %{page_state: :invalid_page_state},
                     %{},
                     %{},
                     base_socket(view: PageStateLive)
                   )
                 end
  end

  test "internal upload lifecycle events halt in Alva without page handlers" do
    {:cont, socket} = Alva.LiveView.on_mount(%{}, %{}, %{}, base_socket())
    [%{function: callback}] = socket.private.lifecycle.handle_event

    assert {:halt, ^socket} = callback.("alva.validate_upload", %{}, socket)
    assert {:halt, ^socket} = callback.("alva.save_upload", %{}, socket)
  end

  test "signal-only delivery does not mutate a route collection" do
    socket =
      %Phoenix.LiveView.Socket{
        endpoint: Alva.LiveViewTest.Endpoint,
        assigns: %{__changed__: %{}},
        private: %{
          lifecycle: %Phoenix.LiveView.Lifecycle{},
          live_temp: %{push_events: []}
        }
      }
      |> then(fn socket ->
        {:cont, socket} = Alva.LiveView.on_mount(%{}, %{}, %{}, socket)
        socket
      end)
      |> Alva.LiveView.collection(:other_students)
      |> Alva.LiveView.activate_signal(:students_created)

    [%{function: callback}] = socket.private.lifecycle.handle_info

    {:halt, final_socket} = callback.(student_created_notification(), socket)

    assert [["students.created", %{id: "123", name: "test"}]] =
             final_socket.private.live_temp.push_events

    assert stream_items(final_socket, :other_students) == []
  end

  test "the same occurrence can update a collection and push a signal when both are active" do
    socket =
      active_students_collection_socket()
      |> Alva.LiveView.activate_signal(:students_created)

    [%{function: callback}] = socket.private.lifecycle.handle_info

    {:halt, final_socket} = callback.(student_created_notification(), socket)

    assert [["students.created", %{id: "123", name: "test"}]] =
             final_socket.private.live_temp.push_events

    assert [%{id: "123", name: "test"}] = stream_items(final_socket, :students)
  end

  test "handle_info inserts matching active collection notifications into the route collection" do
    {:halt, final_socket} =
      students_collection_callback().(
        student_created_notification(),
        active_students_collection_socket()
      )

    assert [%{id: "123", name: "test"}] = stream_items(final_socket, :students)
  end

  test "handle_info updates matching active collection notifications through stream_insert" do
    {:halt, final_socket} =
      students_collection_callback().(
        student_updated_notification(),
        active_students_collection_socket()
      )

    assert [{_dom_id, -1, %{id: "123", name: "renamed"}, nil, true}] =
             stream_inserts(final_socket, :students)
  end

  test "handle_info deletes matching active collection notifications from the route collection" do
    {:halt, final_socket} =
      students_collection_callback().(
        student_deleted_notification(),
        active_students_collection_socket()
      )

    assert ["students-123"] = stream_deletes(final_socket, :students)
  end

  test "two activated pages receive the same collection update through the collection path" do
    callback = students_collection_callback()
    page_one = active_students_collection_socket()
    page_two = active_students_collection_socket()
    notification = student_created_notification()

    {:halt, page_one} = callback.(notification, page_one)
    {:halt, page_two} = callback.(notification, page_two)

    assert [%{id: "123", name: "test"}] = stream_items(page_one, :students)

    assert [%{id: "123", name: "test"}] = stream_items(page_two, :students)
  end

  test "handle_info accepts Phoenix PubSub broadcasts carrying Ash.Notifier.Notification payloads" do
    socket = active_students_collection_socket()
    [%{function: callback}] = socket.private.lifecycle.handle_info

    broadcast = %Phoenix.Socket.Broadcast{
      topic: "students",
      event: "student_created",
      payload: student_created_notification()
    }

    {:halt, final_socket} = callback.(broadcast, socket)

    assert [%{id: "123", name: "test"}] = stream_items(final_socket, :students)
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
        %{},
        %{},
        %{},
        %Phoenix.LiveView.Socket{
          endpoint: Alva.LiveViewTest.Endpoint,
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
    endpoint =
      case Keyword.fetch(opts, :endpoint) do
        {:ok, endpoint} -> endpoint
        :error -> Alva.LiveViewTest.Endpoint
      end

    %Phoenix.LiveView.Socket{
      endpoint: endpoint,
      router: Keyword.get(opts, :router),
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

  defp active_students_collection_socket do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{},
        %{},
        %{},
        %Phoenix.LiveView.Socket{
          endpoint: Alva.LiveViewTest.Endpoint,
          assigns: %{__changed__: %{}},
          private: %{
            lifecycle: %Phoenix.LiveView.Lifecycle{},
            live_temp: %{push_events: []}
          }
        }
      )

    Alva.LiveView.collection(socket, :students)
  end

  defp active_collection_socket do
    {:cont, socket} =
      Alva.LiveView.on_mount(
        %{},
        %{},
        %{},
        %Phoenix.LiveView.Socket{
          endpoint: Alva.LiveViewTest.Endpoint,
          assigns: %{__changed__: %{}},
          private: %{
            lifecycle: %Phoenix.LiveView.Lifecycle{},
            live_temp: %{push_events: []}
          }
        }
      )

    Alva.LiveView.collection(socket, :sales_orders)
  end

  defp students_collection_callback do
    socket = active_students_collection_socket()
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

  defp drain_dispatch_events do
    receive do
      {:dispatch_seen, _event_name, _params} -> drain_dispatch_events()
    after
      0 -> :ok
    end
  end

  defp active_collection_source_input(socket, name) do
    socket.private
    |> Map.fetch!(:alva)
    |> Map.fetch!(:collection_source_inputs)
    |> Map.fetch!(name)
  end

  defp push_job_signal(data) do
    socket = %Phoenix.LiveView.Socket{
      endpoint: Alva.LiveViewTest.Endpoint,
      assigns: %{__changed__: %{}},
      private: %{
        lifecycle: %Phoenix.LiveView.Lifecycle{},
        live_temp: %{push_events: []}
      }
    }

    {:cont, socket} = Alva.LiveView.on_mount(%{}, %{}, %{}, socket)
    socket = Alva.LiveView.activate_signal(socket, :jobs_completed)

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

  defp create_shared_primary!(name) do
    Ash.create!(Ash.Changeset.for_create(SharedKeyPrimaryResource, :create, %{name: name}))
  end

  defp create_shared_secondary!(name) do
    Ash.create!(Ash.Changeset.for_create(SharedKeySecondaryResource, :create, %{name: name}))
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
