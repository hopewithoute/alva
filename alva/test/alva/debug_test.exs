defmodule Alva.DebugTest do
  use ExUnit.Case
  alias Alva.LiveViewTest.TestResource

  test "debug events" do
    IO.inspect(Alva.Registry.events(TestResource))
  end
end
