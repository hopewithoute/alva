defmodule AlvaDemo.Demos.FeedEntry do
  alias AlvaDemo.Subscriptions, as: DemoSubscriptions

  use Ash.Resource,
    domain: AlvaDemo.Demos,
    data_layer: Ash.DataLayer.Ets,
    extensions: [Alva.Resource]

  live_vue do
    event(:demo_feed_list_entries, name: "demo_feed.list_entries", action: :list)

    subscription :feed_entries do
      name("feed_entries")
      kind(:stream)
      source(event: :demo_feed_list_entries)
      scope(%{page: :map, sort: :string})
      resolve(:resolve_feed_entries_scope)
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

  def resolve_feed_entries_scope(input, socket) do
    source_input =
      %{
        "page" => %{"limit" => 5, "offset" => 0},
        "sort" => "position"
      }
      |> DemoSubscriptions.with_defaults(input)

    with {:ok, items} <-
           DemoSubscriptions.load_stream_items(socket, "demo_feed.list_entries", source_input) do
      {:ok, %{topics: [], items: items}}
    end
  end
end
