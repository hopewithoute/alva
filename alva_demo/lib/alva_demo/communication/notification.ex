defmodule AlvaDemo.Communication.Notification do
  use Ash.Resource,
    domain: AlvaDemo.Communication,
    data_layer: AshPostgres.DataLayer,
    extensions: [Alva.Resource, Ash.Notifier.PubSub]

  postgres do
    table "notifications"
    repo AlvaDemo.Repo
  end

  pub_sub do
    module AlvaDemoWeb.Endpoint
    prefix "notifications"

    publish :create, ["all"], event: "notification_created"
  end

  live_vue do
    event "notifications.list", action: :read
    event "notifications.create", action: :create

    signal "notifications.created", on: "notification_created"
  end

  actions do
    defaults [:read]

    create :create do
      accept [:message, :type]
    end
  end

  code_interface do
    domain AlvaDemo.Communication
    define :read
    define :create
  end

  attributes do
    uuid_primary_key :id

    attribute :message, :string, allow_nil?: false, public?: true
    attribute :type, :atom do
      constraints one_of: [:info, :success, :warning, :error]
      default :info
      public? true
    end

    create_timestamp :inserted_at, public?: true
  end
end
