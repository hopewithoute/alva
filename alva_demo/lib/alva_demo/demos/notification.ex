defmodule AlvaDemo.Demos.Notification do
  use Ash.Resource,
    domain: AlvaDemo.Demos,
    data_layer: Ash.DataLayer.Ets,
    notifiers: [Ash.Notifier.PubSub],
    extensions: [Alva.Resource]

  pub_sub do
    module(AlvaDemoWeb.Endpoint)
    prefix("demo_notification")
    publish(:send, ["sent"])
  end

  live_vue do
    event("demo_notifications.send", action: :send)

    signal("demo_notifications.sent",
      on: "send"
    )
  end

  actions do
    defaults([:destroy])

    read :read do
      primary?(true)
      public?(true)
    end

    create :send do
      public?(true)
      primary?(true)
      accept([:title, :severity])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :title, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :severity, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:info, :success, :warning])
    end

    create_timestamp :created_at do
      public?(true)
    end
  end
end
