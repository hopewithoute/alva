defmodule AlvaDemoWeb.ParamHelpers do
  @moduledoc """
  Shared parameter parsing and normalization helpers for AlvaDemoWeb LiveViews.
  """

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
