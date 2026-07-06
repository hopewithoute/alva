defmodule AlvaDemoWeb.DemoPrimitivesLiveTest do
  use AlvaDemoWeb.ConnCase

  import Phoenix.LiveViewTest

  test "chat demo streams new messages across open pages without a refresh", %{conn: conn} do
    {:ok, page_one, _html} = live(conn, "/demo/chat")
    {:ok, page_two, _html} = live(conn, "/demo/chat")

    unique_text = "Stream demo #{System.unique_integer([:positive])}"

    hook_html =
      render_hook(page_one, "demo_chat.send_message", %{
        "author" => "Page One",
        "text" => unique_text
      })

    assert hook_html =~ unique_text

    :timer.sleep(50)
    assert render(page_two) =~ unique_text
  end

  test "notifications demo pushes a semantic signal payload", %{conn: conn} do
    {:ok, page_live, _html} = live(conn, "/demo/notifications")

    unique_title = "Notification #{System.unique_integer([:positive])}"

    render_hook(page_live, "demo_notifications.send", %{
      "title" => unique_title,
      "severity" => "success"
    })

    assert_push_event(
      page_live,
      "demo_notifications.sent",
      %{
        title: ^unique_title,
        severity: "success",
        id: _,
        created_at: _
      },
      200
    )
  end

  test "load more demo grows the route-owned collection on patch navigation", %{conn: conn} do
    {:ok, page_live, _html} = live(conn, "/demo/load-more")

    assert render(page_live) =~ "Pattern 1"
    assert render(page_live) =~ "Pattern 5"
    refute render(page_live) =~ "Pattern 6"

    render_patch(page_live, "/demo/load-more?limit=10")

    assert render(page_live) =~ "Pattern 10"
    assert render(page_live) =~ "Pattern 1"
  end
end
