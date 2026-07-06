<script setup lang="ts">
import { Link } from "live_vue";
</script>

<template>
  <div class="min-h-screen bg-stone-50 text-zinc-950">
    <header class="border-b border-zinc-200 bg-white/95 backdrop-blur">
      <nav class="mx-auto flex max-w-7xl flex-col gap-4 px-5 py-4 lg:flex-row lg:items-center lg:justify-between">
        <div class="space-y-1">
          <Link
            navigate="/"
            class="text-sm font-semibold tracking-wide"
          >
            Alva Commerce Showcase
          </Link>
          <p class="text-sm text-zinc-500">Ash resources, LiveView streams, and Vue surfaces in one operational sample.</p>
        </div>

        <div class="flex items-center gap-2 text-sm">
          <Link navigate="/storefront" class="rounded-md px-3 py-2 hover:bg-zinc-100">
            Customer Storefront
          </Link>
          <Link navigate="/console" class="rounded-md px-3 py-2 hover:bg-zinc-100">
            Merchant Console
          </Link>
          <Link navigate="/demo/chat" class="rounded-md px-3 py-2 hover:bg-zinc-100">
            Chat Demo
          </Link>
          <Link navigate="/demo/notifications" class="rounded-md px-3 py-2 hover:bg-zinc-100">
            Signals Demo
          </Link>
          <Link navigate="/demo/load-more" class="rounded-md px-3 py-2 hover:bg-zinc-100">
            Load More Demo
          </Link>
        </div>
      </nav>
    </header>

    <main class="mx-auto max-w-7xl px-5 py-8">
      <slot />
    </main>
  </div>
</template>
