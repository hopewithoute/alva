defmodule AlvaDemo.Academics.Student do
  use Ash.Resource,
    domain: AlvaDemo.Academics,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "students"
    repo AlvaDemo.Repo
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false
    
    attribute :status, :atom do
      constraints [one_of: [:active, :archived]]
      default :active
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
