defmodule AlvaDemoWeb.MerchantConsoleLiveTest do
  use AlvaDemoWeb.ConnCase
  import Phoenix.LiveViewTest

  test "mounts and sets up data sync", %{conn: conn} do
    product =
      Ash.Seed.seed!(%AlvaDemo.Catalog.Product{
        name: "Test Console Product",
        price: 2500,
        description: "Test",
        stock: 10
      })

    {:ok, page_live, disconnected_html} = live(conn, "/console")

    assert disconnected_html =~ "Merchant Console"
    assert render(page_live) =~ "Test Console Product"

    Ash.Seed.seed!(%AlvaDemo.Sales.Order{
      customer_name: "Console Buyer",
      product_id: product.id,
      quantity: 1
    })

    Ash.Seed.seed!(%AlvaDemo.Support.Conversation{
      customer_name: "Console Chat"
    })

    assert render_hook(page_live, "catalog.list_products", %{}) =~ "Test Console Product"
    assert render_hook(page_live, "sales.list_orders", %{}) =~ "Console Buyer"
    assert render_hook(page_live, "support.list_conversations", %{}) =~ "Console Chat"
  end
end
