defmodule AlvaDemo.Sales.OrderTest do
  use ExUnit.Case, async: true

  alias AlvaDemo.Sales.Order
  alias AlvaDemo.Catalog.Product

  describe "order resource" do
    test "can create an order with new status" do
      # Need a product first
      product = Ash.Seed.seed!(%Product{
        name: "Test Product",
        description: "Test desc",
        price: 1000,
        stock: 10,
        media_reference: "test.jpg"
      })

      order =
        Order
        |> Ash.Changeset.for_create(:create, %{
          customer_name: "Alice",
          product_id: product.id,
          quantity: 2
        })
        |> Ash.create!()

      assert order.customer_name == "Alice"
      assert order.product_id == product.id
      assert order.quantity == 2
      assert order.lifecycle_status == :new
    end
  end
end
