defmodule AlvaDemoWeb.SynchronizationTest do
  use AlvaDemoWeb.ConnCase
  import Alva.Test
  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  alias AlvaDemo.Catalog.Product
  alias AlvaDemo.Sales.Order
  alias AlvaDemo.Support.Conversation
  alias AlvaDemo.Support.SupportMessage
  alias Phoenix.LiveView.Socket

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
    {:ok, storefront_live, _html} = live(conn, "/storefront?customer_name=Sync%20Shopper")
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
    {:ok, storefront_live, _html} = live(conn, "/storefront?customer_name=Hook%20Shopper")

    render_hook(storefront_live, "sales.create_order", %{
      "customer_name" => "Hook Shopper",
      "product_id" => product.id,
      "quantity" => 1
    })

    assert render(storefront_live) =~ "Hook Shopper"
  end

  test "merchant console lifecycle actions sync back to the storefront without a refresh", %{
    conn: conn,
    product: product
  } do
    order =
      Order
      |> Ash.Changeset.for_create(:create, %{
        customer_name: "Console Sync Shopper",
        product_id: product.id,
        quantity: 1
      })
      |> Ash.create!()

    {:ok, storefront_live, _html} = live(conn, "/storefront?customer_name=Console%20Sync%20Shopper")
    {:ok, console_live, _html} = live(conn, "/console")

    render_hook(console_live, "sales.begin_processing", %{"id" => order.id})

    assert render(storefront_live) =~ "Console Sync Shopper"
    assert render(storefront_live) =~ "processing"

    render_hook(console_live, "sales.fulfill", %{"id" => order.id})

    assert render(storefront_live) =~ "fulfilled"
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
      Conversation
      |> Ash.Changeset.for_create(:create, %{customer_name: "Collection Support"})
      |> Ash.create!()

    assert_receive %Phoenix.Socket.Broadcast{event: "create"}

    :timer.sleep(50)

    assert render(console_live) =~ "Collection Support"
  end

  test "storefront does not subscribe to inactive conversation collection broadcasts", %{
    conn: conn
  } do
    {:ok, _storefront_live, _html} = live(conn, "/storefront")

    log =
      capture_log(fn ->
        _conversation =
          Conversation
          |> Ash.Changeset.for_create(:create, %{customer_name: "Storefront Listener"})
          |> Ash.create!()

        :timer.sleep(50)
      end)

    refute log =~ "undefined handle_info in AlvaDemoWeb.CustomerStorefrontLive"
    refute log =~ "conversation:created"
  end

  test "support message history and live updates stay route-scoped for both chat surfaces", %{
    conn: conn
  } do
    active_conversation = seed_conversation!("Active Chat")
    other_conversation = seed_conversation!("Other Chat")

    seed_message!(active_conversation, "Active history", :shopper)
    seed_message!(other_conversation, "Other history", :shopper)

    {:ok, storefront_live, _html} =
      live(
        conn,
        "/storefront?customer_name=#{active_conversation.customer_name}&conversation_id=#{active_conversation.id}"
      )

    {:ok, console_live, _html} = live(conn, "/console?conversation_id=#{active_conversation.id}")

    storefront_history = list_messages_for(active_conversation)
    console_history = list_messages_for(active_conversation)

    assert Enum.any?(storefront_history, &(&1.text == "Active history"))
    refute Enum.any?(storefront_history, &(&1.text == "Other history"))
    assert Enum.any?(console_history, &(&1.text == "Active history"))
    refute Enum.any?(console_history, &(&1.text == "Other history"))

    AlvaDemoWeb.Endpoint.subscribe("support_message:created")

    _message =
      SupportMessage
      |> Ash.Changeset.for_create(:create, %{
        conversation_id: active_conversation.id,
        sender: :merchant,
        text: "Live route message"
      })
      |> Ash.create!()

    assert_receive %Phoenix.Socket.Broadcast{event: "create"}

    :timer.sleep(50)

    assert render(storefront_live) =~ "Live route message"
    assert render(console_live) =~ "Live route message"
  end

  defp seed_conversation!(customer_name) do
    Ash.Seed.seed!(%Conversation{customer_name: customer_name})
  end

  defp seed_message!(conversation, text, sender) do
    Ash.Seed.seed!(%SupportMessage{
      conversation_id: conversation.id,
      text: text,
      sender: sender
    })
  end

  defp list_messages_for(conversation) do
    socket = %Socket{
      endpoint: AlvaDemoWeb.Endpoint,
      assigns: %{}
    }

    result =
      assert_dispatch_ok(socket, "support.list_messages", %{
        "conversation_id" => conversation.id
      })

    result.data
  end

end
