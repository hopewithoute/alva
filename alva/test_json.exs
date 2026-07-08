defmodule TestJSON do
  def run do
    record = %{
      id: "123",
      name: "Test",
      __meta__: %{state: :loaded},
      __metadata__: %{custom: "meta"},
      assoc_1: %Ash.NotLoaded{type: :relation, field: :assoc_1}
    }
    
    # Can Jason encode this map? 
    try do
      IO.inspect(Jason.encode!(record))
    rescue
      e -> IO.inspect(e)
    end
  end
end

TestJSON.run()
