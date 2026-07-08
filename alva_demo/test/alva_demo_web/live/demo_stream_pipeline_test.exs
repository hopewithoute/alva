defmodule AlvaDemoWeb.DemoStreamPipelineTest do
  use AlvaDemoWeb.ConnCase
  alias LiveVue.Test, as: LiveVueTest
  import Phoenix.LiveViewTest

  test "lazy feed entries activate on demand and load more appends the stream", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/demo/load-more")

    disconnected_vue = LiveVueTest.get_vue(disconnected_html, id: "demo-load-more-page")

    assert disconnected_vue.streams_diff == []

    activate_html =
      render_hook(page_live, "alva:activate_subscription", %{
        "name" => "feed_entries",
        "input" => %{
          "page" => %{"limit" => 5, "offset" => 0},
          "sort" => "position"
        }
      })

    activate_vue = LiveVueTest.get_vue(activate_html, id: "demo-load-more-page")

    assert_stream_contains(activate_vue, "feed_entries", %{"position" => 1, "title" => "Pattern 1"})
    assert_stream_contains(activate_vue, "feed_entries", %{"position" => 5, "title" => "Pattern 5"})
    refute_stream_contains(activate_vue, "feed_entries", %{"position" => 6})

    load_more_html =
      render_hook(page_live, "alva:load_more_subscription", %{
        "name" => "feed_entries",
        "input" => %{
          "page" => %{"limit" => 10, "offset" => 0},
          "sort" => "position"
        }
      })

    load_more_vue = LiveVueTest.get_vue(load_more_html, id: "demo-load-more-page")

    assert_stream_contains(load_more_vue, "feed_entries", %{"position" => 6, "title" => "Pattern 6"})
    assert_stream_contains(load_more_vue, "feed_entries", %{"position" => 10, "title" => "Pattern 10"})
  end

  defp assert_stream_contains(vue, stream_name, expected_subset) do
    assert Enum.any?(vue.streams_diff, fn
             [op, path, value]
             when op in ["upsert", "replace"] and is_map(value) and is_binary(path) ->
               String.starts_with?(path, "/#{stream_name}/") and
                 Enum.all?(expected_subset, fn {key, expected} -> value[key] == expected end)

             _ ->
               false
           end)
  end

  defp refute_stream_contains(vue, stream_name, expected_subset) do
    refute Enum.any?(vue.streams_diff, fn
             [op, path, value]
             when op in ["upsert", "replace"] and is_map(value) and is_binary(path) ->
               String.starts_with?(path, "/#{stream_name}/") and
                 Enum.all?(expected_subset, fn {key, expected} -> value[key] == expected end)

             _ ->
               false
           end)
  end
end
