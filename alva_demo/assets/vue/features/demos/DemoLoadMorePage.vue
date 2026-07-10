<script setup lang="ts">
import { computed } from "vue";
import { Link } from "live_vue";
import { useRouteQueryPatch } from "../../shared/useRouteQueryPatch";

type FeedEntry = {
  id: string;
  title: string;
  summary: string;
  position: number;
};

const props = defineProps<{
  feed_entries?: FeedEntry[];
}>();

const entries = computed(() => props.feed_entries ?? []);
const nextLimit = computed(() => entries.value.length + 5);
const hasMore = computed(() => entries.value.length < 12);

const { patchQuery } = useRouteQueryPatch();

const handleLoadMore = () => {
  patchQuery({ limit: String(nextLimit.value) });
};
</script>

<template>
  <section class="space-y-6">
    <div class="max-w-3xl space-y-3">
      <p class="text-sm font-medium uppercase tracking-wide text-zinc-500">Stream Pagination Demo</p>
      <h1 class="text-3xl font-semibold tracking-tight text-zinc-950">Load more through a subscription-backed stream.</h1>
      <p class="text-sm text-zinc-600">
        The older query-binding bridge is gone in this repo. This example keeps
        data server-owned: Vue asks for a larger slice with
        <code>loadMore(...)</code>, the backend reruns the stream source, and
        LiveView grows the visible stream without a second client-owned list.
      </p>
    </div>

    <div class="rounded-xl border border-zinc-200 bg-white p-5 shadow-sm">
      <div class="mb-4 flex items-center justify-between gap-4">
        <div>
          <h2 class="text-lg font-semibold text-zinc-950">Visible Feed Entries</h2>
          <p class="text-sm text-zinc-500">Current stream size: {{ entries.length }}</p>
        </div>

        <button
          v-if="hasMore"
          @click="handleLoadMore"
          class="rounded-md border border-zinc-300 px-4 py-2 text-sm font-medium hover:bg-zinc-50"
        >
          Load 5 More
        </button>
        <span
          v-else
          class="rounded-md bg-zinc-100 px-4 py-2 text-sm font-medium text-zinc-600"
        >
          Fully loaded
        </span>
      </div>

      <div class="grid gap-3 md:grid-cols-2">
        <article
          v-for="entry in entries"
          :key="entry.id"
          class="rounded-lg border border-zinc-200 bg-zinc-50 px-4 py-4"
        >
          <p class="text-xs font-medium uppercase tracking-wide text-zinc-500">Pattern {{ entry.position }}</p>
          <h3 class="mt-2 text-base font-semibold text-zinc-950">{{ entry.title }}</h3>
          <p class="mt-2 text-sm text-zinc-600">{{ entry.summary }}</p>
        </article>
      </div>
    </div>
  </section>
</template>
