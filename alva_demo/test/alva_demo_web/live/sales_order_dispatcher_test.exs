defmodule AlvaDemoWeb.SalesOrderDispatcherTest do
  use AlvaDemoWeb.ConnCase
  import Alva.Test
  alias Phoenix.LiveView.Socket
  alias AlvaDemo.Catalog.Product

  describe "sales.create_order event" do
    test "successfully creates an order" do
      product = Ash.Seed.seed!(%Product{
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

      result = assert_dispatch_ok(socket, "sales.create_order", %{
        "customer_name" => "Bob",
        "product_id" => product.id,
        "quantity" => 3
      })

      assert result.ok == true
      assert result.data.customer_name == "Bob"
      assert result.data.lifecycle_status == :new
    end
  end
end
