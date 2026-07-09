defmodule AlvaDemoWeb.DemoStreamPipelineTest do
  use AlvaDemoWeb.ConnCase
  alias LiveVue.Test, as: LiveVueTest
  import Phoenix.LiveViewTest

  test "feed entries stream mounts synchronously", %{conn: conn} do
    {:ok, _page_live, html} = live(conn, "/demo/load-more")
    vue = LiveVueTest.get_vue(html, id: "demo-load-more-page")

    assert_stream_contains(vue, "feed_entries", %{"position" => 1, "title" => "Pattern 1"})
    assert_stream_contains(vue, "feed_entries", %{"position" => 5, "title" => "Pattern 5"})
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
