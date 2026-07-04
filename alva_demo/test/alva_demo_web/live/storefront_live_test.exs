defmodule AlvaDemoWeb.CustomerStorefrontLiveTest do
  use AlvaDemoWeb.ConnCase
  import Phoenix.LiveViewTest

  test "mounts and sets up data sync", %{conn: conn} do
    product =
      Ash.Seed.seed!(%AlvaDemo.Catalog.Product{
        name: "Test Product",
        price: 1000,
        description: "Test",
        stock: 10
      })

    {:ok, page_live, disconnected_html} = live(conn, "/storefront")

    assert disconnected_html =~ "Customer Storefront"
    assert render(page_live) =~ "CustomerStorefrontPage"
    assert render(page_live) =~ "Test Product"

    render_hook(page_live, "sales.create_order", %{
      "customer_name" => "Storefront Buyer",
      "product_id" => product.id,
      "quantity" => 1
    })

    assert render(page_live) =~ "Storefront Buyer"
  end

  test "merchant console receives storefront purchases without refresh", %{conn: conn} do
    product =
      Ash.Seed.seed!(%AlvaDemo.Catalog.Product{
        name: "Test Product",
        price: 1000,
        description: "Test",
        stock: 10
      })

    {:ok, storefront_live, _html} = live(conn, "/storefront")
    {:ok, console_live, _html} = live(conn, "/console")

    render_hook(storefront_live, "sales.create_order", %{
      "customer_name" => "Cross Window Buyer",
      "product_id" => product.id,
      "quantity" => 1
    })

    assert render(storefront_live) =~ "Cross Window Buyer"
    assert render(console_live) =~ "Cross Window Buyer"
  end
end
