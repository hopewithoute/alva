defmodule AlvaDemo.Catalog.Seeder do
  alias AlvaDemo.Catalog.Product

  def seed do
    existing_media =
      Product
      |> Ash.read!()
      |> Enum.map(& &1.media_reference)
      |> MapSet.new()

    products = [
      %{
        name: "Alva Mug",
        description: "A sturdy ceramic mug for daily coffee, tea, or late-night debugging.",
        price: 1500,
        stock: 50,
        media_reference: "alva-mug.png"
      },
      %{
        name: "Alva T-Shirt",
        description: "A soft cotton t-shirt with a minimal mark for everyday product teams.",
        price: 2500,
        stock: 100,
        media_reference: "alva-tshirt.png"
      },
      %{
        name: "Alva Hoodie",
        description: "A warm heather hoodie for focused work sessions and cooler rooms.",
        price: 4500,
        stock: 75,
        media_reference: "alva-hoodie.png"
      },
      %{
        name: "Alva Notebook",
        description: "A matte notebook and pen set for sketches, specs, and release notes.",
        price: 1800,
        stock: 80,
        media_reference: "alva-notebook.png"
      },
      %{
        name: "Alva Keyboard",
        description: "A compact mechanical keyboard with a quiet, precise desk presence.",
        price: 8900,
        stock: 35,
        media_reference: "alva-keyboard.png"
      },
      %{
        name: "Alva Bottle",
        description: "An insulated stainless bottle built for long days at the workstation.",
        price: 3200,
        stock: 60,
        media_reference: "alva-bottle.png"
      },
      %{
        name: "Alva Desk Lamp",
        description: "A compact adjustable desk lamp for warm, focused evening work.",
        price: 6400,
        stock: 24,
        media_reference: "alva-desk-lamp.png"
      },
      %{
        name: "Alva Laptop Stand",
        description: "A foldable aluminum stand for a cleaner and more ergonomic setup.",
        price: 5200,
        stock: 42,
        media_reference: "alva-laptop-stand.png"
      },
      %{
        name: "Alva Tote",
        description: "A natural canvas tote for notebooks, chargers, and daily carry.",
        price: 2800,
        stock: 65,
        media_reference: "alva-tote.png"
      }
    ]

    products
    |> Enum.reject(fn product_attrs ->
      MapSet.member?(existing_media, product_attrs.media_reference)
    end)
    |> Enum.each(fn product_attrs ->
      Ash.Seed.seed!(struct(Product, product_attrs))
    end)
  end
end
