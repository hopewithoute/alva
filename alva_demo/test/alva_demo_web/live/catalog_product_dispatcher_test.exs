defmodule AlvaDemoWeb.CatalogProductDispatcherTest do
  use AlvaDemoWeb.ConnCase
  import Alva.Test
  alias Phoenix.LiveView.Socket

  describe "catalog.list_products event" do
    test "successfully returns products" do
      socket = %Socket{
        private: %{alva: %{domains: [AlvaDemo.Catalog]}},
        assigns: %{}
      }

      result = assert_dispatch_ok(socket, "catalog.list_products", %{})

      assert result.ok == true
      assert is_list(result.data)
      assert length(result.data) > 0

      product = hd(result.data)
      assert Map.has_key?(product, :id)
      assert Map.has_key?(product, :name)
      assert Map.has_key?(product, :price)
    end
  end

  describe "catalog.adjust_stock event" do
    test "successfully adjusts product stock" do
      product =
        Ash.Seed.seed!(%AlvaDemo.Catalog.Product{
          name: "Adjust Stock Product",
          description: "Test desc",
          price: 1000,
          stock: 10,
          media_reference: "adjust.jpg"
        })

      socket = %Socket{
        private: %{alva: %{domains: [AlvaDemo.Catalog]}},
        assigns: %{}
      }

      result =
        assert_dispatch_ok(socket, "catalog.adjust_stock", %{
          "id" => product.id,
          "stock" => 25
        })

      assert result.ok == true
      assert result.data.stock == 25

      updated_product = Ash.get!(AlvaDemo.Catalog.Product, product.id)
      assert updated_product.stock == 25
    end
  end
end
