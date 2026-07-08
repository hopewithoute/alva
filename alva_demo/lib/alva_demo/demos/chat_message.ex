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

    subscription :chat_messages do
      name("chat_messages")
      kind(:stream)
      source(event: :demo_chat_list_messages)
      insert(on: :send)
      resolve(:resolve_chat_messages_scope)
    end
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

  def resolve_chat_messages_scope(input, socket) do
    with {:ok, items} <-
           DemoSubscriptions.load_stream_items(socket, "demo_chat.list_messages", input) do
      {:ok,
       %{
         topics: [DemoSubscriptions.notifier_topic(__MODULE__, "created")],
         items: items
       }}
    end
  end
end
