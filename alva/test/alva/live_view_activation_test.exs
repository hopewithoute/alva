defmodule Alva.LiveViewActivationTest do
  use ExUnit.Case

  test "compiles successfully with the public declarative activation surface" do
    assert_compile("""
    defmodule TestLiveViewActivation.ValidLive do
      use Phoenix.LiveView

      use Alva.LiveView,
        domains: [TestDomain.Valid],
        collections: [sales_orders: [source_input: :sales_order_source_input]],
        signals: [:sales_orders_updated],
        route_subscriptions: [{:sales_orders, ["orders:all"]}]

      def sales_order_source_input, do: %{}

      def render(assigns) do
        ~H"<div />"
      end
    end
    """)
  end

  test "compiles successfully when route_subscriptions target an activated signal" do
    assert_compile("""
    defmodule TestLiveViewActivation.ValidSignalRouteLive do
      use Phoenix.LiveView

      use Alva.LiveView,
        domains: [TestDomain.Valid],
        signals: [:sales_orders_updated],
        route_subscriptions: [{:sales_orders_updated, "orders:updated"}]

      def render(assigns) do
        ~H"<div />"
      end
    end
    """)
  end

  test "compiles successfully when declarative activation uses module attributes" do
    assert_compile("""
    defmodule TestLiveViewActivation.AttributeBackedLive do
      use Phoenix.LiveView

      @collections [sales_orders: [source_input: :sales_order_source_input]]
      @signals [:sales_orders_updated]
      @route_subscriptions [
        {:sales_orders, ["orders:all"]},
        {:sales_orders_updated, "orders:updated"}
      ]

      use Alva.LiveView,
        domains: [TestDomain.Valid],
        collections: @collections,
        signals: @signals,
        route_subscriptions: @route_subscriptions

      def sales_order_source_input, do: %{}

      def render(assigns) do
        ~H"<div />"
      end
    end
    """)
  end

  test "fails to compile when declarative streams are declared" do
    assert_raise CompileError,
                 ~r/no longer accepts top-level `streams:`/,
                 fn ->
                   compile_module("""
                   defmodule TestLiveViewActivation.StreamsLive do
                     use Phoenix.LiveView

                     use Alva.LiveView,
                       domains: [TestDomain.Invalid],
                       streams: [:sales_orders]

                     def render(assigns) do
                       ~H"<div />"
                     end
                   end
                   """)
                 end
  end

  test "fails to compile when top-level subscriptions are declared" do
    assert_raise CompileError,
                 ~r/no longer accepts top-level `subscriptions:`/,
                 fn ->
                   compile_module("""
                   defmodule TestLiveViewActivation.SubscriptionsLive do
                     use Phoenix.LiveView

                     use Alva.LiveView,
                       domains: [TestDomain.Invalid],
                       subscriptions: ["orders:all"]

                     def render(assigns) do
                       ~H"<div />"
                     end
                   end
                   """)
                 end
  end

  test "fails to compile when a declarative collection uses params" do
    assert_raise CompileError,
                 ~r/no longer accepts `params:`. Use `source_input:` instead/,
                 fn ->
                   compile_module("""
                   defmodule TestLiveViewActivation.ParamsLive do
                     use Phoenix.LiveView

                     use Alva.LiveView,
                       domains: [TestDomain.Invalid],
                       collections: [sales_orders: [params: %{"page" => %{"limit" => 1}}]]

                     def render(assigns) do
                       ~H"<div />"
                     end
                   end
                   """)
                 end
  end

  test "fails to compile when a declarative collection nests subscriptions" do
    assert_raise CompileError,
                 ~r/no longer accepts nested `subscriptions:`. Move topic wiring to top-level `route_subscriptions:`/,
                 fn ->
                   compile_module("""
                   defmodule TestLiveViewActivation.NestedSubscriptionsLive do
                     use Phoenix.LiveView

                     use Alva.LiveView,
                       domains: [TestDomain.Invalid],
                       collections: [sales_orders: [subscriptions: ["orders:all"]]]

                     def render(assigns) do
                       ~H"<div />"
                     end
                   end
                   """)
                 end
  end

  test "fails to compile when signal activation uses browser-facing string names" do
    assert_raise CompileError,
                 ~r/no longer accepts browser-facing string names/,
                 fn ->
                   compile_module("""
                   defmodule TestLiveViewActivation.StringSignalsLive do
                     use Phoenix.LiveView

                     use Alva.LiveView,
                       domains: [TestDomain.Invalid],
                       signals: ["orders.fulfill"]

                     def render(assigns) do
                       ~H"<div />"
                     end
                   end
                   """)
                 end
  end

  test "fails to compile when signal activation uses tuple entries" do
    assert_raise CompileError,
                 ~r/only accepts atom declaration keys/,
                 fn ->
                   compile_module("""
                   defmodule TestLiveViewActivation.TupleSignalsLive do
                     use Phoenix.LiveView

                     use Alva.LiveView,
                       domains: [TestDomain.Invalid],
                       signals: [{:orders_fulfilled, []}]

                     def render(assigns) do
                       ~H"<div />"
                     end
                   end
                   """)
                 end
  end

  test "fails to compile when declarative collections contain duplicates" do
    assert_raise CompileError,
                 ~r/declarative collection activation contains duplicate entries/,
                 fn ->
                   compile_module("""
                   defmodule TestLiveViewActivation.DuplicateCollectionsLive do
                     use Phoenix.LiveView

                     use Alva.LiveView,
                       domains: [TestDomain.Invalid],
                       collections: [:sales_orders, :sales_orders]

                     def render(assigns) do
                       ~H"<div />"
                     end
                   end
                   """)
                 end
  end

  test "fails to compile when declarative signals contain duplicates" do
    assert_raise CompileError,
                 ~r/declarative signal activation contains duplicate entries/,
                 fn ->
                   compile_module("""
                   defmodule TestLiveViewActivation.DuplicateSignalsLive do
                     use Phoenix.LiveView

                     use Alva.LiveView,
                       domains: [TestDomain.Invalid],
                       signals: [:orders_fulfilled, :orders_fulfilled]

                     def render(assigns) do
                       ~H"<div />"
                     end
                   end
                   """)
                 end
  end

  test "fails to compile when declarative route_subscriptions contain duplicates" do
    assert_raise CompileError,
                 ~r/route_subscriptions contains duplicate entries for :sales_orders/,
                 fn ->
                   compile_module("""
                   defmodule TestLiveViewActivation.DuplicateRouteSubscriptionsLive do
                     use Phoenix.LiveView

                     use Alva.LiveView,
                       domains: [TestDomain.Invalid],
                       collections: [:sales_orders],
                       route_subscriptions: [
                         {:sales_orders, ["orders:all"]},
                         {:sales_orders, ["orders:tenant"]}
                       ]

                     def render(assigns) do
                       ~H"<div />"
                     end
                   end
                   """)
                 end
  end

  test "fails to compile when declarative route_subscriptions target an inactive projection" do
    assert_raise CompileError,
                 ~r/must reference an activated Collection or Signal projection on the same page/,
                 fn ->
                   compile_module("""
                   defmodule TestLiveViewActivation.InactiveRouteSubscriptionLive do
                     use Phoenix.LiveView

                     use Alva.LiveView,
                       domains: [TestDomain.Invalid],
                       collections: [:sales_orders],
                       route_subscriptions: [{:students_created, ["students"]}]

                     def render(assigns) do
                       ~H"<div />"
                     end
                   end
                   """)
                 end
  end

  test "fails to compile when declarative collections and signals share a projection key" do
    assert_raise CompileError,
                 ~r/cannot activate the same projection key in both `collections:` and `signals:`: :sales_orders/,
                 fn ->
                   compile_module("""
                   defmodule TestLiveViewActivation.CrossKindCollisionLive do
                     use Phoenix.LiveView

                     use Alva.LiveView,
                       domains: [TestDomain.Invalid],
                       collections: [:sales_orders],
                       signals: [:sales_orders]

                     def render(assigns) do
                       ~H"<div />"
                     end
                   end
                   """)
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
      TestLiveViewActivation.ValidLive,
      TestLiveViewActivation.ValidSignalRouteLive,
      TestLiveViewActivation.AttributeBackedLive
    ])
  end

  defp compile_module(code) do
    Code.compile_string(code)
  after
    purge_modules([
      TestLiveViewActivation.StreamsLive,
      TestLiveViewActivation.SubscriptionsLive,
      TestLiveViewActivation.ParamsLive,
      TestLiveViewActivation.NestedSubscriptionsLive,
      TestLiveViewActivation.StringSignalsLive,
      TestLiveViewActivation.TupleSignalsLive,
      TestLiveViewActivation.DuplicateCollectionsLive,
      TestLiveViewActivation.DuplicateSignalsLive,
      TestLiveViewActivation.DuplicateRouteSubscriptionsLive,
      TestLiveViewActivation.InactiveRouteSubscriptionLive,
      TestLiveViewActivation.CrossKindCollisionLive
    ])
  end

  defp purge_modules(modules) do
    Enum.each(modules, fn mod ->
      :code.purge(mod)
      :code.delete(mod)
    end)
  end
end
