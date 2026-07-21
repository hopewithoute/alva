<script setup lang="ts">
import { Link } from "live_vue";
import ShowcaseStatus from "../../shared/layout/ShowcaseStatus.vue";
</script>

<template>
  <div class="w-full max-w-7xl mx-auto py-8 space-y-24">
    <!-- Hero Section (Specimen № 01) -->
    <section id="commerce-showcase-entry" class="grid grid-cols-1 lg:grid-cols-[260px_1fr] border-y border-[var(--color-rule)]">
      <!-- Left Rail: Specimen Mark -->
      <div class="border-b lg:border-b-0 lg:border-r border-[var(--color-rule)] p-8 lg:p-10 flex flex-col justify-between min-h-[440px]">
        <div class="space-y-1">
          <span class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">№ 01 — SPECIMEN</span>
          <p class="text-[10px] uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">Issue Vol. I / 2026</p>
        </div>

        <div>
          <h2 class="text-7xl lg:text-9xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display); line-height: 0.8; letter-spacing: -0.03em;">
            Alva
          </h2>
          <p class="mt-4 text-sm text-[var(--color-ink-2)] italic" style="font-family: var(--font-display);">Commerce &amp; Operations</p>
        </div>

        <div class="text-[10px] uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
          Ash + LiveVue Engine
        </div>
      </div>

      <!-- Right: Main Hero Content -->
      <div class="p-8 lg:p-14 flex flex-col justify-between space-y-10">
        <div class="max-w-3xl space-y-6">
          <p class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
            The Broadsheet Architecture
          </p>
          <h1 class="text-5xl lg:text-6xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display); line-height: 1.05;">
            Reactive commerce over Ash, LiveView, and Vue 3.
          </h1>
          <p class="text-lg text-[var(--color-ink-2)] max-w-2xl" style="line-height: 1.7;">
            Operate your store from two synchronized surfaces: the <strong>Shopper Storefront</strong> for customer placement, and the <strong>Merchant Console</strong> for real-time order lifecycle execution.
          </p>
        </div>

        <!-- Action Buttons -->
        <div class="flex flex-col sm:flex-row gap-4 pt-8 border-t border-[var(--color-rule)]">
          <Link
            navigate="/console"
            class="btn--primary px-8 py-4 text-xs font-semibold text-center"
          >
            Open Merchant Console
          </Link>
          <Link
            navigate="/storefront"
            class="border border-[var(--color-ink)] bg-transparent px-8 py-4 text-xs font-semibold text-[var(--color-ink)] uppercase tracking-[0.1em] text-center transition-colors hover:bg-[var(--color-ink)] hover:text-[var(--color-paper)]"
            style="font-family: var(--font-mono)"
          >
            Browse Storefront
          </Link>
        </div>
      </div>
    </section>

    <!-- Architecture Section (Specimen № 02) -->
    <section class="space-y-12">
      <div class="flex flex-col sm:flex-row sm:items-baseline justify-between border-b border-[var(--color-rule)] pb-4 gap-4">
        <div class="space-y-1">
          <span class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">№ 02 — ARCHITECTURE</span>
          <h2 class="text-3xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">Core Pillars</h2>
        </div>
        <p class="text-xs text-[var(--color-ink-2)] uppercase tracking-[0.1em]" style="font-family: var(--font-mono)">Declarative &amp; Stream-Backed</p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-12">
        <div class="space-y-4 border-t border-[var(--color-rule)] pt-6">
          <span class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">01 / Real-Time LiveVue</span>
          <h3 class="text-2xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">Server-Owned Streams</h3>
          <p class="text-sm text-[var(--color-ink-2)]" style="line-height: 1.7;">
            Data stays on the server. Vue components receive live updates over WebSocket connections without client-side state duplication.
          </p>
        </div>

        <div class="space-y-4 border-t border-[var(--color-rule)] pt-6">
          <span class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">02 / Ash Framework</span>
          <h3 class="text-2xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">Resource-Driven Logic</h3>
          <p class="text-sm text-[var(--color-ink-2)]" style="line-height: 1.7;">
            Declarative domain resources handle validation, policies, and lifecycle actions with zero boilerplate.
          </p>
        </div>

        <div class="space-y-4 border-t border-[var(--color-rule)] pt-6">
          <span class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">03 / Multi-Surface UI</span>
          <h3 class="text-2xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">Synchronized Queues</h3>
          <p class="text-sm text-[var(--color-ink-2)]" style="line-height: 1.7;">
            Order creation on the storefront immediately reflects in the merchant queue and support thread with zero manual polling.
          </p>
        </div>
      </div>
    </section>

    <!-- Demos Index (Specimen № 03) -->
    <section class="space-y-12">
      <div class="flex flex-col sm:flex-row sm:items-baseline justify-between border-b border-[var(--color-rule)] pb-4 gap-4">
        <div class="space-y-1">
          <span class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">№ 03 — INTERACTIVE DEMOS</span>
          <h2 class="text-3xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">Live Stream Showcases</h2>
        </div>
        <p class="text-xs text-[var(--color-ink-2)] uppercase tracking-[0.1em]" style="font-family: var(--font-mono)">Select a showcase to test</p>
      </div>

      <div class="divide-y divide-[var(--color-rule)] border-y border-[var(--color-rule)]">
        <Link
          navigate="/demo/chat"
          class="group flex flex-col sm:flex-row sm:items-center justify-between py-6 px-2 transition-colors hover:bg-[var(--color-paper-2)]"
        >
          <div class="space-y-1">
            <span class="text-xs font-mono uppercase tracking-[0.15em] text-[var(--color-ink-2)]">Demo 01</span>
            <h3 class="text-2xl font-normal text-[var(--color-ink)] group-hover:underline" style="font-family: var(--font-display)">Realtime Chat Stream</h3>
            <p class="text-sm text-[var(--color-ink-2)]">Commands broadcast messages across all open tabs simultaneously.</p>
          </div>
          <span class="mt-4 sm:mt-0 text-xs font-mono uppercase tracking-[0.1em] text-[var(--color-ink)] font-semibold group-hover:translate-x-2 transition-transform">
            Launch Stream &rarr;
          </span>
        </Link>

        <Link
          navigate="/demo/load-more"
          class="group flex flex-col sm:flex-row sm:items-center justify-between py-6 px-2 transition-colors hover:bg-[var(--color-paper-2)]"
        >
          <div class="space-y-1">
            <span class="text-xs font-mono uppercase tracking-[0.15em] text-[var(--color-ink-2)]">Demo 02</span>
            <h3 class="text-2xl font-normal text-[var(--color-ink)] group-hover:underline" style="font-family: var(--font-display)">Infinite Subscription Feed</h3>
            <p class="text-sm text-[var(--color-ink-2)]">Server-owned stream pagination with Vue asking for larger dataset slices.</p>
          </div>
          <span class="mt-4 sm:mt-0 text-xs font-mono uppercase tracking-[0.1em] text-[var(--color-ink)] font-semibold group-hover:translate-x-2 transition-transform">
            Launch Feed &rarr;
          </span>
        </Link>

        <Link
          navigate="/demo/notifications"
          class="group flex flex-col sm:flex-row sm:items-center justify-between py-6 px-2 transition-colors hover:bg-[var(--color-paper-2)]"
        >
          <div class="space-y-1">
            <span class="text-xs font-mono uppercase tracking-[0.15em] text-[var(--color-ink-2)]">Demo 03</span>
            <h3 class="text-2xl font-normal text-[var(--color-ink)] group-hover:underline" style="font-family: var(--font-display)">Semantic Signal Log</h3>
            <p class="text-sm text-[var(--color-ink-2)]">Listen for standalone signal events without routing through local state reconciliations.</p>
          </div>
          <span class="mt-4 sm:mt-0 text-xs font-mono uppercase tracking-[0.1em] text-[var(--color-ink)] font-semibold group-hover:translate-x-2 transition-transform">
            Launch Log &rarr;
          </span>
        </Link>

        <Link
          navigate="/demo/query-lookup"
          class="group flex flex-col sm:flex-row sm:items-center justify-between py-6 px-2 transition-colors hover:bg-[var(--color-paper-2)]"
        >
          <div class="space-y-1">
            <span class="text-xs font-mono uppercase tracking-[0.15em] text-[var(--color-ink-2)]">Demo 04</span>
            <h3 class="text-2xl font-normal text-[var(--color-ink)] group-hover:underline" style="font-family: var(--font-display)">Query Lookups & AST Filters</h3>
            <p class="text-sm text-[var(--color-ink-2)]">Single-record lookups with use_by_id, background query polling, and typed AST filters.</p>
          </div>
          <span class="mt-4 sm:mt-0 text-xs font-mono uppercase tracking-[0.1em] text-[var(--color-ink)] font-semibold group-hover:translate-x-2 transition-transform">
            Launch Lookup &rarr;
          </span>
        </Link>

        <Link
          navigate="/demo/optimistic-form"
          class="group flex flex-col sm:flex-row sm:items-center justify-between py-6 px-2 transition-colors hover:bg-[var(--color-paper-2)]"
        >
          <div class="space-y-1">
            <span class="text-xs font-mono uppercase tracking-[0.15em] text-[var(--color-ink-2)]">Demo 05</span>
            <h3 class="text-2xl font-normal text-[var(--color-ink)] group-hover:underline" style="font-family: var(--font-display)">Optimistic Form UI & Server Rollback</h3>
            <p class="text-sm text-[var(--color-ink-2)]">Instant local UI form mutation feedback with automatic state rollback on server rejection.</p>
          </div>
          <span class="mt-4 sm:mt-0 text-xs font-mono uppercase tracking-[0.1em] text-[var(--color-ink)] font-semibold group-hover:translate-x-2 transition-transform">
            Launch Form &rarr;
          </span>
        </Link>
      </div>
    </section>

    <!-- Broad-sheet Stat Strip (Specimen № 04) -->
    <section class="border-y-2 border-[var(--color-ink)] py-10 my-16">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-8 text-center divide-x divide-[var(--color-rule)]">
        <div class="space-y-1">
          <p class="text-4xl lg:text-5xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">24ms</p>
          <p class="text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">Hydration Speed</p>
        </div>
        <div class="space-y-1">
          <p class="text-4xl lg:text-5xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">100%</p>
          <p class="text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">Reactive Streams</p>
        </div>
        <div class="space-y-1">
          <p class="text-4xl lg:text-5xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">0</p>
          <p class="text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">State Drift</p>
        </div>
        <div class="space-y-1">
          <p class="text-4xl lg:text-5xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">Zero</p>
          <p class="text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">Boilerplate</p>
        </div>
      </div>
    </section>
  </div>
</template>

<style scoped>
  @keyframes typing {
    from { width: 0 }
    to { width: 140px }
  }
  @keyframes blink {
    from, to { border-color: transparent }
    50% { border-color: var(--color-accent) }
  }
  @keyframes fade-in {
    from { opacity: 0; transform: translateY(5px); }
    to { opacity: 1; transform: none; }
  }
</style>
