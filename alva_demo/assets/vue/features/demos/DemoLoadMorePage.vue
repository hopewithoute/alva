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
  <div class="max-w-4xl mx-auto py-16 px-6 lg:px-12">
    <article class="space-y-16">
      
      <!-- Header -->
      <header class="space-y-8 pb-12 border-b border-[var(--color-rule)]">
        <h1 class="text-4xl md:text-5xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display); line-height: 1.1;">
          Load more through a subscription-backed stream.
        </h1>
        <p class="text-lg text-[var(--color-ink-2)] max-w-[65ch]" style="line-height: 1.7;">
          The older query-binding bridge is gone in this repo. This example keeps
          data server-owned: Vue asks for a larger slice with
          <code class="px-1.5 py-0.5 bg-[var(--color-rule-2)] font-mono text-sm">loadMore(...)</code>, the backend reruns the stream source, and
          LiveView grows the visible stream without a second client-owned list.
        </p>
      </header>

      <!-- Main Document Area -->
      <section class="space-y-12">
        <div class="flex items-baseline justify-between">
          <h2 class="text-2xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display);">Visible Feed Entries</h2>
          <span class="text-xs text-[var(--color-ink-2)] uppercase tracking-[0.1em]" style="font-family: var(--font-mono)">
            Size: {{ entries.length }}
          </span>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-x-12 gap-y-16">
          <article
            v-for="entry in entries"
            :key="entry.id"
            class="space-y-3"
          >
            <div class="border-t border-[var(--color-ink)] pt-4">
              <p class="text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">Pattern {{ entry.position }}</p>
            </div>
            <h3 class="text-xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display);">{{ entry.title }}</h3>
            <p class="text-base text-[var(--color-ink-2)]" style="line-height: 1.7;">{{ entry.summary }}</p>
          </article>
        </div>

        <div class="pt-12 border-t border-[var(--color-rule)] flex justify-center">
          <button
            v-if="hasMore"
            @click="handleLoadMore"
            class="btn--primary px-8 py-4 text-xs font-semibold hover:opacity-90 transition-opacity"
          >
            Load 5 More
          </button>
          <span
            v-else
            class="text-sm italic text-[var(--color-ink-2)]" style="font-family: var(--font-display)"
          >
            Fully loaded. No more entries.
          </span>
        </div>
      </section>

    </article>
  </div>
</template>
