defmodule AlvaDemoWeb.CustomerStorefrontLive do
  use AlvaDemoWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section id="customer-storefront" class="space-y-6">
        <div class="space-y-2">
          <p class="text-sm font-medium uppercase text-zinc-500">Customer Storefront</p>
          <h1 class="text-3xl font-semibold tracking-tight">Browse products and place simple orders.</h1>
          <p class="max-w-2xl text-zinc-600">
            Product catalog, Customer Name capture, ordering, and Support Chat arrive in the next slices.
          </p>
        </div>
        <.vue v-component="CustomerStorefrontPage" />
      </section>
    </Layouts.app>
    """
  end
end
