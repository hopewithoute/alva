defmodule AlvaDemoWeb.Router do
  use AlvaDemoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AlvaDemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", AlvaDemoWeb do
    pipe_through :browser

    live_session :commerce_showcase do
      live "/", HomeLive
      live "/storefront", CustomerStorefrontLive
      live "/console", MerchantConsoleLive
      live "/docs", DocsLive
      live "/docs/:slug", DocsLive

      # Isolated Realtime Demos
      live "/demo/chat", DemoChatLive
      live "/demo/load-more", DemoLoadMoreLive
      live "/demo/notifications", DemoNotificationsLive
      live "/demo/query-lookup", DemoQueryLookupLive
      live "/demo/optimistic-form", DemoOptimisticFormLive
    end
  end
end
