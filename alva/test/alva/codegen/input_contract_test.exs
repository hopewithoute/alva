defmodule Alva.Codegen.InputContractTest do
  use ExUnit.Case
  alias Alva.Codegen.InputContract

  defmodule Resource do
    use Ash.Resource, domain: nil

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true, allow_nil?: false
      attribute :age, :integer, public?: true
      attribute :secret, :string, public?: false
    end

    actions do
      defaults [:read]

      create :create do
        accept [:name, :age]
        allow_nil_input [:name]
        argument :tags, {:array, :string}, allow_nil?: true
        argument :role, :string, allow_nil?: false
      end
      
      update :update do
        accept [:name, :age]
        require_attributes [:age]
      end

      action :do_something, :string do
        argument :force, :boolean, allow_nil?: false, default: false
        argument :reason, :string, allow_nil?: false
        run fn input, _ -> {:ok, "done"} end
      end
    end
  end

  test "generates input shape for create action" do
    action = Ash.Resource.Info.action(Resource, :create)
    shape = InputContract.generate_input_shape(Resource, %{}, action)

    # name is accepted, allow_nil false, but in allow_nil_input -> optional
    assert shape =~ "name?: string;"
    # age is accepted, allow_nil true -> optional
    assert shape =~ "age?: number;"
    # tags is argument, allow_nil true -> optional
    assert shape =~ "tags?: string[];"
    # role is argument, allow_nil false -> required
    assert shape =~ "role: string;"
  end

  test "generates input shape for update action" do
    action = Ash.Resource.Info.action(Resource, :update)
    shape = InputContract.generate_input_shape(Resource, %{}, action)

    # update actions usually make all accepted optional, EXCEPT if require_attributes is set
    # age is in require_attributes -> required
    assert shape =~ "age: number;"
    # name is accepted but not required -> optional
    assert shape =~ "name?: string;"
  end

  test "generates input shape for generic action" do
    action = Ash.Resource.Info.action(Resource, :do_something)
    shape = InputContract.generate_input_shape(Resource, %{}, action)

    # force has default, so it's optional
    assert shape =~ "force?: boolean;"
    # reason has no default and allow_nil false -> required
    assert shape =~ "reason: string;"
  end

  test "generates filter property for read action if enable_filter is true" do
    action = Ash.Resource.Info.action(Resource, :read)
    event_def = %{enable_filter: true}
    shape = InputContract.generate_input_shape(Resource, event_def, action)

    assert shape =~ "filter?: Types.AshFilter<Types.Resource>;"
  end
end
