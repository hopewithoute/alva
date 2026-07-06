defmodule AlvaDemoWeb.CustomerStorefrontLiveTest do
  use AlvaDemoWeb.ConnCase
  alias LiveVue.Test, as: LiveVueTest
  import Phoenix.LiveViewTest

  test "mounts into the persistent layout and sets up collections", %{conn: conn} do
    product =
      Ash.Seed.seed!(%AlvaDemo.Catalog.Product{
        name: "Test Product",
        price: 1000,
        description: "Test",
        stock: 10
      })

    {:ok, page_live, disconnected_html} = live(conn, "/storefront")

    assert disconnected_html =~ ~s(data-name="AppLayout")
    assert disconnected_html =~ ~s(id="customer-storefront-page")
    assert disconnected_html =~ ~s(data-name="CustomerStorefrontPage")
    assert disconnected_html =~ ~s(data-inject="layout")
    assert render(page_live) =~ "CustomerStorefrontPage"
    assert render(page_live) =~ "Test Product"

    html =
      render_hook(page_live, "sales.create_order", %{
        "customer_name" => "Storefront Buyer",
        "product_id" => product.id,
        "quantity" => 1
      })

    assert render(page_live) =~ "Storefront Buyer"

    vue = LiveVueTest.get_vue(html, id: "customer-storefront-page")

    assert Enum.any?(vue.streams_diff, fn
             [
               "upsert",
               path,
               %{"customer_name" => "Storefront Buyer", "lifecycle_status" => "new"}
             ] ->
               path =~ "/sales_orders/"

             _ ->
               false
           end)
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
