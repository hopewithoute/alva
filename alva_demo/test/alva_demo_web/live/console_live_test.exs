defmodule AlvaDemoWeb.MerchantConsoleLiveTest do
  use AlvaDemoWeb.ConnCase
  alias LiveVue.Test, as: LiveVueTest
  import Phoenix.LiveViewTest

  test "mounts into the persistent layout and sets up collections", %{conn: conn} do
    product =
      Ash.Seed.seed!(%AlvaDemo.Catalog.Product{
        name: "Test Console Product",
        price: 2500,
        description: "Test",
        stock: 10
      })

    Ash.Seed.seed!(%AlvaDemo.Sales.Order{
      customer_name: "Console Buyer",
      product_id: product.id,
      quantity: 1
    })

    Ash.Seed.seed!(%AlvaDemo.Support.Conversation{
      customer_name: "Console Chat"
    })

    {:ok, page_live, disconnected_html} = live(conn, "/console")

    assert disconnected_html =~ ~s(data-name="AppLayout")
    assert disconnected_html =~ ~s(id="merchant-console-page")
    assert disconnected_html =~ ~s(data-name="MerchantConsolePage")
    assert disconnected_html =~ ~s(data-inject="layout")
    assert render(page_live) =~ "Test Console Product"
    assert render(page_live) =~ "Console Buyer"
    assert render(page_live) =~ "Console Chat"
  end

  test "adjusting stock does not reset the products stream", %{conn: conn} do
    product =
      Ash.Seed.seed!(%AlvaDemo.Catalog.Product{
        name: "Reset Guard Product",
        price: 1500,
        description: "Test",
        stock: 10
      })

    {:ok, page_live, _html} = live(conn, "/console")

    html =
      render_hook(page_live, "catalog.adjust_stock", %{
        "id" => product.id,
        "stock" => 25
      })

    vue = LiveVueTest.get_vue(html, id: "merchant-console-page")

    refute Enum.any?(vue.streams_diff, fn
             ["replace", "/products", []] -> true
             _ -> false
           end)

    assert Enum.any?(vue.streams_diff, fn
             ["replace", path, %{"stock" => 25}] ->
               path == "/products/$$products-#{product.id}"

             _ ->
               false
           end)
  end

  test "passes the live upload config into the merchant console page", %{conn: conn} do
    {:ok, _page_live, html} = live(conn, "/console")

    vue = LiveVueTest.get_vue(html, id: "merchant-console-page")

    assert %{
             "name" => "media",
             "ref" => ref,
             "max_entries" => 1,
             "auto_upload" => true
           } = vue.props["media"]

    assert is_binary(ref)
    refute ref == "dummy-ref"
  end

  test "accepts LiveView upload lifecycle events without crashing" do
    socket = %Phoenix.LiveView.Socket{assigns: %{}, private: %{}}

    assert {:noreply, ^socket} =
             AlvaDemoWeb.MerchantConsoleLive.handle_event("validate_upload", %{}, socket)

    assert {:noreply, ^socket} =
             AlvaDemoWeb.MerchantConsoleLive.handle_event("save_upload", %{}, socket)
  end

  test "merchant console advances the order lifecycle through the route stream", %{
    conn: conn
  } do
    product =
      Ash.Seed.seed!(%AlvaDemo.Catalog.Product{
        name: "Lifecycle Product",
        price: 1800,
        description: "Test",
        stock: 8
      })

    order =
      Ash.Seed.seed!(%AlvaDemo.Sales.Order{
        customer_name: "Lifecycle Buyer",
        product_id: product.id,
        quantity: 1
      })

    {:ok, page_live, _html} = live(conn, "/console")

    processing_html =
      render_hook(page_live, "sales.begin_processing", %{
        "id" => order.id
      })

    processing_vue = LiveVueTest.get_vue(processing_html, id: "merchant-console-page")

    assert Enum.any?(processing_vue.streams_diff, fn
             ["replace", path, %{"id" => id, "lifecycle_status" => "processing"}] ->
               path == "/sales_orders/$$sales_orders-#{order.id}" and id == order.id

             _ ->
               false
           end)

    fulfill_html =
      render_hook(page_live, "sales.fulfill", %{
        "id" => order.id
      })

    fulfill_vue = LiveVueTest.get_vue(fulfill_html, id: "merchant-console-page")

    assert Enum.any?(fulfill_vue.streams_diff, fn
             ["replace", path, %{"id" => id, "lifecycle_status" => "fulfilled"}] ->
               path == "/sales_orders/$$sales_orders-#{order.id}" and id == order.id

             _ ->
               false
           end)
  end
end
