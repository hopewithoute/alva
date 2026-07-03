defmodule Alva.LiveViewTest do
  use ExUnit.Case
  import Phoenix.LiveViewTest

  @endpoint Alva.LiveViewTest.Endpoint

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :alva
    plug Plug.Session, store: :cookie, key: "_alva_key", signing_salt: "whatever123"
  end

  defmodule TestResource do
    use Ash.Resource,
      domain: Alva.LiveViewTest.TestDomain,
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
      create :upload_file do
        argument :file, Ash.Type.File, allow_nil?: false
        accept []
      end
    end

    live_vue do
      event "upload", action: :upload_file
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
      resource TestResource
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

  test "handle_info pushes Ash.Notifier.Notification" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}}, 
      private: %{
        lifecycle: %Phoenix.LiveView.Lifecycle{},
        live_temp: %{push_events: []}
      }
    }
    {:cont, socket} = Alva.LiveView.on_mount([Alva.LiveViewTest.TestDomain], %{}, %{}, socket)

    [%{function: callback}] = socket.private.lifecycle.handle_info
    
    notification = %Ash.Notifier.Notification{
      resource: TestResource,
      action: %{name: :upload_file},
      data: %TestResource{id: "123", name: "test"}
    }
    
    {:halt, final_socket} = callback.(notification, socket)
    
    events_str = inspect(final_socket.private.live_temp.push_events)
    assert events_str =~ "ash_notification"
    assert events_str =~ "upload_file"
    assert events_str =~ "123"
  end
end
