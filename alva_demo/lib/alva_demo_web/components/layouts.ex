defmodule AlvaDemoWeb.Layouts do
  @moduledoc """
  Layouts for the Commerce Showcase.
  """

  use AlvaDemoWeb, :html

  embed_templates "layouts/*"

  def vite_dev_server? do
    Application.get_env(:alva_demo, :dev_routes, false)
  end

  attr :flash, :map, required: true
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-stone-50 text-zinc-950">
      <header class="border-b border-zinc-200 bg-white">
        <nav class="mx-auto flex max-w-6xl items-center justify-between px-5 py-4">
          <.link navigate={~p"/"} class="text-sm font-semibold tracking-wide">
            Alva Commerce Showcase
          </.link>
          <div class="flex items-center gap-2 text-sm">
            <.link navigate={~p"/storefront"} class="rounded-md px-3 py-2 hover:bg-zinc-100">
              Customer Storefront
            </.link>
            <.link navigate={~p"/console"} class="rounded-md px-3 py-2 hover:bg-zinc-100">
              Merchant Console
            </.link>
          </div>
        </nav>
      </header>

      <main class="mx-auto max-w-6xl px-5 py-8">
        {render_slot(@inner_block)}
      </main>
    </div>
    """
  end
end
