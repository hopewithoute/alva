defmodule AlvaDemoWeb.CustomerStorefrontLiveTest do
  use AlvaDemoWeb.ConnCase
  import Phoenix.LiveViewTest

  test "disconnected and connected mount", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/storefront")
    
    assert disconnected_html =~ "Customer Storefront"
    assert render(page_live) =~ "Customer Storefront"
    assert render(page_live) =~ "data-name=\"CustomerStorefrontPage\""
    
  end
end
