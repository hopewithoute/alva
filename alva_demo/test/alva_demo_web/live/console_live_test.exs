defmodule AlvaDemoWeb.MerchantConsoleLiveTest do
  use AlvaDemoWeb.ConnCase
  import Phoenix.LiveViewTest

  test "mounts and sets up data sync", %{conn: conn} do
    Ash.Seed.seed!(%AlvaDemo.Catalog.Product{
      name: "Test Console Product",
      price: 2500,
      description: "Test",
      stock: 10
    })

    {:ok, page_live, disconnected_html} = live(conn, "/console")

    assert disconnected_html =~ "Merchant Console"
    assert render(page_live) =~ "MerchantConsolePage"
  end
end
