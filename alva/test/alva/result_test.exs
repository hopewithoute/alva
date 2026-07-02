defmodule Alva.ResultTest do
  use ExUnit.Case

  test "apply with {:stream_insert, key} ignores errors" do
    result = %{ok: false, error: %{type: "invalid"}}

    {reply, ^result, socket} =
      Alva.Result.apply(result, %Phoenix.LiveView.Socket{}, strategy: {:stream_insert, :items})

    assert reply == :reply
    assert socket == %Phoenix.LiveView.Socket{}
  end

  test "apply with {:stream_delete, key} ignores errors" do
    result = %{ok: false, error: %{type: "not_found"}}

    {reply, ^result, socket} =
      Alva.Result.apply(result, %Phoenix.LiveView.Socket{}, strategy: {:stream_delete, :items})

    assert reply == :reply
    assert socket == %Phoenix.LiveView.Socket{}
  end

  test "apply with default strategy or non-socket" do
    result = %{ok: true, data: %{}}
    {reply, ^result, socket} = Alva.Result.apply(result, %{})
    assert reply == :reply
    assert socket == %{}
  end

  test "apply with {:assign, key} assigns data to socket" do
    result = %{ok: true, data: %{name: "Test"}}
    socket = %Phoenix.LiveView.Socket{}

    {reply, ^result, returned_socket} =
      Alva.Result.apply(result, socket, strategy: {:assign, :current_user})

    assert reply == :reply
    assert returned_socket.assigns.current_user == %{name: "Test"}
  end

  test "apply with {:reply, :data} doesn't alter socket state" do
    result = %{ok: true, data: %{name: "Test"}}
    socket = %Phoenix.LiveView.Socket{assigns: %{foo: "bar"}}

    {reply, ^result, returned_socket} =
      Alva.Result.apply(result, socket, strategy: {:reply, :data})

    assert reply == :reply
    assert returned_socket == socket
    assert returned_socket.assigns.foo == "bar"
  end
end
