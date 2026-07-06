defmodule AlvaDemo.Demos do
  use Ash.Domain,
    extensions: [Alva.Domain]

  resources do
    resource(AlvaDemo.Demos.ChatMessage)
    resource(AlvaDemo.Demos.Notification)
    resource(AlvaDemo.Demos.FeedEntry)
  end
end
