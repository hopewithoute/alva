defmodule AlvaDemo.Academics.Student do
  use Ash.Resource,
    domain: AlvaDemo.Academics,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "students"
    repo AlvaDemo.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name]
    end
  end

  code_interface do
    domain AlvaDemo.Academics
    define :read
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false, public?: true
    
    attribute :status, :atom do
      constraints [one_of: [:active, :archived]]
      default :active
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
