defmodule AppTest do
  def run do
    # Assuming Alva.DispatcherTest.TestResource doesn't exist, we just mock a page struct to see how it looks
    page = %Ash.Page.Offset{
      results: [1, 2, 3],
      limit: 10,
      offset: 0,
      count: 3,
      more?: false
    }
    IO.inspect(page)
  end
end
AppTest.run()
