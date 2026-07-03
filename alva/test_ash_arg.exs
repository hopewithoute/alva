defmodule TestResourceArg do
  use Ash.Resource, domain: nil

  actions do
    action :do_something, :string do
      argument :arg_no_default, :string, allow_nil?: false
      argument :arg_with_default, :string, allow_nil?: false, default: "hello"
      run fn _, _ -> {:ok, "done"} end
    end
  end
end

action = Ash.Resource.Info.action(TestResourceArg, :do_something)
IO.inspect(action.arguments)
