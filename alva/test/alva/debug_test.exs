defmodule Alva.DebugTest do
  use ExUnit.Case
  alias Alva.LiveViewTest.TestResource

  test "debug events" do
    assert is_list(Alva.Registry.events(TestResource))
  end
end
