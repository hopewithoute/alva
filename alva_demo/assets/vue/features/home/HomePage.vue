<script setup lang="ts">
import { Link } from "live_vue";
import ShowcaseStatus from "../../shared/layout/ShowcaseStatus.vue";
</script>

<template>
  <section id="commerce-showcase-entry" class="grid gap-6 md:grid-cols-[1.2fr_0.8fr]">
    <div class="space-y-4">
      <p class="text-sm font-medium uppercase text-zinc-500">Alva Commerce Showcase</p>
      <h1 class="text-4xl font-semibold tracking-tight">
        Commerce operations over Ash, LiveView, and Vue.
      </h1>
      <p class="max-w-2xl text-base text-zinc-600">
        Start from either side of the sample: the Customer Storefront for shopper activity, or the
        Merchant Console for operational work. The header navigation also links to three isolated
        realtime demos if you want to study streams, signals, or route-owned collection reloads in
        smaller slices.
      </p>
      <div class="flex items-center gap-4">
        <Link
          navigate="/storefront"
          class="rounded-md bg-zinc-950 px-4 py-2 text-sm font-medium text-white"
        >
          View Storefront
        </Link>
        <Link
          navigate="/console"
          class="rounded-md border border-zinc-300 px-4 py-2 text-sm font-medium"
        >
          Open Merchant Console
        </Link>
      </div>
    </div>
    <div class="rounded-lg border border-zinc-200 bg-white p-5">
      <ShowcaseStatus surface="entry" />
    </div>
  </section>
</template>
