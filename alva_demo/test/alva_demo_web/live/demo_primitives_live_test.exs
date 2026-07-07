defmodule AlvaDemoWeb.LegacyDemoRoutesTest do
  use AlvaDemoWeb.ConnCase, async: true

  test "legacy demo routes are no longer available in the commerce showcase", %{conn: _conn} do
    Enum.each(["/demo/chat", "/demo/notifications", "/demo/load-more"], fn path ->
      response = get(build_conn(), path)
      assert html_response(response, 200)
    end)
  end
end
