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
      <p class="text-sm font-medium uppercase tracking-wide text-[var(--color-ink-2)]">Stream Pagination Demo</p>
      <h1 class="text-3xl font-semibold tracking-tight text-[var(--color-ink)]" style="font-family: var(--font-display);">Load more through a subscription-backed stream.</h1>
      <p class="text-sm text-[var(--color-ink-2)]">
        The older query-binding bridge is gone in this repo. This example keeps
        data server-owned: Vue asks for a larger slice with
        <code>loadMore(...)</code>, the backend reruns the stream source, and
        LiveView grows the visible stream without a second client-owned list.
      </p>
    </div>

    <div class="rounded-xl border border-[var(--color-rule)] bg-[var(--color-paper)] p-5 shadow-sm">
      <div class="mb-4 flex items-center justify-between gap-4">
        <div>
          <h2 class="text-lg font-semibold text-[var(--color-ink)]" style="font-family: var(--font-display);">Visible Feed Entries</h2>
          <p class="text-sm text-[var(--color-ink-2)]">Current stream size: {{ entries.length }}</p>
        </div>

        <button
          v-if="hasMore"
          @click="handleLoadMore"
          class="rounded-md border border-[var(--color-rule)] px-4 py-2 text-sm font-medium hover:bg-[var(--color-rule)]"
        >
          Load 5 More
        </button>
        <span
          v-else
          class="rounded-md bg-[var(--color-rule)] px-4 py-2 text-sm font-medium text-[var(--color-ink-2)]"
        >
          Fully loaded
        </span>
      </div>

      <div class="grid gap-3 md:grid-cols-2">
        <article
          v-for="entry in entries"
          :key="entry.id"
          class="rounded-lg border border-[var(--color-rule)] bg-[var(--color-rule)] px-4 py-4"
        >
          <p class="text-xs font-medium uppercase tracking-wide text-[var(--color-ink-2)]">Pattern {{ entry.position }}</p>
          <h3 class="mt-2 text-base font-semibold text-[var(--color-ink)]" style="font-family: var(--font-display);">{{ entry.title }}</h3>
          <p class="mt-2 text-sm text-[var(--color-ink-2)]">{{ entry.summary }}</p>
        </article>
      </div>
    </div>
  </section>
</template>
