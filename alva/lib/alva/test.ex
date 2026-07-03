defmodule Alva.Test do
  @moduledoc """
  Provides test helpers for verifying Alva dispatch events.
  """

  @doc """
  Executes an event dispatch and asserts that the result is successful.
  Returns the successful result map.
  """
  defmacro assert_dispatch_ok(socket, event, params \\ %{}, opts \\ []) do
    quote bind_quoted: [socket: socket, event: event, params: params, opts: opts] do
      domains = Keyword.get(opts, :domains) || get_in(socket.private, [:alva, :domains]) || []
      opts = Keyword.put(opts, :domains, domains)
      opts = Keyword.put(opts, :socket, socket)
      
      result = Alva.Dispatcher.dispatch(event, params, opts)
      assert result.ok == true, "Expected dispatch to succeed, but got error: #{inspect(result)}"
      result
    end
  end

  @doc """
  Executes an event dispatch and asserts that the result is a forbidden error.
  Returns the error result map.
  """
  defmacro assert_dispatch_forbidden(socket, event, params \\ %{}, opts \\ []) do
    quote bind_quoted: [socket: socket, event: event, params: params, opts: opts] do
      domains = Keyword.get(opts, :domains) || get_in(socket.private, [:alva, :domains]) || []
      opts = Keyword.put(opts, :domains, domains)
      opts = Keyword.put(opts, :socket, socket)
      
      result = Alva.Dispatcher.dispatch(event, params, opts)
      assert result.ok == false, "Expected dispatch to fail, but got success: #{inspect(result)}"
      assert result.error.type == "forbidden", "Expected forbidden error, but got: #{inspect(result.error)}"
      result
    end
  end
end
