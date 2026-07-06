defmodule AlvaDemo.Demos.FeedEntry do
  use Ash.Resource,
    domain: AlvaDemo.Demos,
    data_layer: Ash.DataLayer.Ets,
    extensions: [Alva.Resource]

  live_vue do
    event(:demo_feed_list_entries, name: "demo_feed.list_entries", action: :list)

    collection :feed_entries do
      source(event: :demo_feed_list_entries, mode: :reset)
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
      pagination(offset?: true, required?: false)

      prepare(fn query, _context ->
        Ash.Query.sort(query, position: :asc)
      end)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :title, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :summary, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :position, :integer do
      allow_nil?(false)
      public?(true)
    end
  end
end
