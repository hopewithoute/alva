defmodule AlvaDemoWeb.HomeLiveTest do
  use AlvaDemoWeb.ConnCase
  import Phoenix.LiveViewTest

  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "AlvaDemo"
    assert render(page_live) =~ "StudentsIndex"
  end

  test "students.archive event doesn't crash", %{conn: conn} do
    student = AlvaDemo.Academics.Student.create!(%{name: "To Be Archived"})
    {:ok, page_live, _} = live(conn, "/")

    render_hook(page_live, "students.archive", %{"id" => student.id})
    # If the stream_delete fails, the LiveView will crash. By arriving here, we know it worked.
    assert render(page_live) =~ "StudentsIndex"
  end

  test "students.create event doesn't crash", %{conn: conn} do
    {:ok, page_live, _} = live(conn, "/")

    render_hook(page_live, "students.create", %{"name" => "Siti"})
    assert render(page_live) =~ "StudentsIndex"
  end
end
