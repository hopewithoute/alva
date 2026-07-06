defmodule AlvaDemoWeb.CatalogProductDispatcherTest do
  use AlvaDemoWeb.ConnCase
  import Alva.Test
  alias Phoenix.LiveView.Socket

  defmodule MockUploadConsumer do
    def consume_uploaded_entries(socket, name, func) do
      socket.assigns
      |> get_in([:uploads, name, :entries])
      |> Kernel.||([])
      |> Enum.map(fn entry ->
        {:ok, upload} = func.(%{path: entry.path}, entry)
        upload
      end)
    end
  end

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

    test "supports product query and max stock filters" do
      Ash.Seed.seed!(%AlvaDemo.Catalog.Product{
        name: "Needle Finder",
        description: "Search me",
        price: 1900,
        stock: 9,
        media_reference: "needle.jpg"
      })

      Ash.Seed.seed!(%AlvaDemo.Catalog.Product{
        name: "High Stock Product",
        description: "Plenty available",
        price: 2200,
        stock: 77,
        media_reference: "high-stock.jpg"
      })

      socket = %Socket{
        private: %{alva: %{domains: [AlvaDemo.Catalog]}},
        assigns: %{}
      }

      query_result =
        assert_dispatch_ok(socket, "catalog.list_products", %{
          "query" => "Needle"
        })

      assert Enum.any?(query_result.data, &(&1.name == "Needle Finder"))
      refute Enum.any?(query_result.data, &(&1.name == "High Stock Product"))

      stock_result =
        assert_dispatch_ok(socket, "catalog.list_products", %{
          "max_stock" => 10
        })

      assert Enum.any?(stock_result.data, &(&1.name == "Needle Finder"))
      refute Enum.any?(stock_result.data, &(&1.name == "High Stock Product"))
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
    test "consumes the LiveView upload entry and updates the product media reference" do
      product =
        Ash.Seed.seed!(%AlvaDemo.Catalog.Product{
          name: "Upload Media Product",
          description: "Test upload",
          price: 1000,
          stock: 10,
          media_reference: "before-upload.jpg"
        })

      path = Path.join(System.tmp_dir!(), "mock_upload_#{System.unique_integer([:positive])}.jpg")
      File.write!(path, "dummy image")

      socket = %Socket{
        private: %{alva: %{domains: [AlvaDemo.Catalog]}},
        assigns: %{
          current_user: %{id: "merchant-1"},
          current_tenant: "demo",
          uploads: %{
            media: %{
              entries: [
                %{
                  client_name: "test_upload.jpg",
                  client_type: "image/jpeg",
                  path: path
                }
              ]
            }
          }
        }
      }

      result =
        assert_dispatch_ok(socket, "catalog.upload_media", %{"id" => product.id},
          upload_consumer: MockUploadConsumer
        )

      dest_path =
        Path.join(:code.priv_dir(:alva_demo), "static/images/#{result.data.media_reference}")

      on_exit(fn ->
        File.rm(path)
        File.rm(dest_path)
      end)

      assert result.data.media_reference =~ "test_upload.jpg"
      assert result.data.media_reference != "before-upload.jpg"
      assert File.exists?(dest_path)

      updated_product = Ash.get!(AlvaDemo.Catalog.Product, product.id)
      assert updated_product.media_reference == result.data.media_reference
    end
  end
end
