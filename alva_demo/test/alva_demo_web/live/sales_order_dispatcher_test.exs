defmodule AlvaDemoWeb.SalesOrderDispatcherTest do
  use AlvaDemoWeb.ConnCase
  import Alva.Test
  alias Phoenix.LiveView.Socket
  alias AlvaDemo.Catalog.Product
  alias AlvaDemo.Sales.Order

  setup do
    product =
      Ash.Seed.seed!(%Product{
        name: "Test Product",
        description: "Test desc",
        price: 1000,
        stock: 10,
        media_reference: "test.jpg"
      })

    socket = %Socket{
      endpoint: AlvaDemoWeb.Endpoint,
      assigns: %{}
    }

    %{product: product, socket: socket}
  end

  describe "sales.create_order event" do
    test "successfully creates an order", %{socket: socket, product: product} do
      result =
        assert_dispatch_ok(socket, "sales.create_order", %{
          "customer_name" => "Bob",
          "product_id" => product.id,
          "quantity" => 3
        })

      assert result.ok == true
      assert result.data.customer_name == "Bob"
      assert result.data.lifecycle_status == "new"
    end

    test "rejects orders without a customer name", %{socket: socket, product: product} do
      result =
        Alva.Dispatcher.dispatch(
          "sales.create_order",
          %{
            "customer_name" => "",
            "product_id" => product.id,
            "quantity" => 1
          },
          otp_app: :alva_demo,
          socket: socket
        )

      assert result.ok == false
      assert result.error.type == "validation"
      assert result.error.fields["customer_name"] == ["is required"]
    end

    test "rejects lifecycle status supplied by the client", %{socket: socket, product: product} do
      result =
        Alva.Dispatcher.dispatch(
          "sales.create_order",
          %{
            "customer_name" => "Scoped Buyer",
            "product_id" => product.id,
            "quantity" => 1,
            "lifecycle_status" => "fulfilled"
          },
          otp_app: :alva_demo,
          socket: socket
        )

      assert result.ok == false
      assert result.error.type == "conflict"
      assert result.error.message =~ "No such input `lifecycle_status`"
    end
  end

  describe "sales.list_orders event" do
    test "successfully returns orders", %{socket: socket} do
      result = assert_dispatch_ok(socket, "sales.list_orders", %{})
      assert result.ok == true
      assert is_list(result.data)
    end

    test "filters orders by status, customer query, and product query", %{
      socket: socket,
      product: product
    } do
      secondary_product =
        Ash.Seed.seed!(%Product{
          name: "Filter Tee",
          description: "Secondary product",
          price: 2400,
          stock: 12,
          media_reference: "filter-tee.jpg"
        })

      _new_order =
        Order
        |> Ash.Changeset.for_create(:create, %{
          customer_name: "Alice Filter",
          product_id: product.id,
          quantity: 1
        })
        |> Ash.create!()

      processing_order =
        Order
        |> Ash.Changeset.for_create(:create, %{
          customer_name: "Processing Buyer",
          product_id: secondary_product.id,
          quantity: 1
        })
        |> Ash.create!()
        |> Ash.Changeset.for_update(:begin_processing)
        |> Ash.update!()

      status_result =
        assert_dispatch_ok(socket, "sales.list_orders", %{
          "status" => "processing"
        })

      assert Enum.all?(status_result.data, &(&1.lifecycle_status == "processing"))
      assert Enum.any?(status_result.data, &(&1.id == processing_order.id))

      customer_result =
        assert_dispatch_ok(socket, "sales.list_orders", %{
          "customer_query" => "Alice"
        })

      assert Enum.any?(customer_result.data, &(&1.customer_name == "Alice Filter"))
      refute Enum.any?(customer_result.data, &(&1.customer_name == "Processing Buyer"))

      product_result =
        assert_dispatch_ok(socket, "sales.list_orders", %{
          "product_query" => "Tee"
        })

      assert Enum.any?(product_result.data, &(&1.id == processing_order.id))
      refute Enum.any?(product_result.data, &(&1.customer_name == "Alice Filter"))
    end
  end

  describe "sales.begin_processing event" do
    test "transitions order from new to processing", %{socket: socket, product: product} do
      order =
        Order
        |> Ash.Changeset.for_create(:create, %{
          customer_name: "Alice",
          product_id: product.id,
          quantity: 1
        })
        |> Ash.create!()

      result = assert_dispatch_ok(socket, "sales.begin_processing", %{"id" => order.id})
      assert result.ok == true
      assert result.data.lifecycle_status == "processing"
    end
  end

  describe "sales.fulfill event" do
    test "transitions order from processing to fulfilled", %{socket: socket, product: product} do
      order =
        Order
        |> Ash.Changeset.for_create(:create, %{
          customer_name: "Alice",
          product_id: product.id,
          quantity: 1
        })
        |> Ash.create!()

      processed =
        order
        |> Ash.Changeset.for_update(:begin_processing)
        |> Ash.update!()

      result = assert_dispatch_ok(socket, "sales.fulfill", %{"id" => processed.id})
      assert result.ok == true
      assert result.data.lifecycle_status == "fulfilled"
    end

    test "rejects fulfill when the order is still new", %{socket: socket, product: product} do
      order =
        Order
        |> Ash.Changeset.for_create(:create, %{
          customer_name: "Alice",
          product_id: product.id,
          quantity: 1
        })
        |> Ash.create!()

      result =
        Alva.Dispatcher.dispatch(
          "sales.fulfill",
          %{"id" => order.id},
          otp_app: :alva_demo,
          socket: socket
        )

      assert result.ok == false
      assert result.error.type == "validation"

      assert result.error.fields["lifecycle_status"] == [
               "Invalid value provided for lifecycle_status: Order must be in processing state to transition."
             ]
    end
  end
end
