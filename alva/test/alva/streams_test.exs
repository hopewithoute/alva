defmodule Alva.StreamsTest do
  use ExUnit.Case

  alias Alva.LiveView.Streams

  defmodule MockEndpoint do
    def config(:otp_app), do: :alva
    def config(:pubsub_server), do: Alva.TestPubSub
  end

  defmodule TestResource do
    use Ash.Resource,
      domain: Alva.StreamsTest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      notifiers: [Ash.Notifier.PubSub],
      validate_domain_inclusion?: false

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
      attribute :status, :atom, public?: true, default: :open
    end

    actions do
      defaults [:read, :destroy]

      create :create do
        primary? true
        accept [:name, :status]
      end

      update :update do
        primary? true
        accept [:name, :status]
      end

      read :open_items do
        primary? false
        filter expr(status == :open)
      end
    end
  end

  defmodule TestDomain do
    use Ash.Domain,
      validate_config_inclusion?: false

    resources do
      resource Alva.StreamsTest.TestResource
    end
  end

  setup_all do
    start_supervised!({Phoenix.PubSub, name: Alva.TestPubSub})
    Application.put_env(:alva, :ash_domains, [Alva.StreamsTest.TestDomain])

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
        live_temp: %{},
        alva: %{
          otp_app: :alva
        }
      }
    }

    %{socket: socket}
  end

  describe "record_in_scope?/3" do
    test "returns true when record is in scope and false when out of scope", %{socket: socket} do
      open_rec =
        Ash.create!(
          Ash.Changeset.for_create(TestResource, :create, %{name: "Item 1", status: :open})
        )

      closed_rec =
        Ash.create!(
          Ash.Changeset.for_create(TestResource, :create, %{name: "Item 2", status: :closed})
        )

      stream_meta = %{
        resource: TestResource,
        source: :open_items,
        scope: %{},
        scope_args: %{},
        sync_on: [:update]
      }

      # open_rec has status: :open -> in scope
      assert Streams.record_in_scope?(socket, stream_meta, open_rec) == true

      # closed_rec has status: :closed -> out of scope
      assert Streams.record_in_scope?(socket, stream_meta, closed_rec) == false
    end
  end
end
