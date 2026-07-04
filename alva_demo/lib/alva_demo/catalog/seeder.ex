defmodule AlvaDemo.Catalog.Seeder do
  alias AlvaDemo.Catalog.Product

  def seed do
    # Only seed if empty
    if Ash.count!(Product) == 0 do
      products = [
        %{
          name: "Alva T-Shirt",
          description: "A comfortable, high-quality t-shirt featuring the Alva logo.",
          price: 2500,
          stock: 100,
          media_reference: "tshirt.jpg"
        },
        %{
          name: "Alva Mug",
          description: "A sturdy ceramic mug for your daily coffee or tea.",
          price: 1500,
          stock: 50,
          media_reference: "mug.jpg"
        },
        %{
          name: "Alva Hoodie",
          description: "A warm and cozy hoodie perfect for cold weather.",
          price: 4500,
          stock: 75,
          media_reference: "hoodie.jpg"
        }
      ]

      Enum.each(products, fn product_attrs ->
        Ash.Seed.seed!(struct(Product, product_attrs))
      end)
    end
  end
end
