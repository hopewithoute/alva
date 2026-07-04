defmodule AlvaDemoWeb.ShowcaseShellTest do
  use AlvaDemoWeb.ConnCase, async: true

  test "root route links to the Customer Storefront and Merchant Console", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "commerce-showcase-entry"
    assert html =~ "Customer Storefront"
    assert html =~ "Merchant Console"
    assert html =~ ~s(href="/shop")
    assert html =~ ~s(href="/console")
  end

  test "Customer Storefront route renders the LiveVue host page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/shop")

    assert html =~ "customer-storefront"
    assert html =~ "Customer Storefront"
    assert html =~ "CustomerStorefrontPage"
  end

  test "Merchant Console route renders the LiveVue host page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/console")

    assert html =~ "merchant-console"
    assert html =~ "Merchant Console"
    assert html =~ "MerchantConsolePage"
  end
end
