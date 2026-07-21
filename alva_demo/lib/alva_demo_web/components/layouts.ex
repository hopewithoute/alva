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
    <div class="min-h-screen bg-[var(--color-paper)] text-[var(--color-ink)]">
      <!-- N6 Broadsheet Masthead Header -->
      <header class="bg-[var(--color-paper)] pt-6 pb-2">
        <div class="mx-auto max-w-7xl px-6">
          <!-- Metadata Bar -->
          <div class="flex items-center justify-between text-[11px] uppercase tracking-[0.15em] text-[var(--color-ink-2)] border-b border-[var(--color-rule)] pb-2" style="font-family: var(--font-mono)">
            <span>Vol. I — No. 042</span>
            <span class="hidden sm:inline">Ash Framework + LiveVue Engine</span>
            <span>Commerce Operations</span>
          </div>

          <!-- Main Title / Wordmark -->
          <div class="py-6 text-center">
            <.link navigate={~p"/"} class="inline-block text-4xl sm:text-6xl font-normal tracking-tight text-[var(--color-ink)] hover:opacity-90 transition-opacity" style="font-family: var(--font-display)">
              ALVA COMMERCE
            </.link>
            <p class="mt-1 text-xs italic text-[var(--color-ink-2)]" style="font-family: var(--font-display)">
              Real-time state, signals, and operations broadsheet.
            </p>
          </div>

          <!-- Navigation & Double-Rule Border -->
          <div class="border-y-2 border-[var(--color-ink)] py-2.5 flex items-center justify-between text-xs uppercase tracking-[0.1em]" style="font-family: var(--font-mono)">
            <div class="flex items-center gap-8">
              <.link navigate={~p"/"} class="text-[var(--color-ink-2)] hover:text-[var(--color-ink)] transition-colors">
                Overview
              </.link>
              <.link navigate={~p"/storefront"} class="text-[var(--color-ink-2)] hover:text-[var(--color-ink)] transition-colors">
                Shopper Storefront
              </.link>
              <.link navigate={~p"/console"} class="text-[var(--color-ink-2)] hover:text-[var(--color-ink)] transition-colors">
                Merchant Console
              </.link>
              <.link navigate={~p"/docs"} class="text-[var(--color-ink-2)] hover:text-[var(--color-ink)] transition-colors">
                Documentation
              </.link>
            </div>
            <div class="hidden sm:flex items-center gap-2 text-[10px] text-[var(--color-ink-2)]">
              <span>Status: <strong class="text-[var(--color-success)] uppercase font-mono">Live</strong></span>
            </div>
          </div>
        </div>
      </header>

      <main class="mx-auto max-w-7xl px-6 py-10">
        {render_slot(@inner_block)}
      </main>
    </div>
    """
  end
end
