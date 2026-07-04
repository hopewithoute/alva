defmodule AlvaDemoWeb.HomeLive do
  use AlvaDemoWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section id="commerce-showcase-entry" class="grid gap-6 md:grid-cols-[1.2fr_0.8fr]">
        <div class="space-y-4">
          <p class="text-sm font-medium uppercase text-zinc-500">Alva Commerce Showcase</p>
          <h1 class="text-4xl font-semibold tracking-tight">Commerce operations over Ash, LiveView, and Vue.</h1>
          <p class="max-w-2xl text-base text-zinc-600">
            Start from either side of the sample: the Customer Storefront for shopper activity, or the Merchant Console for operational work.
          </p>
          <div class="flex flex-wrap gap-3">
            <.link navigate={~p"/shop"} class="rounded-md bg-zinc-950 px-4 py-2 text-sm font-medium text-white">
              Open Customer Storefront
            </.link>
            <.link navigate={~p"/console"} class="rounded-md border border-zinc-300 px-4 py-2 text-sm font-medium">
              Open Merchant Console
            </.link>
          </div>
        </div>
        <div class="rounded-lg border border-zinc-200 bg-white p-5">
          <.vue v-component="ShowcaseStatus" surface="entry" />
        </div>
      </section>
    </Layouts.app>
    """
  end
end
