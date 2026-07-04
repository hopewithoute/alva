defmodule AlvaDemoWeb.MerchantConsoleLive do
  use AlvaDemoWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section id="merchant-console" class="space-y-6">
        <div class="space-y-2">
          <p class="text-sm font-medium uppercase text-zinc-500">Merchant Console</p>
          <h1 class="text-3xl font-semibold tracking-tight">Monitor orders and operate the showcase.</h1>
          <p class="max-w-2xl text-zinc-600">
            Order Lifecycle, Inventory Snapshot, Product Media, and Support Chat controls arrive in follow-up slices.
          </p>
        </div>
        <.vue v-component="MerchantConsolePage" />
      </section>
    </Layouts.app>
    """
  end
end
