defmodule AlvaDemo.Support.SupportMessage do
  use Ash.Resource,
    domain: AlvaDemo.Support,
    data_layer: Ash.DataLayer.Ets,
    notifiers: [Ash.Notifier.PubSub],
    extensions: [Alva.Resource]

  pub_sub do
    module(AlvaDemoWeb.Endpoint)
    prefix("support_message")
    publish(:create, ["created"])
  end

  live_vue do
    event("support.list_messages", action: :read_for_conversation)
    event("support.send_message", action: :create)

    # Message history is scoped by the conversation selected in Vue, so it stays
    # command-driven. Live messages stream through props and are filtered by the
    # active conversation on each chat surface.
    stream :support_messages do
      insert(on: "create")
    end
  end

  actions do
    defaults([:destroy])

    read :read do
      primary?(true)
      public?(true)
    end

    read :read_for_conversation do
      public?(true)
      argument(:conversation_id, :uuid, allow_nil?: false)
      filter(expr(conversation_id == ^arg(:conversation_id)))
    end

    create :create do
      public?(true)
      primary?(true)
      accept([:text, :sender, :conversation_id])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :text, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :sender, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:shopper, :merchant])
    end

    # We add created_at to help with sorting if needed, though ETS preserves order
    create_timestamp :created_at do
      public?(true)
    end
  end

  relationships do
    belongs_to :conversation, AlvaDemo.Support.Conversation do
      allow_nil?(false)
      public?(true)
    end
  end
end
