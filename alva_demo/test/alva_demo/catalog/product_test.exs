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
    
    test "upload_media action updates media_reference" do
      product = Ash.read!(Product) |> hd()
      
      # Simulate a Plug.Upload created by live view consume_uploaded_entries
      upload = %Plug.Upload{
        path: "test/support/fixtures/test_image.jpg",
        filename: "test_image.jpg",
        content_type: "image/jpeg"
      }
      
      # We need a dummy file to exist, let's create it inline for testing
      File.mkdir_p!("test/support/fixtures")
      File.write!("test/support/fixtures/test_image.jpg", "dummy image data")
      
      updated = 
        product
        |> Ash.Changeset.for_update(:upload_media, %{media: upload})
        |> Ash.update!()
        
      assert updated.media_reference =~ "test_image.jpg"
      
      # Verify it was copied to priv/static/images
      dest_path = Path.join(:code.priv_dir(:alva_demo), "static/images/#{updated.media_reference}")
      assert File.exists?(dest_path)
      
      # Cleanup
      File.rm!(dest_path)
    end
  end
end
