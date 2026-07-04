defmodule AlvaDemo.Sales.OrderLifecycleTest do
  use ExUnit.Case, async: false

  alias AlvaDemo.Sales.Order
  alias AlvaDemo.Catalog.Product

  setup do
    product =
      Ash.Seed.seed!(%Product{
        name: "Console Test Product",
        description: "Console desc",
        price: 1000,
        stock: 10,
        media_reference: "test.jpg"
      })

    order =
      Order
      |> Ash.Changeset.for_create(:create, %{
        customer_name: "MerchantTest",
        product_id: product.id,
        quantity: 1
      })
      |> Ash.create!()

    %{order: order}
  end

  test "can list orders", %{order: order} do
    orders = Ash.read!(Order, action: :read)
    assert Enum.any?(orders, fn o -> o.id == order.id end)
  end

  test "can transition from new to processing", %{order: order} do
    processed =
      order
      |> Ash.Changeset.for_update(:begin_processing)
      |> Ash.update!()

    assert processed.lifecycle_status == :processing
  end

  test "can transition from processing to fulfilled", %{order: order} do
    processed =
      order
      |> Ash.Changeset.for_update(:begin_processing)
      |> Ash.update!()

    fulfilled =
      processed
      |> Ash.Changeset.for_update(:fulfill)
      |> Ash.update!()

    assert fulfilled.lifecycle_status == :fulfilled
  end

  test "rejects invalid transition from new to fulfilled", %{order: order} do
    assert_raise Ash.Error.Invalid, fn ->
      order
      |> Ash.Changeset.for_update(:fulfill)
      |> Ash.update!()
    end
  end

  test "rejects invalid transition from processing to processing", %{order: order} do
    processed =
      order
      |> Ash.Changeset.for_update(:begin_processing)
      |> Ash.update!()

    assert_raise Ash.Error.Invalid, fn ->
      processed
      |> Ash.Changeset.for_update(:begin_processing)
      |> Ash.update!()
    end
  end
end
