defmodule Alva.LiveView do
  @moduledoc since: "0.1.0"
  @moduledoc """
  A macro to inject Alva-specific functionality into Phoenix LiveViews.

  The Alva frontend SDK communicates over WebSockets directly to your Phoenix LiveView 
  instances. To handle this routing and seamlessly sync data, you must inject the 
  `Alva.LiveView` module into your LiveView definitions.

  ## Integrating `Alva.LiveView`

  In your `LiveView` module, simply `use Alva.LiveView` and define your stream 
  synchronizations and uploads.

  ```elixir
  defmodule MyAppWeb.StorefrontLive do
    use MyAppWeb, :live_view

    # 1. Mount Alva into the LiveView process
    use Alva.LiveView,
      # Configure auto-syncing streams
      streams: [
        products: [
          # `resource`: The full module name of the Ash Resource
          resource: MyApp.Catalog.Product,
          # `source`: The name of a `:read` action defined in that resource to fetch the stream
          source: :list,
          # `scope`: Arguments to pass to the `:read` action. (Empty means no arguments)
          scope: %{},
          # `sync_on`: A list of mutation action names in the resource that will trigger a stream refresh
          sync_on: [:create, :adjust_stock, :destroy]
        ],
        orders: [
          resource: MyApp.Sales.Order,
          source: :my_orders,
          # A value prefixed with a colon (`:current_user_id`) dynamically pulls from `socket.assigns`
          scope: %{user_id: :current_user_id},
          sync_on: [:create, :fulfill]
        ]
      ],
      # `uploads`: An array of strings that must exactly match the `name` property of an `event` 
      # defined in your Alva.Resource block (e.g., name: "catalog.upload_media").
      # This automatically configures LiveView's `allow_upload/3` for the associated file arguments.
      uploads: ["catalog.upload_media"]

    def handle_params(params, _uri, socket) do
      # 2. Call reconfigure_streams/2 whenever route params change
      # to refresh data across your streams based on new parameters.
      {:noreply, socket |> Alva.LiveView.reconfigure_streams(params)}
    end

    def render(assigns) do
      ~H\"\"\"
      <.vue
        v-component="StorefrontPage"
        v-socket={@socket}
        
        <!-- 3. Pass the streams down to the Vue component -->
        products={Map.get(@streams, :products)}
        orders={Map.get(@streams, :orders)}
        media={@uploads.media}
      />
      \"\"\"
    end
  end
  ```

  ## How It Works

  ### Event Dispatching
  By calling `use Alva.LiveView`, Alva dynamically intercepts incoming events (e.g., 
  from `alva.catalog.create_product()` on the frontend) and routes them directly to 
  the mapped Ash actions without writing any manual `handle_event/3` handlers!

  ### Reactive Streams
  The `streams: [...]` config tells Alva to automatically re-fetch the stream (using 
  the `source` action) whenever a mutation occurs locally or via PubSub (`sync_on`). 

  ### Uploads
  The `uploads: [...]` array automatically configures `allow_upload/3` behind the scenes, 
  linking the upload namespace so `alva.use_upload("catalog.upload_media")` on the frontend 
  works out-of-the-box.
  """

  @public_activation_keys [
    :streams,
    :uploads
  ]

  @err_domains_removed "Alva declarative page activation no longer accepts `domains:`. Prefer `subscriptions:` for the supported V2 path; projection lookup now resolves through the consuming host app registry."

  @err_opts_expected "use Alva.LiveView expects keyword options. The V2 path only accepts `streams:` and `uploads:`. Legacy keys are no longer supported."
  defp err_unsupported_key(key),
    do:
      "Alva declarative page activation only accepts :streams and :uploads on the supported V2 path. Unsupported key: #{inspect(key)}. The V1 legacy keys are removed."

  defmacro __using__(opts) do
    validate_use_opts!(opts, __CALLER__)

    if Keyword.has_key?(opts, :subscriptions) do
      raise CompileError,
        description:
          "The legacy `subscriptions:` DSL is strictly removed. Use `streams:` instead."
    end

    quote do
      import Alva.LiveView
      @alva_streams Keyword.get(unquote(opts), :streams, [])
      @alva_uploads Keyword.get(unquote(opts), :uploads, [])

      on_mount({Alva.LiveView, %{streams: @alva_streams, uploads: @alva_uploads}})
    end
  end

  alias Alva.LiveView.Streams
  alias Alva.LiveView.Sync
  alias Alva.LiveView.Uploads
  alias Alva.LiveView.State

  @doc """
  Reconfigures and re-evaluates active streams for a LiveView process when route parameters change.
  """
  @doc since: "0.1.0"
  @spec reconfigure_streams(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def reconfigure_streams(socket, params \\ %{}) do
    Streams.reconfigure_streams(socket, params)
  end

  @doc false
  @spec on_mount(map() | keyword(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(config, params, _session, socket) do
    streams_config = Map.get(config, :streams, [])
    uploads_config = Map.get(config, :uploads, [])
    socket = Phoenix.LiveView.put_private(socket, :alva_options, streams: streams_config)

    otp_app = host_app_otp_app!(socket)
    registry = Alva.Registry.registry(otp_app)

    socket
    |> setup_initial_alva_state(otp_app, registry)
    |> Streams.configure_streams(streams_config, params, otp_app)
    |> Uploads.configure_file_uploads(uploads_config, otp_app)
    |> Sync.attach_alva_hooks(otp_app)
    |> then(&{:cont, &1})
  end

  defp setup_initial_alva_state(socket, otp_app, registry) do
    State.update(socket, fn state ->
      updates =
        projection_cache(registry)
        |> Map.merge(%{
          otp_app: otp_app,
          domains: registry.domains
        })

      struct!(state, updates)
    end)
  end

  defp host_app_otp_app!(socket) do
    case Alva.Registry.otp_app(socket) do
      otp_app when is_atom(otp_app) and not is_nil(otp_app) ->
        otp_app

      _ ->
        raise ArgumentError,
              "Alva.LiveView requires socket.endpoint to resolve the consuming host app registry. Page-scoped `domains:` activation is no longer supported."
    end
  end

  defp projection_cache(%Alva.Registry{} = registry) do
    %{
      event_map: registry.event_map
    }
  end

  defp validate_use_opts!(opts, caller) when is_list(opts) do
    if Keyword.keyword?(opts) do
      Enum.each(Keyword.keys(opts), &validate_public_activation_key!(&1, caller))

      case Keyword.fetch(opts, :streams) do
        {:ok, streams} -> maybe_validate_stream_use_declarations!(streams, caller)
        :error -> :ok
      end
    else
      raise_compile_error!(caller, @err_opts_expected)
    end
  end

  defp validate_use_opts!(_opts, caller) do
    raise_compile_error!(caller, @err_opts_expected)
  end

  defp maybe_validate_stream_use_declarations!(streams, caller) do
    case expand_use_opt_literal(streams, caller) do
      {:ok, streams} -> validate_stream_use_declarations!(streams, caller)
      :dynamic -> :ok
    end
  end

  defp expand_use_opt_literal(value, caller) do
    expanded = Macro.expand(value, caller)

    if Macro.quoted_literal?(expanded) do
      {:ok, expanded}
    else
      :dynamic
    end
  end

  defp validate_public_activation_key!(:domains, caller) do
    raise_compile_error!(caller, @err_domains_removed)
  end

  defp validate_public_activation_key!(:subscriptions, caller) do
    raise_compile_error!(
      caller,
      "The legacy `subscriptions:` DSL is strictly removed. Use `streams:` instead."
    )
  end

  defp validate_public_activation_key!(key, caller)
       when key in [:collections, :signals, :route_subscriptions, :page_events, :page_state] do
    raise_compile_error!(
      caller,
      "Alva declarative page activation no longer accepts `#{key}:`. For the supported V2 path, use `streams:` and `uploads:`."
    )
  end

  defp validate_public_activation_key!(key, caller) do
    unless key in @public_activation_keys do
      raise_compile_error!(caller, err_unsupported_key(key))
    end
  end

  defp validate_stream_use_declarations!(streams, caller)
       when is_list(streams) do
    keys =
      Enum.map(streams, fn
        key when is_atom(key) ->
          key

        {key, opts} when is_atom(key) and is_list(opts) ->
          validate_stream_use_opts!(key, opts, caller)
          key

        name when is_binary(name) ->
          raise_compile_error!(
            caller,
            "Alva declarative `streams:` entries must use declaration key atoms, got browser-facing name #{inspect(name)}"
          )

        {key, _opts} ->
          raise_compile_error!(
            caller,
            invalid_stream_use_entries_description("Invalid key: #{inspect(key)}")
          )

        other ->
          raise_compile_error!(
            caller,
            invalid_stream_use_entries_description("Got: #{inspect(other)}")
          )
      end)

    validate_unique_activation_names!(keys, :stream, caller)
    keys
  end

  defp validate_stream_use_declarations!(_streams, caller) do
    raise_compile_error!(
      caller,
      "Alva declarative `streams:` must be a list of declaration key atoms or keyword entries."
    )
  end

  defp validate_stream_use_opts!(name, opts, caller) when is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise_compile_error!(caller, invalid_stream_use_opts_description(name))
    end
  end

  defp validate_stream_use_opts!(name, _opts, caller) do
    raise_compile_error!(caller, invalid_stream_use_opts_description(name))
  end

  defp validate_unique_activation_names!(names, kind, caller) do
    names
    |> Enum.frequencies()
    |> Enum.each(fn
      {_name, 1} ->
        :ok

      {name, _count} ->
        raise_compile_error!(
          caller,
          "Alva declarative #{kind} activation contains duplicate entries for #{inspect(name)}."
        )
    end)
  end

  defp invalid_stream_use_entries_description(detail) do
    "Alva declarative `streams:` entries must be atoms or keyword entries like `streams: [sales_orders: [resource: App.Order, source: :list]]`. #{detail}"
  end

  defp invalid_stream_use_opts_description(name) do
    "Alva declarative stream #{inspect(name)} options must be a keyword list containing :resource, :source, etc."
  end

  defp raise_compile_error!(caller, description) do
    raise CompileError,
      file: caller.file,
      line: caller.line,
      description: description
  end
end
