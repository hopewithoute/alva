defmodule AlvaDemoWeb.CustomerStorefrontLiveTest do
  use AlvaDemoWeb.ConnCase
  import Phoenix.LiveViewTest

  test "mounts and sets up data sync", %{conn: conn} do
    Ash.Seed.seed!(%AlvaDemo.Catalog.Product{
      name: "Test Product",
      price: 1000,
      description: "Test",
      stock: 10
    })

    {:ok, page_live, disconnected_html} = live(conn, "/storefront")

    assert disconnected_html =~ "Customer Storefront"
    assert render(page_live) =~ "CustomerStorefrontPage"
  end
end
