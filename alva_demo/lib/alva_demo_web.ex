defmodule AlvaDemoWeb do
  @moduledoc """
  Entrypoint for the Commerce Showcase web interface.
  """

  def static_paths, do: ~w(assets images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Phoenix.Controller
      import Phoenix.LiveView.Router
      import Plug.Conn
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      on_mount {AlvaDemoWeb.ParamHelpers, :default}

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller, only: [get_csrf_token: 0]
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import LiveVue

      alias AlvaDemoWeb.Layouts
      alias Phoenix.LiveView.JS

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: AlvaDemoWeb.Endpoint,
        router: AlvaDemoWeb.Router,
        statics: AlvaDemoWeb.static_paths()
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
