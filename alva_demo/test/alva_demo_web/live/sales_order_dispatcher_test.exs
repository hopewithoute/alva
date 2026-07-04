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
      private: %{alva: %{domains: [AlvaDemo.Sales, AlvaDemo.Catalog]}},
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
      assert result.data.lifecycle_status == :new
    end
  end

  describe "sales.list_orders event" do
    test "successfully returns orders", %{socket: socket} do
      result = assert_dispatch_ok(socket, "sales.list_orders", %{})
      assert result.ok == true
      assert is_list(result.data)
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
      assert result.data.lifecycle_status == :processing
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
      assert result.data.lifecycle_status == :fulfilled
    end
  end
end
