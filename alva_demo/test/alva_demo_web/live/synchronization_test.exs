defmodule AlvaDemoWeb.SynchronizationTest do
  use AlvaDemoWeb.ConnCase
  import Phoenix.LiveViewTest
  alias AlvaDemo.Catalog.Product
  alias AlvaDemo.Sales.Order

  setup do
    product = Ash.Seed.seed!(%Product{
      name: "Sync Test Product",
      description: "Test desc",
      price: 1000,
      stock: 10,
      media_reference: "sync.jpg"
    })
    
    %{product: product}
  end

  test "order updates sync across storefront and merchant console", %{conn: conn, product: product} do
    # Mount both surfaces
    {:ok, storefront_live, _html} = live(conn, "/storefront")
    {:ok, console_live, _html} = live(conn, "/console")

    # Simulate an order created via Ash domain (which triggers pubsub)
    order = 
      Order
      |> Ash.Changeset.for_create(:create, %{
        customer_name: "Sync Shopper", 
        product_id: product.id, 
        quantity: 2
      })
      |> Ash.create!()

    # The LiveViews should receive the stream diffs over PubSub
    # They should now render the new order in their props JSON
    assert render(storefront_live) =~ "Sync Shopper"
    assert render(console_live) =~ "Sync Shopper"

    # Simulate order advancing to processing
    order =
      order
      |> Ash.Changeset.for_update(:begin_processing)
      |> Ash.update!()

    # The views should receive the updated status
    assert render(storefront_live) =~ "processing"
    assert render(console_live) =~ "processing"
    
    # Simulate order fulfillment
    _order =
      order
      |> Ash.Changeset.for_update(:fulfill)
      |> Ash.update!()

    assert render(storefront_live) =~ "fulfilled"
    assert render(console_live) =~ "fulfilled"
  end
end
