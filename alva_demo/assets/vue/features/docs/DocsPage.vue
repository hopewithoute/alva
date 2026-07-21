<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { Link } from 'live_vue';
import { getAllGuides, getGuideBySlug, type GuideMeta } from './docsLoader';
import { renderMarkdownToHtml } from './docsRenderer';
import AlvaInspector from './AlvaInspector.vue';

const props = defineProps<{
  slug?: string;
}>();

const allGuides = getAllGuides();
const currentSlug = computed(() => props.slug || 'getting-started');

const currentGuide = computed<GuideMeta>(() => {
  return getGuideBySlug(currentSlug.value) || allGuides[0];
});

const renderedHtml = ref<string>('');
const isLoading = ref<boolean>(true);
const searchQuery = ref<string>('');

const categories = computed(() => {
  const map: Record<string, GuideMeta[]> = {};
  for (const guide of allGuides) {
    if (
      searchQuery.value &&
      !guide.title.toLowerCase().includes(searchQuery.value.toLowerCase()) &&
      !guide.description.toLowerCase().includes(searchQuery.value.toLowerCase())
    ) {
      continue;
    }

    if (!map[guide.category]) {
      map[guide.category] = [];
    }
    map[guide.category].push(guide);
  }
  return map;
});

const prevGuide = computed(() => {
  const idx = allGuides.findIndex((g) => g.slug === currentGuide.value.slug);
  return idx > 0 ? allGuides[idx - 1] : null;
});

const nextGuide = computed(() => {
  const idx = allGuides.findIndex((g) => g.slug === currentGuide.value.slug);
  return idx >= 0 && idx < allGuides.length - 1 ? allGuides[idx + 1] : null;
});

const loadContent = async () => {
  isLoading.value = true;
  if (currentGuide.value) {
    renderedHtml.value = await renderMarkdownToHtml(currentGuide.value.rawContent);
  }
  isLoading.value = false;
};

watch(currentSlug, loadContent, { immediate: true });

onMounted(() => {
  loadContent();
});
</script>

<template>
  <div class="space-y-6">
    <!-- Top Banner Header -->
    <div class="mb-6 border-b border-[var(--color-rule)] pb-4">
      <div class="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
        <div>
          <span class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
            Alva SDK Documentation
          </span>
          <h1 class="text-3xl font-normal tracking-tight text-[var(--color-ink)] sm:text-4xl" style="font-family: var(--font-display)">
            {{ currentGuide.title }}
          </h1>
        </div>
        <div class="mt-2 md:mt-0 text-xs text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
          Guide {{ currentGuide.order }} of {{ allGuides.length }}
        </div>
      </div>
    </div>

    <!-- Main Layout Grid -->
    <div class="grid gap-10 lg:grid-cols-[260px_1fr]">
        <!-- Sidebar Navigation -->
        <aside class="space-y-6 lg:sticky lg:top-24 lg:h-[calc(100vh-8rem)] lg:overflow-y-auto pr-2">
          <!-- Search Filter -->
          <div class="relative">
            <input
              v-model="searchQuery"
              type="text"
              placeholder="Filter guides..."
              class="w-full border border-[var(--color-rule-2)] bg-transparent px-3 py-1.5 text-xs text-[var(--color-ink)] placeholder-[var(--color-ink-2)] outline-none focus:border-[var(--color-ink)] transition-colors"
              style="font-family: var(--font-mono)"
            />
          </div>

          <!-- Category Navigation Groups -->
          <div v-for="(guides, catName) in categories" :key="catName" class="space-y-2">
            <h3 class="text-[10px] font-bold uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
              {{ catName }}
            </h3>
            <ul class="space-y-1">
              <li v-for="guide in guides" :key="guide.slug">
                <Link
                  :navigate="`/docs/${guide.slug}`"
                  class="group flex items-center justify-between border-l-2 px-3 py-1.5 text-xs transition-colors"
                  :class="[
                    currentSlug === guide.slug
                      ? 'border-[var(--color-ink)] font-semibold text-[var(--color-ink)] bg-[var(--color-rule)]/30'
                      : 'border-transparent text-[var(--color-ink-2)] hover:border-[var(--color-rule-2)] hover:text-[var(--color-ink)]'
                  ]"
                >
                  <span class="truncate">{{ guide.title }}</span>
                  <span class="text-[10px] text-[var(--color-ink-2)] opacity-60 group-hover:opacity-100" style="font-family: var(--font-mono)">
                    0{{ guide.order }}
                  </span>
                </Link>
              </li>
            </ul>
          </div>
        </aside>

        <!-- Markdown Rendered Content Area -->
        <main class="min-w-0">
          <div v-if="isLoading" class="flex items-center justify-center py-20 text-xs text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
            Loading Shiki syntax highlighter...
          </div>
          <div v-else class="prose-container border border-[var(--color-rule-2)] bg-[var(--color-paper)] p-6 sm:p-10 shadow-sm">
            <div class="prose-content text-sm leading-relaxed" v-html="renderedHtml"></div>
          </div>

          <!-- Bottom Prev / Next Navigation Footer -->
          <nav class="mt-10 flex items-center justify-between border-t border-[var(--color-rule)] pt-6">
            <div>
              <Link
                v-if="prevGuide"
                :navigate="`/docs/${prevGuide.slug}`"
                class="group inline-flex flex-col gap-1 text-left text-xs text-[var(--color-ink-2)] hover:text-[var(--color-ink)] transition-colors"
              >
                <span class="font-mono text-[10px] uppercase tracking-wider text-[var(--color-ink-2)]">← Previous</span>
                <span class="font-semibold text-sm text-[var(--color-ink)] group-hover:underline">{{ prevGuide.title }}</span>
              </Link>
            </div>

            <div>
              <Link
                v-if="nextGuide"
                :navigate="`/docs/${nextGuide.slug}`"
                class="group inline-flex flex-col items-end gap-1 text-right text-xs text-[var(--color-ink-2)] hover:text-[var(--color-ink)] transition-colors"
              >
                <span class="font-mono text-[10px] uppercase tracking-wider text-[var(--color-ink-2)]">Next →</span>
                <span class="font-semibold text-sm text-[var(--color-ink)] group-hover:underline">{{ nextGuide.title }}</span>
              </Link>
            </div>
          </nav>
        </main>
      </div>
  </div>
  <AlvaInspector />
