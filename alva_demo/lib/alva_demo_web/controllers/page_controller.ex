defmodule AlvaDemoWeb.PageController do
  use AlvaDemoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
