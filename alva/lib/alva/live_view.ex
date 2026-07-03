defmodule Alva.LiveView do
  @moduledoc """
  A macro to inject Alva-specific functionality into Phoenix LiveViews.
  """

  defmacro __using__(opts) do
    quote do
      import Alva.LiveView
      @alva_domains Keyword.get(unquote(opts), :domains, [])
      on_mount {Alva.LiveView, @alva_domains}
    end
  end

  def on_mount(domains, _params, _session, socket) do
    # Configure file uploads
    socket =
      Enum.reduce(domains, socket, fn domain, acc_socket ->
        domain
        |> Alva.Domain.Info.file_upload_arguments()
        |> Enum.reduce(acc_socket, fn arg, s ->
          Phoenix.LiveView.allow_upload(s, arg.name, accept: :any)
        end)
      end)

    # Attach handle_event hook
    socket =
      Phoenix.LiveView.attach_hook(socket, :alva_handle_event, :handle_event, fn event_name, params, sock ->
        res = Alva.Dispatcher.dispatch(event_name, params, domains: domains, socket: sock)
        case res do
          %{ok: false, error: %{type: "unknown"}} ->
            {:cont, sock}
          _ ->
            {:halt, res, sock}
        end
      end)

    # Attach handle_info hook
    socket =
      Phoenix.LiveView.attach_hook(socket, :alva_handle_info, :handle_info, fn
        %Ash.Notifier.Notification{} = notification, sock ->
          payload = %{
            action: notification.action && notification.action.name,
            resource: to_string(notification.resource),
            data: Alva.Dispatcher.strip_metadata(notification.data)
          }
          {:halt, Phoenix.LiveView.push_event(sock, "ash_notification", payload)}

        _msg, sock ->
          {:cont, sock}
      end)

    {:cont, socket}
  end
end
