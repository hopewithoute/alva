defmodule AlvaDemoWeb.MerchantConsoleLiveTest do
  use AlvaDemoWeb.ConnCase
  import Phoenix.LiveViewTest

  test "disconnected and connected mount", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/console")
    
    assert disconnected_html =~ "Merchant Console"
    assert render(page_live) =~ "Merchant Console"
    assert render(page_live) =~ "data-name=\"MerchantConsolePage\""
  end
end
