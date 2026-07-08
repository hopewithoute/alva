defmodule AlvaDemo.Subscriptions do
  @moduledoc false

  alias Alva.Dispatcher

  def load_stream_items(socket, event_name, input) do
    case Dispatcher.dispatch(event_name, normalize_input(input), socket: socket) do
      %{ok: true, data: items} when is_list(items) ->
        {:ok, items}

      %{ok: true, data: %{results: items}} when is_list(items) ->
        {:ok, items}

      %{ok: false, error: error} ->
        {:error, error}

      other ->
        {:error, {:invalid_stream_source, other}}
    end
  end

  def notifier_topic(resource, topic) do
    prefix = Ash.Notifier.PubSub.Info.prefix(resource) || ""
    delimiter = Ash.Notifier.PubSub.Info.delimiter(resource)

    if prefix == "" do
      topic
    else
      "#{prefix}#{delimiter}#{topic}"
    end
  end

  def with_defaults(defaults, input) do
    Map.merge(defaults, normalize_input(input))
  end

  def normalize_input(input) when is_map(input) do
    Map.new(input, fn {key, value} -> {to_string(key), value} end)
  end

  def normalize_input(_input), do: %{}
end
