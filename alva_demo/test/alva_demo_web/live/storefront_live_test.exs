defmodule AlvaDemoWeb.CustomerStorefrontLiveTest do
  use AlvaDemoWeb.ConnCase
  alias LiveVue.Test, as: LiveVueTest
  import Phoenix.LiveViewTest

  test "mounts into the persistent layout and sends eager stream payloads", %{conn: conn} do
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

    disconnected_vue = LiveVueTest.get_vue(disconnected_html, id: "customer-storefront-page")

    assert_stream_reset(disconnected_vue, "sales_orders")
    assert_stream_contains(disconnected_vue, "products", %{"name" => "Test Product", "stock" => 10})
    assert_stream_reset(disconnected_vue, "support_messages")

    _html =
      render_hook(page_live, "sales.create_order", %{
        "customer_name" => "Storefront Buyer",
        "product_id" => product.id,
        "quantity" => 1
      })
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

    storefront_vue = LiveVueTest.get_vue(render(storefront_live), id: "customer-storefront-page")
    console_vue = LiveVueTest.get_vue(render(console_live), id: "merchant-console-page")

    assert_stream_contains(storefront_vue, "sales_orders", %{
      "customer_name" => "Cross Window Buyer",
      "lifecycle_status" => "new"
    })

    assert_stream_contains(console_vue, "sales_orders", %{
      "customer_name" => "Cross Window Buyer",
      "lifecycle_status" => "new"
    })
  end

  test "route params scope support chat history for the storefront surface", %{conn: conn} do
    conversation =
      Ash.Seed.seed!(%AlvaDemo.Support.Conversation{
        customer_name: "Storefront Chat"
      })

    Ash.Seed.seed!(%AlvaDemo.Support.SupportMessage{
      conversation_id: conversation.id,
      sender: :merchant,
      text: "Storefront history"
    })

    {:ok, page_live, _html} =
      live(conn, "/storefront?customer_name=#{conversation.customer_name}&conversation_id=#{conversation.id}")

    vue = LiveVueTest.get_vue(render(page_live), id: "customer-storefront-page")

    assert vue.props["connected_customer_name"] == conversation.customer_name
    assert vue.props["active_conversation_id"] == conversation.id
    assert_stream_contains(vue, "support_messages", %{"text" => "Storefront history"})
  end

  defp assert_stream_reset(vue, stream_name) do
    assert Enum.any?(vue.streams_diff, fn
             ["replace", path, []] -> path == "/#{stream_name}"
             _ -> false
           end)
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
