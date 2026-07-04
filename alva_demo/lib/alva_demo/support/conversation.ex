defmodule AlvaDemo.Support.Conversation do
  use Ash.Resource,
    domain: AlvaDemo.Support,
    data_layer: Ash.DataLayer.Ets,
    notifiers: [Ash.Notifier.PubSub],
    extensions: [Alva.Resource]

  pub_sub do
    module(AlvaDemoWeb.Endpoint)
    prefix("conversation")
    publish(:create, ["created"])
  end

  live_vue do
    event("support.create", action: :create)
    event("support.list_conversations", action: :read)
    event("support.get_conversation", action: :get_by_customer)

    collection :conversations do
      source(event: "support.list_conversations", mode: :reset)
      insert(on: "create")
    end
  end

  actions do
    defaults([:destroy])

    read :read do
      primary?(true)
      public?(true)
    end

    read :get_by_customer do
      public?(true)
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
  end

  attributes do
    uuid_primary_key(:id)

    attribute :customer_name, :string do
      allow_nil?(false)
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
end
