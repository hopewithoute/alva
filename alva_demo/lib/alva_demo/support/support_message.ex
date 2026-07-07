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
    publish(:create, ["conversation", :conversation_id])
  end

  live_vue do
    event(:support_list_messages, name: "support.list_messages", action: :read_for_conversation)
    event(:support_send_message, name: "support.send_message", action: :create)

    collection :support_messages do
      # The page owns conversation scope; Alva owns the canonical transcript.
      source(event: :support_list_messages, mode: :reset)
      insert(on: :create)
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
      argument(:conversation_id, :uuid, allow_nil?: true)

      prepare(fn query, _context ->
        require Ash.Query
        require Ash.Expr

        query =
          case Ash.Query.get_argument(query, :conversation_id) do
            nil ->
              Ash.Query.filter(query, Ash.Expr.expr(false))

            conversation_id ->
              Ash.Query.filter(query, Ash.Expr.expr(conversation_id == ^conversation_id))
          end

        Ash.Query.sort(query, created_at: :asc)
      end)
    end

    create :create do
      public?(true)
      primary?(true)
      accept([:text, :sender, :conversation_id])
      change(AlvaDemo.Support.Changes.SyncConversationSummary)
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
