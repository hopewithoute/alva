defmodule AlvaDemo.Support do
  use Ash.Domain

  resources do
    resource(AlvaDemo.Support.Conversation)
    resource(AlvaDemo.Support.SupportMessage)
  end
end
