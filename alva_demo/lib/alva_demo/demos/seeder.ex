defmodule AlvaDemo.Demos.Seeder do
  alias AlvaDemo.Demos.ChatMessage
  alias AlvaDemo.Demos.FeedEntry

  def seed do
    seed_chat_messages()
    seed_feed_entries()
  end

  defp seed_chat_messages do
    existing_texts =
      ChatMessage
      |> Ash.read!()
      |> Enum.map(& &1.text)
      |> MapSet.new()

    [
      %{author: "Guide", text: "Streams append to both open pages as soon as messages land."},
      %{author: "Teammate", text: "Open this page in two tabs to watch the list stay in sync."}
    ]
    |> Enum.reject(fn attrs -> MapSet.member?(existing_texts, attrs.text) end)
    |> Enum.each(fn attrs ->
      Ash.Seed.seed!(struct(ChatMessage, attrs))
    end)
  end

  defp seed_feed_entries do
    existing_positions =
      FeedEntry
      |> Ash.read!()
      |> Enum.map(& &1.position)
      |> MapSet.new()

    1..12
    |> Enum.reject(&MapSet.member?(existing_positions, &1))
    |> Enum.each(fn position ->
      Ash.Seed.seed!(%FeedEntry{
        position: position,
        title: "Pattern #{position}",
        summary: "Page through a route-owned collection without reintroducing the old bridge."
      })
    end)
  end
end
