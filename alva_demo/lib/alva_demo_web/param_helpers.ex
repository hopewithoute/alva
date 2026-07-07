defmodule AlvaDemoWeb.ParamHelpers do
  @moduledoc """
  Shared parameter parsing and normalization helpers for AlvaDemoWeb LiveViews.
  """

  def support_message_collection_source_input(socket) do
    %{"conversation_id" => active_conversation_id(socket)}
  end

  def support_message_route_topics(socket) do
    case active_conversation_id(socket) do
      nil -> {:ok, []}
      conversation_id -> {:ok, ["support_message:conversation:#{conversation_id}"]}
    end
  end

  def active_conversation_id(socket) do
    socket
    |> Alva.LiveView.route_params()
    |> normalize_conversation_id()
  end

  def normalize_conversation_id(params) when is_map(params) do
    params
    |> Map.get("conversation_id")
    |> normalize_optional_string()
  end

  def normalize_optional_string(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  rescue
    Protocol.UndefinedError -> nil
  end
end
