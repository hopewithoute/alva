defmodule AlvaDemo.Academics.Student do
  use Ash.Resource,
    domain: AlvaDemo.Academics,
    data_layer: AshPostgres.DataLayer,
    extensions: [Alva.Resource, Ash.Notifier.PubSub]

  postgres do
    table "students"
    repo AlvaDemo.Repo
  end

  pub_sub do
    module AlvaDemoWeb.Endpoint
    prefix "students"

    publish :create, ["all"], event: "student_created"
    publish :archive, ["all"], event: "student_archived"
  end

  live_vue do
    event("students.list", action: :read)
    event("students.create", action: :create)
    event("students.archive", action: :archive, lookup: :id)
    event("test.assign", action: :read)

    stream :students do
      insert on: "student_created"
      update on: "student_archived"
    end

    signal "students.created", on: "student_created"
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name]
    end

    update :archive do
      accept []
      change set_attribute(:status, :archived)
    end
  end

  code_interface do
    domain AlvaDemo.Academics
    define :read
    define :create
    define :archive
    define :by_id, action: :read, get_by: [:id]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false, public?: true

    attribute :status, :atom do
      constraints one_of: [:active, :archived]
      default :active
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
