defmodule AlvaDemo.Catalog.ProductTest do
  use ExUnit.Case, async: true

  alias AlvaDemo.Catalog.Product

  describe "product resource" do
    test "is ETS-backed and seeded on startup" do
      products = Ash.read!(Product)

      assert length(products) > 0
      
      product = hd(products)
      assert %Product{} = product
      assert is_binary(product.name)
      assert is_binary(product.description)
      assert is_integer(product.price)
      assert is_integer(product.stock)
      assert is_binary(product.media_reference)
    end
  end
end
