<script setup lang="ts">
import { Link } from "live_vue";
</script>

<template>
  <div class="w-full space-y-24 py-4">
    <!-- Hero Section (Specimen № 01) -->
    <section
      id="commerce-showcase-entry"
      class="grid grid-cols-1 border-y border-[var(--color-rule)] lg:grid-cols-[260px_1fr]"
    >
      <!-- Left Rail: Specimen Mark -->
      <div
        class="flex min-h-[440px] flex-col justify-between border-b border-[var(--color-rule)] p-8 lg:border-b-0 lg:border-r lg:p-10"
      >
        <div class="space-y-1">
          <span
            class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
            >ALVA LIBRARY HUB</span
          >
          <p
            class="text-[10px] uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
          >
            v0.1.0 Release
          </p>
        </div>

        <div>
          <h2
            class="text-7xl font-normal text-[var(--color-ink)] lg:text-9xl"
            style="font-family: var(--font-display); line-height: 0.8; letter-spacing: -0.03em"
          >
            Alva
          </h2>
          <p
            class="mt-4 text-sm italic text-[var(--color-ink-2)]"
            style="font-family: var(--font-display)"
          >
            Ash &amp; LiveVue Bridge
          </p>
        </div>

        <div
          class="text-[10px] uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
          style="font-family: var(--font-mono)"
        >
          Elixir + Vue 3 Reactive SDK
        </div>
      </div>

      <!-- Right: Main Hero Content -->
      <div class="flex flex-col justify-between space-y-10 p-8 lg:p-14">
        <div class="max-w-3xl space-y-6">
          <p
            class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
          >
            THE TYPE-SAFE VUE 3 &amp; ASH FRAMEWORK BRIDGE
          </p>
          <h1
            class="text-5xl font-normal text-[var(--color-ink)] lg:text-6xl"
            style="font-family: var(--font-display); line-height: 1.05"
          >
            Build Ash-backed Vue UIs with zero boilerplate.
          </h1>
          <p class="max-w-2xl text-lg text-[var(--color-ink-2)]" style="line-height: 1.7">
            Alva bridges <strong>Ash Framework domain resources</strong> and
            <strong>Phoenix LiveVue components</strong>. Generative TypeScript SDKs, instant PubSub
            signal reactivity, and server-owned streams in one unified architecture.
          </p>
        </div>

        <!-- Terminal Quickstart Codeblock -->
        <div
          class="max-w-xl space-y-2 border border-[var(--color-rule-2)] bg-[var(--color-paper-2)] p-4"
        >
          <div
            class="flex items-center justify-between border-b border-[var(--color-rule)] pb-2 font-mono text-[10px] uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
          >
            <span>Terminal / Code Generation</span>
            <span>TypeScript SDK</span>
          </div>
          <div class="flex items-center justify-between pt-1 font-mono text-xs">
            <div class="flex items-center gap-3">
              <span class="font-bold text-[var(--color-accent)]">$</span>
              <span class="font-bold text-[var(--color-ink)]">mix alva.codegen</span>
            </div>
            <span
              class="font-mono text-[10px] font-semibold uppercase tracking-wider text-emerald-500"
              >✓ Generated</span
            >
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="flex flex-col gap-4 border-t border-[var(--color-rule)] pt-8 sm:flex-row">
          <Link navigate="/docs" class="btn--primary px-8 py-4 text-center text-xs font-semibold">
            Read Documentation &rarr;
          </Link>
          <Link
            navigate="/storefront"
            class="border border-[var(--color-ink)] bg-transparent px-8 py-4 text-center text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)] transition-colors hover:bg-[var(--color-ink)] hover:text-[var(--color-paper)]"
            style="font-family: var(--font-mono)"
          >
            Explore Case Study
          </Link>
        </div>
      </div>
    </section>

    <!-- Architecture Section (Specimen № 02) -->
    <section class="space-y-12">
      <div
        class="flex flex-col justify-between gap-4 border-b border-[var(--color-rule)] pb-4 sm:flex-row sm:items-baseline"
      >
        <div class="space-y-1">
          <span
            class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
            >№ 01 — ARCHITECTURE PILLARS</span
          >
          <h2
            class="text-3xl font-normal text-[var(--color-ink)]"
            style="font-family: var(--font-display)"
          >
            Core Library Features
          </h2>
        </div>
        <p
          class="text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
          style="font-family: var(--font-mono)"
        >
          Declarative &amp; Generative
        </p>
      </div>

      <div class="grid grid-cols-1 gap-12 md:grid-cols-3">
        <div class="space-y-4 border-t border-[var(--color-rule)] pt-6">
          <span
            class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
            >01 / Generative SDK</span
          >
          <h3
            class="text-2xl font-normal text-[var(--color-ink)]"
            style="font-family: var(--font-display)"
          >
            Schema-Driven Code Generation
          </h3>
          <p class="text-sm text-[var(--color-ink-2)]" style="line-height: 1.7">
            Inspects your backend Ash Domain DSL and automatically compiles strongly-typed Vue
            composables for all queries, mutations, and form validations. Ensures complete
            end-to-end type safety from Elixir schemas directly to frontend components.
          </p>
        </div>

        <div class="space-y-4 border-t border-[var(--color-rule)] pt-6">
          <span
            class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
            >02 / Realtime Signals</span
          >
          <h3
            class="text-2xl font-normal text-[var(--color-ink)]"
            style="font-family: var(--font-display)"
          >
            Reactive Event Dispatching
          </h3>
          <p class="text-sm text-[var(--color-ink-2)]" style="line-height: 1.7">
            Seamlessly bridges Phoenix PubSub events into Vue component reactivity. Domain actions
            instantly trigger real-time UI updates across connected clients over WebSocket channels
            without writing custom socket listeners or channel handlers.
          </p>
        </div>

        <div class="space-y-4 border-t border-[var(--color-rule)] pt-6">
          <span
            class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
            >03 / Canonical State</span
          >
          <h3
            class="text-2xl font-normal text-[var(--color-ink)]"
            style="font-family: var(--font-display)"
          >
            Zero State Synchronization
          </h3>
          <p class="text-sm text-[var(--color-ink-2)]" style="line-height: 1.7">
            Maintains the canonical source of truth on Phoenix LiveView server assigns while client
            components stream data dynamically. Prevents frontend state drift, eliminates client
            cache invalidation bugs, and simplifies complex data-fetching pipelines.
          </p>
        </div>
      </div>
    </section>

    <!-- Demos Index (Specimen № 03) -->
    <section class="space-y-12">
      <div
        class="flex flex-col justify-between gap-4 border-b border-[var(--color-rule)] pb-4 sm:flex-row sm:items-baseline"
      >
        <div class="space-y-1">
          <span
            class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
            >№ 02 — INTERACTIVE SPECIMENS</span
          >
          <h2
            class="text-3xl font-normal text-[var(--color-ink)]"
            style="font-family: var(--font-display)"
          >
            Library Feature Sandboxes
          </h2>
        </div>
        <p
          class="text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
          style="font-family: var(--font-mono)"
        >
          Select a specimen sandbox to test
        </p>
      </div>

      <div class="divide-y divide-[var(--color-rule)] border-y border-[var(--color-rule)]">
        <Link
          navigate="/demo/chat"
          class="group flex flex-col justify-between px-2 py-6 transition-colors hover:bg-[var(--color-paper-2)] sm:flex-row sm:items-center"
        >
          <div class="space-y-1">
            <span class="font-mono text-xs uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
              >Specimen 01</span
            >
            <h3
              class="text-2xl font-normal text-[var(--color-ink)] group-hover:underline"
              style="font-family: var(--font-display)"
            >
              Realtime Chat Stream
            </h3>
            <p class="text-sm text-[var(--color-ink-2)]">
              Multi-client message broadcasting backed by Ash PubSub without local state
              reconciliation.
            </p>
          </div>
          <span
            class="mt-4 font-mono text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)] transition-transform group-hover:translate-x-2 sm:mt-0"
          >
            Launch Specimen &rarr;
          </span>
        </Link>

        <Link
          navigate="/demo/load-more"
          class="group flex flex-col justify-between px-2 py-6 transition-colors hover:bg-[var(--color-paper-2)] sm:flex-row sm:items-center"
        >
          <div class="space-y-1">
            <span class="font-mono text-xs uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
              >Specimen 02</span
            >
            <h3
              class="text-2xl font-normal text-[var(--color-ink)] group-hover:underline"
              style="font-family: var(--font-display)"
            >
              Infinite Subscription Feed
            </h3>
            <p class="text-sm text-[var(--color-ink-2)]">
              Server-owned stream pagination with Vue components requesting incremental data slices
              on demand.
            </p>
          </div>
          <span
            class="mt-4 font-mono text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)] transition-transform group-hover:translate-x-2 sm:mt-0"
          >
            Launch Specimen &rarr;
          </span>
        </Link>

        <Link
          navigate="/demo/notifications"
          class="group flex flex-col justify-between px-2 py-6 transition-colors hover:bg-[var(--color-paper-2)] sm:flex-row sm:items-center"
        >
          <div class="space-y-1">
            <span class="font-mono text-xs uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
              >Specimen 03</span
            >
            <h3
              class="text-2xl font-normal text-[var(--color-ink)] group-hover:underline"
              style="font-family: var(--font-display)"
            >
              Semantic Signal Log
            </h3>
            <p class="text-sm text-[var(--color-ink-2)]">
              Listens to standalone system notifications and domain events in real time without
              polling.
            </p>
          </div>
          <span
            class="mt-4 font-mono text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)] transition-transform group-hover:translate-x-2 sm:mt-0"
          >
            Launch Specimen &rarr;
          </span>
        </Link>

        <Link
          navigate="/demo/query-lookup"
          class="group flex flex-col justify-between px-2 py-6 transition-colors hover:bg-[var(--color-paper-2)] sm:flex-row sm:items-center"
        >
          <div class="space-y-1">
            <span class="font-mono text-xs uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
              >Specimen 04</span
            >
            <h3
              class="text-2xl font-normal text-[var(--color-ink)] group-hover:underline"
              style="font-family: var(--font-display)"
            >
              Query Lookups &amp; AST Filters
            </h3>
            <p class="text-sm text-[var(--color-ink-2)]">
              Single-record detail fetching with background polling and server-side AST filter
              execution.
            </p>
          </div>
          <span
            class="mt-4 font-mono text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)] transition-transform group-hover:translate-x-2 sm:mt-0"
          >
            Launch Specimen &rarr;
          </span>
        </Link>

        <Link
          navigate="/demo/optimistic-form"
          class="group flex flex-col justify-between px-2 py-6 transition-colors hover:bg-[var(--color-paper-2)] sm:flex-row sm:items-center"
        >
          <div class="space-y-1">
            <span class="font-mono text-xs uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
              >Specimen 05</span
            >
            <h3
              class="text-2xl font-normal text-[var(--color-ink)] group-hover:underline"
              style="font-family: var(--font-display)"
            >
              Optimistic Form UI &amp; Rollback
            </h3>
            <p class="text-sm text-[var(--color-ink-2)]">
              Provides immediate local UI form feedback with automatic state restoration if server
              validation fails.
            </p>
          </div>
          <span
            class="mt-4 font-mono text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)] transition-transform group-hover:translate-x-2 sm:mt-0"
          >
            Launch Specimen &rarr;
          </span>
        </Link>
      </div>
    </section>

    <!-- Broad-sheet Stat Strip (Specimen № 04) -->
    <section class="my-16 border-y-2 border-[var(--color-ink)] py-10">
      <div
        class="grid grid-cols-2 gap-8 divide-x divide-[var(--color-rule)] text-center md:grid-cols-4"
      >
        <div class="space-y-1">
          <p
            class="text-4xl font-normal text-[var(--color-ink)] lg:text-5xl"
            style="font-family: var(--font-display)"
          >
            100%
          </p>
          <p
            class="text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
          >
            Type-Safe Client
          </p>
        </div>
        <div class="space-y-1">
          <p
            class="text-4xl font-normal text-[var(--color-ink)] lg:text-5xl"
            style="font-family: var(--font-display)"
          >
            0kb
          </p>
          <p
            class="text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
          >
            Extra Dependencies
          </p>
        </div>
        <div class="space-y-1">
          <p
            class="text-4xl font-normal text-[var(--color-ink)] lg:text-5xl"
            style="font-family: var(--font-display)"
          >
            0
          </p>
          <p
            class="text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
          >
            State Drift
          </p>
        </div>
        <div class="space-y-1">
          <p
            class="text-4xl font-normal text-[var(--color-ink)] lg:text-5xl"
            style="font-family: var(--font-display)"
          >
            Zero
          </p>
          <p
            class="text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
          >
            Socket Boilerplate
          </p>
        </div>
      </div>
    </section>
  </div>
</template>

<style scoped>
@keyframes typing {
  from {
    width: 0;
  }
  to {
    width: 140px;
  }
}
@keyframes blink {
  from,
  to {
    border-color: transparent;
  }
  50% {
    border-color: var(--color-accent);
  }
}
@keyframes fade-in {
  from {
    opacity: 0;
    transform: translateY(5px);
  }
  to {
    opacity: 1;
    transform: none;
  }
}
</style>
