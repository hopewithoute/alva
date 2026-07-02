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
end
