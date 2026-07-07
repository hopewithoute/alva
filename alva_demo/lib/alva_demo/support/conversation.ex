defmodule AlvaDemo.Support.Conversation do
  require Ash.Query

  use Ash.Resource,
    domain: AlvaDemo.Support,
    data_layer: Ash.DataLayer.Ets,
    notifiers: [Ash.Notifier.PubSub],
    extensions: [Alva.Resource]

  pub_sub do
    module(AlvaDemoWeb.Endpoint)
    prefix("conversation")
    publish(:create, ["created"])
    publish(:record_message, ["updated"])
  end

  live_vue do
    event(:support_create, name: "support.create", action: :create)
    event(:support_list_conversations, name: "support.list_conversations", action: :list)
    event(:support_get_conversation, name: "support.get_conversation", action: :get_by_customer)

    collection :conversations do
      source(event: :support_list_conversations, mode: :reset)
      insert(on: :create, at: 0)
      update(on: :record_message, at: 0)
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
      argument(:customer_query, :string, allow_nil?: true)
      argument(:needs_merchant_reply, :boolean, allow_nil?: true)

      prepare(fn query, _context ->
        query
        |> Ash.Query.sort(last_message_at: :desc, customer_name: :asc)
        |> filter_customer_query(Ash.Query.get_argument(query, :customer_query))
        |> filter_needs_reply(Ash.Query.get_argument(query, :needs_merchant_reply))
      end)
    end

    read :get_by_customer do
      public?(true)
      get?(true)
      argument(:customer_name, :string, allow_nil?: false)
      filter(expr(customer_name == ^arg(:customer_name)))
    end

    create :create do
      public?(true)
      primary?(true)
      accept([:customer_name])
      upsert?(true)
      upsert_identity(:unique_customer)
    end

    update :record_message do
      require_atomic?(false)

      accept([
        :last_message_at,
        :last_message_preview,
        :last_message_sender,
        :needs_merchant_reply,
        :message_count
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :customer_name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :last_message_at, :utc_datetime_usec do
      allow_nil?(true)
      public?(true)
    end

    attribute :last_message_preview, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :last_message_sender, :atom do
      allow_nil?(true)
      public?(true)
      constraints(one_of: [:shopper, :merchant])
    end

    attribute :needs_merchant_reply, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
    end

    attribute :message_count, :integer do
      allow_nil?(false)
      default(0)
      public?(true)
    end
  end

  relationships do
    has_many :messages, AlvaDemo.Support.SupportMessage do
      public?(true)
    end
  end

  identities do
    identity(:unique_customer, [:customer_name], pre_check_with: AlvaDemo.Support)
  end

  defp filter_customer_query(query, search_term) do
    case search_pattern(search_term) do
      nil ->
        query

      pattern ->
        require Ash.Expr

        Ash.Query.filter(query, Ash.Expr.expr(contains(customer_name, ^pattern)))
    end
  end

  defp filter_needs_reply(query, nil), do: query

  defp filter_needs_reply(query, needs_reply) do
    require Ash.Expr

    Ash.Query.filter(query, Ash.Expr.expr(needs_merchant_reply == ^needs_reply))
  end

  defp search_pattern(nil), do: nil

  defp search_pattern(search_term) when is_binary(search_term) do
    case String.trim(search_term) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
