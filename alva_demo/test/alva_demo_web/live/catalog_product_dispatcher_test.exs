defmodule AlvaDemoWeb.CatalogProductDispatcherTest do
  use AlvaDemoWeb.ConnCase
  import Alva.Test
  alias Phoenix.LiveView.Socket

  defmodule CleanupMockUploadConsumer do
    def consume_uploaded_entries(socket, name, func) do
      socket.assigns
      |> get_in([:uploads, name, :entries])
      |> Kernel.||([])
      |> Enum.map(fn entry ->
        {:ok, upload} = func.(%{path: entry.path}, entry)
        File.rm(entry.path)
        upload
      end)
    end
  end

  defp alva_upload_temp_paths do
    temp_dir = Path.join(System.tmp_dir!(), "alva_uploads")

    case File.ls(temp_dir) do
      {:ok, files} -> MapSet.new(Enum.map(files, &Path.join(temp_dir, &1)))
      {:error, :enoent} -> MapSet.new()
    end
  end

  describe "catalog.list_products event" do
    test "successfully returns products" do
      socket = %Socket{
        endpoint: AlvaDemoWeb.Endpoint,
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
        endpoint: AlvaDemoWeb.Endpoint,
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
        endpoint: AlvaDemoWeb.Endpoint,
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
      persisted_before = alva_upload_temp_paths()

      socket = %Socket{
        endpoint: AlvaDemoWeb.Endpoint,
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
          upload_consumer: CleanupMockUploadConsumer
        )

      persisted_after = alva_upload_temp_paths()

      new_persisted_files =
        MapSet.difference(persisted_after, persisted_before) |> MapSet.to_list()

      dest_path =
        Path.join(:code.priv_dir(:alva_demo), "static/images/#{result.data.media_reference}")

      on_exit(fn ->
        Enum.each(new_persisted_files, &File.rm/1)
        File.rm(path)
        File.rm(dest_path)
      end)

      refute File.exists?(path)
      assert result.data.media_reference =~ "test_upload.jpg"
      assert result.data.media_reference != "before-upload.jpg"
      assert File.exists?(dest_path)

      updated_product = Ash.get!(AlvaDemo.Catalog.Product, product.id)
      assert updated_product.media_reference == result.data.media_reference
    end
  end
end
