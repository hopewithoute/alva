<script setup lang="ts">
import { computed, ref } from "vue";
import Button from "@/vue/shared/ui/button/Button.vue";
import { useRouteQueryPatch } from "@/vue/shared/useRouteQueryPatch";
import SpecimenSourceViewerModal from "@/vue/shared/components/SpecimenSourceViewerModal.vue";

const isSourceModalOpen = ref(false);

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
  <div class="w-full py-4">
    <article class="space-y-16">
      <!-- Header -->
      <header class="space-y-8 border-b border-[var(--color-rule)] pb-12">
        <h1
          class="text-4xl font-normal text-[var(--color-ink)] md:text-5xl"
          style="font-family: var(--font-display); line-height: 1.1"
        >
          Load more through a subscription-backed stream.
        </h1>
        <div class="flex flex-col justify-between gap-6 sm:flex-row sm:items-end">
          <p class="max-w-[65ch] text-lg text-[var(--color-ink-2)]" style="line-height: 1.7">
            Keeps data server-owned: Vue requests a larger dataset slice with
            <code class="bg-[var(--color-rule-2)] px-1.5 py-0.5 font-mono text-sm"
              >loadMore(...)</code
            >, LiveView updates the stream source, and components render incremental items
            seamlessly.
          </p>
          <Button variant="specimen" @click="isSourceModalOpen = true">
            <span>⚡ INSPECT SPECIMEN CODE</span>
          </Button>
        </div>
      </header>

      <!-- Main Document Area -->
      <section class="space-y-12">
        <div class="flex items-baseline justify-between">
          <h2
            class="text-2xl font-normal text-[var(--color-ink)]"
            style="font-family: var(--font-display)"
          >
            Visible Feed Entries
          </h2>
          <span
            class="text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
          >
            Size: {{ entries.length }}
          </span>
        </div>

        <div class="grid grid-cols-1 gap-x-12 gap-y-16 md:grid-cols-2">
          <article v-for="entry in entries" :key="entry.id" class="space-y-3">
            <div class="border-t border-[var(--color-ink)] pt-4">
              <p
                class="text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
                style="font-family: var(--font-mono)"
              >
                Pattern {{ entry.position }}
              </p>
            </div>
            <h3
              class="text-xl font-normal text-[var(--color-ink)]"
              style="font-family: var(--font-display)"
            >
              {{ entry.title }}
            </h3>
            <p class="text-base text-[var(--color-ink-2)]" style="line-height: 1.7">
              {{ entry.summary }}
            </p>
          </article>
        </div>

        <div class="flex justify-center border-t border-[var(--color-rule)] pt-12">
          <button
            v-if="hasMore"
            @click="handleLoadMore"
            class="btn--primary px-8 py-4 text-xs font-semibold transition-opacity hover:opacity-90"
          >
            Load 5 More
          </button>
          <span
            v-else
            class="text-sm italic text-[var(--color-ink-2)]"
            style="font-family: var(--font-display)"
          >
            Fully loaded. No more entries.
          </span>
        </div>
      </section>
    </article>
    <SpecimenSourceViewerModal v-model="isSourceModalOpen" specimen-id="load-more" />
  </div>
</template>
