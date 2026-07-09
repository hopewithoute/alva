defmodule AlvaDemo.LiveVueEncoders do
  require Protocol

  [
    AlvaDemo.Catalog.Product,
    AlvaDemo.Sales.Order,
    AlvaDemo.Support.Conversation,
    AlvaDemo.Support.SupportMessage,
    AlvaDemo.Demos.ChatMessage,
    AlvaDemo.Demos.FeedEntry,
    AlvaDemo.Demos.Notification
  ]
  |> Enum.each(fn mod ->
    Protocol.derive(LiveVue.Encoder, mod)
  end)
end

defimpl LiveVue.Encoder, for: Ecto.Schema.Metadata do
  def encode(_struct, _opts), do: %{}
end

defimpl LiveVue.Encoder, for: Ash.NotLoaded do
  def encode(_struct, _opts), do: nil
end

defimpl LiveVue.Encoder, for: Phoenix.LiveView.LiveStream do
  def encode(stream, opts) do
    # Extract items from Phoenix stream inserts list so they can be diffed by LiveVue
    stream.inserts
    |> Enum.map(fn {_dom_id, _index, item, _limit, _update_only} -> item end)
    |> LiveVue.Encoder.encode(opts)
  end
end
