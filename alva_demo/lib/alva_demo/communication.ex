defmodule AlvaDemo.Communication do
  use Ash.Domain

  resources do
    resource AlvaDemo.Communication.Message
    resource AlvaDemo.Communication.Notification
  end
end
