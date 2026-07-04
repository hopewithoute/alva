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

  describe "catalog.upload_media event" do
    test "successfully processes uploaded media and updates reference" do
      product =
        Ash.Seed.seed!(%AlvaDemo.Catalog.Product{
          name: "Upload Media Product",
          description: "Test upload",
          price: 1000,
          stock: 10,
          media_reference: nil
        })

      # Create a dummy file for the test
      path = "test/support/fixtures/mock_upload_#{System.unique_integer([:positive])}.jpg"
      File.mkdir_p!("test/support/fixtures")
      File.write!(path, "dummy image")

      upload = %Plug.Upload{
        path: path,
        filename: "test_upload.jpg",
        content_type: "image/jpeg"
      }

      result =
        product
        |> Ash.Changeset.for_update(:upload_media, %{media: upload})
        |> Ash.update!()

      assert result.media_reference =~ "test_upload.jpg"

      updated_product = Ash.get!(AlvaDemo.Catalog.Product, product.id)
      assert updated_product.media_reference =~ "test_upload.jpg"
    end
  end
end
