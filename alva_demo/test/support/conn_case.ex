defmodule AlvaDemoWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint AlvaDemoWeb.Endpoint

      use AlvaDemoWeb, :verified_routes

      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
