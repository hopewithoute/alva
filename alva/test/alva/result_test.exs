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

  test "apply with {:push_event, event} pushes event to socket" do
    result = %{ok: true, data: %{id: 123}}
    socket = %Phoenix.LiveView.Socket{}

    {reply, ^result, returned_socket} =
      Alva.Result.apply(result, socket, strategy: {:push_event, "user_created"})

    assert reply == :reply
    assert [["user_created", %{id: 123}]] = returned_socket.private.live_temp.push_events
  end

  test "apply with {:navigate, to} handles static string" do
    result = %{ok: true, data: %{}}
    socket = %Phoenix.LiveView.Socket{}

    {reply, ^result, returned_socket} =
      Alva.Result.apply(result, socket, strategy: {:navigate, "/users"})

    assert reply == :reply
    assert returned_socket.redirected == {:live, :redirect, %{to: "/users", kind: :push}}
  end

  test "apply with {:patch, to} handles static string" do
    result = %{ok: true, data: %{}}
    socket = %Phoenix.LiveView.Socket{}

    {reply, ^result, returned_socket} =
      Alva.Result.apply(result, socket, strategy: {:patch, "/users"})

    assert reply == :reply
    assert returned_socket.redirected == {:live, :patch, %{to: "/users", kind: :push}}
  end

  defmodule DummyCustomHandler do
    def handle_result(socket, data) do
      Phoenix.Component.assign(socket, :custom_handled, data)
    end
  end

  defmodule DummyCustomNoreplyHandler do
    def handle_result(socket, data) do
      {:noreply, Phoenix.Component.assign(socket, :custom_handled, data)}
    end
  end

  test "apply with {:custom, module} delegates to module returning socket" do
    result = %{ok: true, data: %{foo: "bar"}}
    socket = %Phoenix.LiveView.Socket{}

    {reply, ^result, returned_socket} =
      Alva.Result.apply(result, socket, strategy: {:custom, DummyCustomHandler})

    assert reply == :reply
    assert returned_socket.assigns.custom_handled == %{foo: "bar"}
  end

  test "apply with {:custom, module} delegates to module returning {:noreply, socket}" do
    result = %{ok: true, data: %{foo: "baz"}}
    socket = %Phoenix.LiveView.Socket{}

    {reply, ^result, returned_socket} =
      Alva.Result.apply(result, socket, strategy: {:custom, DummyCustomNoreplyHandler})

    assert reply == :reply
    assert returned_socket.assigns.custom_handled == %{foo: "baz"}
  end
end