</template>

<style>
/* Prose Markdown Content Styling */
.prose-content {
  color: var(--color-ink);
  font-family: var(--font-body);
}

.prose-content h1 {
  font-family: var(--font-display);
  font-size: 2rem;
  font-weight: 400;
  letter-spacing: -0.02em;
  margin-bottom: 1rem;
  border-bottom: 1px solid var(--color-rule);
  padding-bottom: 0.5rem;
}

.prose-content h2 {
  font-family: var(--font-display);
  font-size: 1.35rem;
  font-weight: 500;
  margin-top: 2rem;
  margin-bottom: 0.75rem;
  border-bottom: 1px dashed var(--color-rule-2);
  padding-bottom: 0.25rem;
}

.prose-content h3 {
  font-family: var(--font-display);
  font-size: 1.1rem;
  font-weight: 600;
  margin-top: 1.5rem;
  margin-bottom: 0.5rem;
}

.prose-content p {
  margin-bottom: 1rem;
}

.prose-content ul, .prose-content ol {
  margin-bottom: 1rem;
  padding-left: 1.5rem;
}

.prose-content ul {
  list-style-type: disc;
}

.prose-content ol {
  list-style-type: decimal;
}

.prose-content li {
  margin-bottom: 0.25rem;
}

.prose-content blockquote {
  border-left: 3px solid var(--color-ink);
  background-color: rgba(0, 0, 0, 0.03);
  padding: 0.75rem 1rem;
  margin: 1rem 0;
  font-style: italic;
}

.dark .prose-content blockquote {
  background-color: rgba(255, 255, 255, 0.04);
}

.prose-content table {
  width: 100%;
  border-collapse: collapse;
  margin: 1.25rem 0;
  font-size: 0.85rem;
}

.prose-content th, .prose-content td {
  border: 1px solid var(--color-rule-2);
  padding: 0.5rem 0.75rem;
  text-align: left;
}

.prose-content th {
  background-color: rgba(0, 0, 0, 0.04);
  font-family: var(--font-mono);
  font-weight: 600;
}

.dark .prose-content th {
  background-color: rgba(255, 255, 255, 0.06);
}

.prose-content code:not(pre code) {
  font-family: var(--font-mono);
  font-size: 0.85em;
  background-color: rgba(0, 0, 0, 0.06);
  padding: 0.15rem 0.35rem;
  border-radius: 2px;
}

.dark .prose-content code:not(pre code) {
  background-color: rgba(255, 255, 255, 0.1);
}

/* Shiki Code Blocks Styling */
.prose-content pre.shiki {
  padding: 1.25rem;
  overflow-x: auto;
  border-radius: 4px;
  font-family: var(--font-mono);
  font-size: 0.825rem;
  line-height: 1.6;
  margin: 1.25rem 0;
  border: 1px solid var(--color-rule-2);
}
</style>
