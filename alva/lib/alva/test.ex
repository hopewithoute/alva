defmodule Alva.Test do
  @moduledoc since: "0.1.0"
  @moduledoc """
  Provides test helpers for verifying Alva dispatch events.

  Use these macros in your Phoenix `ConnCase` or `LiveViewCase` tests to
  assert that dispatches succeed or return forbidden errors.
  """

  @doc """
  Executes an event dispatch and asserts that the result is successful.
  Returns the successful result map.
  """
  @doc since: "0.1.0"
  defmacro assert_dispatch_ok(socket, event, params \\ %{}, opts \\ []) do
    quote bind_quoted: [socket: socket, event: event, params: params, opts: opts] do
      result = Alva.Test.do_dispatch(socket, event, params, opts)
      assert result.ok == true, "Expected dispatch to succeed, but got error: #{inspect(result)}"
      result
    end
  end

  @doc """
  Executes an event dispatch and asserts that the result is a forbidden error.
  Returns the error result map.
  """
  @doc since: "0.1.0"
  defmacro assert_dispatch_forbidden(socket, event, params \\ %{}, opts \\ []) do
    quote bind_quoted: [socket: socket, event: event, params: params, opts: opts] do
      result = Alva.Test.do_dispatch(socket, event, params, opts)
      assert result.ok == false, "Expected dispatch to fail, but got success: #{inspect(result)}"

      assert result.error.type == "forbidden",
             "Expected forbidden error, but got: #{inspect(result.error)}"

      result
    end
  end

  @doc false
  def do_dispatch(socket, event, params, opts) do
    domains = Keyword.get(opts, :domains) || get_in(socket.private, [:alva, :domains]) || []

    # Extract assigns as requested by the spec
    user_key = Application.get_env(:alva, :actor_assign_key, :current_user)
    tenant_key = Application.get_env(:alva, :tenant_assign_key, :current_tenant)
    actor = Map.get(socket.assigns || %{}, user_key)
    tenant = Map.get(socket.assigns || %{}, tenant_key)

    opts = Keyword.put(opts, :domains, domains)
    opts = Keyword.put(opts, :socket, socket)
    opts = if actor, do: Keyword.put(opts, :actor, actor), else: opts
    opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

    Alva.Dispatcher.dispatch(event, params, opts)
  end
end
