defmodule Alva.LiveView.State do
  @moduledoc false

  @type t :: %__MODULE__{
          otp_app: atom() | nil,
          domains: [atom()],
          event_map: map()
        }

  defstruct otp_app: nil,
            domains: [],
            event_map: %{}

  @alva_private_key :alva

  @spec get(Phoenix.LiveView.Socket.t()) :: t()
  def get(socket) do
    Map.get(socket.private, @alva_private_key, %__MODULE__{})
  end

  @spec put(Phoenix.LiveView.Socket.t(), t()) :: Phoenix.LiveView.Socket.t()
  def put(socket, %__MODULE__{} = state) do
    Phoenix.LiveView.put_private(socket, @alva_private_key, state)
  end

  @spec update(Phoenix.LiveView.Socket.t(), (t() -> t())) :: Phoenix.LiveView.Socket.t()
  def update(socket, fun) do
    put(socket, fun.(get(socket)))
  end
end
