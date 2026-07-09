defmodule AlvaDemo.Demos.ChatMessage do
  alias AlvaDemo.Subscriptions, as: DemoSubscriptions

  use Ash.Resource,
    domain: AlvaDemo.Demos,
    data_layer: Ash.DataLayer.Ets,
    notifiers: [Ash.Notifier.PubSub],
    extensions: [Alva.Resource]

  pub_sub do
    module(AlvaDemoWeb.Endpoint)
    prefix("demo_chat")
    publish(:send, ["created"])
  end

  live_vue do
    event(:demo_chat_list_messages, name: "demo_chat.list_messages", action: :list)
    event(:demo_chat_send_message, name: "demo_chat.send_message", action: :send)
  end

  actions do
    defaults([:destroy])

    read :read do
      primary?(true)
      public?(true)
    end

    read :list do
      public?(true)

      prepare(fn query, _context ->
        Ash.Query.sort(query, created_at: :asc)
      end)
    end

    create :send do
      public?(true)
      primary?(true)
      accept([:author, :text])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :author, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :text, :string do
      allow_nil?(false)
      public?(true)
    end

    create_timestamp :created_at do
      public?(true)
    end
  end
end
