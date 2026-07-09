defmodule Alva.LiveViewActivationTest do
  use ExUnit.Case

  test "compiles successfully when top-level streams are declared" do
    assert_compile("""
    defmodule TestLiveViewActivation.StreamsLive do
      use Phoenix.LiveView

      use Alva.LiveView,
        streams: [
          :sales_orders
        ]

      def render(assigns) do
        ~H"<div />"
      end
    end
    """)
  end

  test "fails to compile when legacy subscriptions are used" do
    assert_raise CompileError,
                 ~r/legacy `subscriptions:` DSL is strictly removed/,
                 fn ->
                   compile_module("""
                   defmodule TestLiveViewActivation.InvalidSubscriptionsLive do
                     use Phoenix.LiveView

                     use Alva.LiveView,
                       subscriptions: [:orders]

                     def render(assigns) do
                       ~H"<div />"
                     end
                   end
                   """)
                 end
  end

  test "fails to compile when legacy V1 keys are used" do
    for legacy_key <- [:collections, :signals, :route_subscriptions, :page_events, :page_state] do
      assert_raise CompileError,
                   ~r/Alva declarative page activation no longer accepts `#{legacy_key}:`/,
                   fn ->
                     compile_module("""
                     defmodule TestLiveViewActivation.InvalidLegacyLive do
                       use Phoenix.LiveView

                       use Alva.LiveView,
                         #{legacy_key}: []

                       def render(assigns) do
                         ~H"<div />"
                       end
                     end
                     """)
                   end
    end
  end

  setup_all do
    Code.compiler_options(ignore_module_conflict: true)
    :ok
  end

  defp assert_compile(code) do
    assert [_ | _] = Code.compile_string(code)
  after
    purge_modules([
      TestLiveViewActivation.SubscriptionsLive
    ])
  end

  defp compile_module(code) do
    Code.compile_string(code)
  after
    purge_modules([
      TestLiveViewActivation.InvalidSubscriptionsLive
    ])
  end

  defp purge_modules(modules) do
    Enum.each(modules, fn mod ->
      :code.purge(mod)
      :code.delete(mod)
    end)
  end
end
