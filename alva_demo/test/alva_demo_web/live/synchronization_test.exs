defmodule AlvaDemoWeb.SynchronizationTest do
  use AlvaDemoWeb.ConnCase
  import Phoenix.LiveViewTest
  alias AlvaDemo.Catalog.Product
  alias AlvaDemo.Sales.Order

  setup do
    product =
      Ash.Seed.seed!(%Product{
        name: "Sync Test Product",
        description: "Test desc",
        price: 1000,
        stock: 10,
        media_reference: "sync.jpg"
      })

    %{product: product}
  end

  test "order updates sync across storefront and merchant console", %{
    conn: conn,
    product: product
  } do
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

  test "order command updates the active storefront without a refresh", %{
    conn: conn,
    product: product
  } do
    {:ok, storefront_live, _html} = live(conn, "/storefront")

    html =
      render_hook(storefront_live, "sales.create_order", %{
        "customer_name" => "Hook Shopper",
        "product_id" => product.id,
        "quantity" => 1
      })

    assert html =~ "Hook Shopper"
  end

  test "product inventory updates sync across storefront and merchant console", %{
    conn: conn,
    product: product
  } do
    # Mount both surfaces
    {:ok, storefront_live, _html} = live(conn, "/storefront")
    {:ok, console_live, _html} = live(conn, "/console")

    AlvaDemoWeb.Endpoint.subscribe("product:updated")

    # Simulate stock adjustment via Ash domain
    _product =
      product
      |> Ash.Changeset.for_update(:adjust_stock, %{stock: 50})
      |> Ash.update!()

    # Wait for the broadcast to ensure LiveViews have received it
    assert_receive %Phoenix.Socket.Broadcast{event: "adjust_stock"}

    # Give the LiveView processes a tiny fraction of time to process the message they also just received
    :timer.sleep(50)

    # Both views should render the updated product stock
    assert render(storefront_live) =~ ~r/stock.?:50/
    assert render(console_live) =~ ~r/stock.?:50/
  end

  test "product media updates sync across storefront and merchant console", %{
    conn: conn,
    product: product
  } do
    {:ok, storefront_live, _html} = live(conn, "/storefront")
    {:ok, console_live, _html} = live(conn, "/console")

    path = Path.join(System.tmp_dir!(), "mock_upload_#{System.unique_integer([:positive])}.jpg")
    File.write!(path, "dummy image")

    upload = %Plug.Upload{
      path: path,
      filename: "collection_media.jpg",
      content_type: "image/jpeg"
    }

    AlvaDemoWeb.Endpoint.subscribe("product:updated")

    updated_product =
      product
      |> Ash.Changeset.for_update(:upload_media, %{media: upload})
      |> Ash.update!()

    on_exit(fn ->
      File.rm(path)

      Path.join(:code.priv_dir(:alva_demo), "static/images/#{updated_product.media_reference}")
      |> File.rm()
    end)

    assert_receive %Phoenix.Socket.Broadcast{event: "upload_media"}

    :timer.sleep(50)

    assert render(storefront_live) =~ "collection_media.jpg"
    assert render(console_live) =~ "collection_media.jpg"
  end

  test "support conversation creates sync to merchant console without a refresh", %{conn: conn} do
    {:ok, console_live, _html} = live(conn, "/console")

    AlvaDemoWeb.Endpoint.subscribe("conversation:created")

    _conversation =
      AlvaDemo.Support.Conversation
      |> Ash.Changeset.for_create(:create, %{customer_name: "Collection Support"})
      |> Ash.create!()

    assert_receive %Phoenix.Socket.Broadcast{event: "create"}

    :timer.sleep(50)

    assert render(console_live) =~ "Collection Support"
  end
end
