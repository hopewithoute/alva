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
end
