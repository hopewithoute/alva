defmodule AlvaDemo.Communication.Message do
  use Ash.Resource,
    domain: AlvaDemo.Communication,
    data_layer: AshPostgres.DataLayer,
    extensions: [Alva.Resource, Ash.Notifier.PubSub]

  postgres do
    table "messages"
    repo AlvaDemo.Repo
  end

  pub_sub do
    module AlvaDemoWeb.Endpoint
    prefix "messages"

    publish :create, ["all"], event: "message_created"
  end

  live_vue do
    event "messages.list", action: :read
    event "messages.create", action: :create

    stream :messages do
      insert on: "message_created"
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [:content, :username]
    end
  end

  code_interface do
    domain AlvaDemo.Communication
    define :read
    define :create
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string, allow_nil?: false, public?: true
    attribute :username, :string, allow_nil?: false, public?: true

    create_timestamp :inserted_at, public?: true
  end
end
