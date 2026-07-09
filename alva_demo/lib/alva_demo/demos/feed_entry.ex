defmodule AlvaDemo.Demos.FeedEntry do

  use Ash.Resource,
    domain: AlvaDemo.Demos,
    data_layer: Ash.DataLayer.Ets,
    extensions: [Alva.Resource]

  live_vue do
    event(:demo_feed_list_entries, name: "demo_feed.list_entries", action: :list)
  end

  actions do
    defaults([:destroy])

    read :read do
      primary?(true)
      public?(true)
    end

    read :list do
      public?(true)
      argument(:page_limit, :integer, allow_nil?: true)

      prepare(fn query, _context ->
        limit = Ash.Query.get_argument(query, :page_limit) || 5

        query
        |> Ash.Query.sort(position: :asc)
        |> Ash.Query.limit(limit)
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
