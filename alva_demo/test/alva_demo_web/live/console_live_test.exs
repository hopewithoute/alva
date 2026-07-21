defmodule AlvaDemoWeb.MerchantConsoleLiveTest do
  use AlvaDemoWeb.ConnCase
  alias LiveVue.Test, as: LiveVueTest
  import Phoenix.LiveViewTest

  test "mounts into the persistent layout and sends eager stream payloads", %{conn: conn} do
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

    {:ok, _page_live, disconnected_html} = live(conn, "/console")

    assert disconnected_html =~ ~s(data-name="AppLayout")
    assert disconnected_html =~ ~s(id="merchant-console-page")
    assert disconnected_html =~ ~s(data-name="MerchantConsolePage")
    assert disconnected_html =~ ~s(data-inject="layout")

    vue = LiveVueTest.get_vue(disconnected_html, id: "merchant-console-page")

    assert_stream_contains(vue, "products", %{"name" => "Test Console Product", "stock" => 10})
    assert_stream_contains(vue, "sales_orders", %{"customer_name" => "Console Buyer"})
    assert_stream_contains(vue, "conversations", %{"customer_name" => "Console Chat"})
  end

  test "adjusting stock pushes the updated product through the products stream", %{conn: conn} do
    product =
      Ash.Seed.seed!(%AlvaDemo.Catalog.Product{
        name: "Reset Guard Product",
        price: 1500,
        description: "Test",
        stock: 10
      })

    {:ok, page_live, _html} = live(conn, "/console")

    render_hook(page_live, "catalog.adjust_stock", %{
      "id" => product.id,
      "stock" => 25
    })

    vue = LiveVueTest.get_vue(render(page_live), id: "merchant-console-page")

    assert_stream_contains(vue, "products", %{"id" => product.id, "stock" => 25})
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

    render_hook(page_live, "sales.begin_processing", %{
      "id" => order.id
    })

    processing_vue = LiveVueTest.get_vue(render(page_live), id: "merchant-console-page")

    assert_stream_contains(processing_vue, "sales_orders", %{
      "id" => order.id,
      "lifecycle_status" => "processing"
    })

    render_hook(page_live, "sales.fulfill", %{
      "id" => order.id
    })

    fulfill_vue = LiveVueTest.get_vue(render(page_live), id: "merchant-console-page")

    assert_stream_contains(fulfill_vue, "sales_orders", %{
      "id" => order.id,
      "lifecycle_status" => "fulfilled"
    })
  end

  test "route params scope the active merchant conversation transcript", %{
    conn: conn
  } do
    first_conversation =
      Ash.Seed.seed!(%AlvaDemo.Support.Conversation{
        customer_name: "Waiting Shopper"
      })

    second_conversation =
      Ash.Seed.seed!(%AlvaDemo.Support.Conversation{
        customer_name: "Resolved Shopper"
      })

    Ash.Seed.seed!(%AlvaDemo.Support.SupportMessage{
      conversation_id: first_conversation.id,
      sender: :shopper,
      text: "Waiting history"
    })

    Ash.Seed.seed!(%AlvaDemo.Support.SupportMessage{
      conversation_id: second_conversation.id,
      sender: :merchant,
      text: "Resolved history"
    })

    {:ok, page_live, _html} = live(conn, "/console?conversation_id=#{second_conversation.id}")

    vue = LiveVueTest.get_vue(render(page_live), id: "merchant-console-page")

    assert vue.props["active_conversation_id"] == second_conversation.id
    assert_stream_contains(vue, "support_messages", %{"text" => "Resolved history"})
    refute render(page_live) =~ "Waiting history"
  end

  defp assert_stream_contains(vue, stream_name, expected_subset) do
    assert Enum.any?(vue.streams_diff, fn
             [op, path, value]
             when op in ["upsert", "replace"] and is_map(value) and is_binary(path) ->
               String.starts_with?(path, "/#{stream_name}/") and
                 Enum.all?(expected_subset, fn {key, expected} -> value[key] == expected end)

             _ ->
               false
           end)
  end
end
