defmodule AlvaDemoWeb.ShowcaseShellTest do
  use AlvaDemoWeb.ConnCase, async: true

  @showcase_live_files Path.wildcard(Path.expand("../../../lib/alva_demo_web/live/*.ex", __DIR__))

  test "root route injects the home page into the persistent LiveVue layout", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ ~s(id="layout")
    assert html =~ ~s(data-name="AppLayout")
    assert html =~ ~s(id="home-page")
    assert html =~ ~s(data-name="HomePage")
    assert html =~ ~s(data-inject="layout")
  end

  test "Customer Storefront route injects the LiveVue host page into the persistent layout", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, ~p"/storefront")

    assert html =~ ~s(id="layout")
    assert html =~ ~s(data-name="AppLayout")
    assert html =~ ~s(id="customer-storefront-page")
    assert html =~ "CustomerStorefrontPage"
    assert html =~ ~s(data-inject="layout")
  end

  test "Merchant Console route injects the LiveVue host page into the persistent layout", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, ~p"/console")

    assert html =~ ~s(id="layout")
    assert html =~ ~s(data-name="AppLayout")
    assert html =~ ~s(id="merchant-console-page")
    assert html =~ "MerchantConsolePage"
    assert html =~ ~s(data-inject="layout")
  end

  test "Chat demo route injects the LiveVue host page into the persistent layout", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/demo/chat")

    assert html =~ ~s(id="layout")
    assert html =~ ~s(data-name="AppLayout")
    assert html =~ ~s(id="demo-chat-page")
    assert html =~ "DemoChatPage"
    assert html =~ ~s(data-inject="layout")
  end

  test "Notifications demo route injects the LiveVue host page into the persistent layout", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, ~p"/demo/notifications")

    assert html =~ ~s(id="layout")
    assert html =~ ~s(data-name="AppLayout")
    assert html =~ ~s(id="demo-notifications-page")
    assert html =~ "DemoNotificationsPage"
    assert html =~ ~s(data-inject="layout")
  end

  test "Load more demo route injects the LiveVue host page into the persistent layout", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, ~p"/demo/load-more")

    assert html =~ ~s(id="layout")
    assert html =~ ~s(data-name="AppLayout")
    assert html =~ ~s(id="demo-load-more-page")
    assert html =~ "DemoLoadMorePage"
    assert html =~ ~s(data-inject="layout")
  end

  test "showcase LiveViews do not reintroduce legacy declarative activation shapes" do
    Enum.each(@showcase_live_files, fn path ->
      content = File.read!(path)

      refute Regex.match?(~r/(^|\s)streams:\s/m, content),
             "#{Path.basename(path)} still uses legacy declarative streams:"

      refute Regex.match?(~r/(^|\s)subscriptions:\s/m, content),
             "#{Path.basename(path)} still uses legacy declarative subscriptions:"

      refute Regex.match?(~r/(^|\s)params:\s/m, content),
             "#{Path.basename(path)} still uses nested params: instead of source_input:"
    end)
  end
end
