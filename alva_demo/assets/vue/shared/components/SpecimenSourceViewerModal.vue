<script setup lang="ts">
import { ref, computed, watch } from "vue";
import { specimenSourcesMap } from "@/vue/features/demos/specimenSources";
import { highlightCode } from "@/vue/features/docs/docsRenderer";

const props = defineProps<{
  modelValue: boolean;
  specimenId: string;
}>();

const emit = defineEmits<{
  (e: "update:modelValue", value: boolean): void;
}>();

const currentGroup = computed(() => {
  return specimenSourcesMap[props.specimenId] || null;
});

const selectedFileId = ref("");
const highlightedCodeHtml = ref("");
const isCopying = ref(false);
const isLoadingCode = ref(false);

const selectedFile = computed(() => {
  if (!currentGroup.value) return null;
  return (
    currentGroup.value.files.find((f) => f.id === selectedFileId.value) ||
    currentGroup.value.files[0] ||
    null
  );
});

const renderCurrentCode = async () => {
  if (!selectedFile.value) {
    highlightedCodeHtml.value = "";
    return;
  }
  isLoadingCode.value = true;
  highlightedCodeHtml.value = await highlightCode(
    selectedFile.value.content,
    selectedFile.value.lang
  );
  isLoadingCode.value = false;
};

watch(
  () => props.specimenId,
  () => {
    if (currentGroup.value && currentGroup.value.files.length > 0) {
      selectedFileId.value = currentGroup.value.files[0].id;
    }
  },
  { immediate: true }
);

watch(selectedFile, renderCurrentCode, { immediate: true });

import { onMounted, onUnmounted } from "vue";

let themeObserver: MutationObserver | null = null;

onMounted(() => {
  if (typeof document !== "undefined") {
    themeObserver = new MutationObserver(() => {
      renderCurrentCode();
    });
    themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"]
    });
  }
});

onUnmounted(() => {
  if (themeObserver) {
    themeObserver.disconnect();
  }
});

const closeModal = () => {
  emit("update:modelValue", false);
};

const copyCode = async () => {
  if (!selectedFile.value) return;
  try {
    await navigator.clipboard.writeText(selectedFile.value.content);
    isCopying.value = true;
    setTimeout(() => {
      isCopying.value = false;
    }, 2000);
  } catch (e) {
    console.error("Failed to copy code", e);
  }
};

const lineCount = computed(() => {
  if (!selectedFile.value) return 0;
  return selectedFile.value.content.split("\n").length;
});
</script>

<template>
  <Teleport to="body">
    <div
      v-if="modelValue && currentGroup"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/75 p-4 backdrop-blur-sm md:p-8"
      @click.self="closeModal"
    >
      <div
        class="flex h-[88vh] w-full max-w-6xl flex-col border border-[var(--color-rule-2)] bg-[var(--color-paper)] text-[var(--color-ink)] shadow-2xl"
      >
        <!-- Modal Top Bar -->
        <header
          class="flex items-center justify-between border-b border-[var(--color-rule)] px-6 py-4"
        >
          <div class="space-y-1">
            <div class="flex items-center gap-3">
              <span
                class="font-mono text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-accent)]"
              >
                SPECIMEN CODE INSPECTOR
              </span>
              <span
                class="border border-[var(--color-rule-2)] px-1.5 py-0.5 font-mono text-[10px] uppercase text-[var(--color-ink-2)]"
              >
                LIVE SOURCE
              </span>
            </div>
            <h2
              class="text-xl font-normal tracking-tight text-[var(--color-ink)] sm:text-2xl"
              style="font-family: var(--font-display)"
            >
              {{ currentGroup.title }}
            </h2>
          </div>

          <div class="flex items-center gap-4">
            <button
              @click="copyCode"
              class="hidden items-center gap-2 border border-[var(--color-rule-2)] bg-transparent px-3 py-1.5 font-mono text-xs text-[var(--color-ink)] transition-colors hover:border-[var(--color-ink)] sm:flex"
            >
              <span>{{ isCopying ? "✓ COPIED!" : "📋 COPY SOURCE" }}</span>
            </button>

            <button
              @click="closeModal"
              class="border border-[var(--color-rule-2)] p-2 font-mono text-xs text-[var(--color-ink-2)] transition-colors hover:border-[var(--color-ink)] hover:text-[var(--color-ink)]"
              title="Close modal (ESC)"
            >
              ✕
            </button>
          </div>
        </header>

        <!-- Main Body Grid: File Tree + Code Editor -->
        <div class="grid flex-1 grid-cols-1 overflow-hidden md:grid-cols-[280px_1fr]">
          <!-- Left Rail: File Tree -->
          <aside
            class="flex flex-col border-b border-[var(--color-rule)] bg-[var(--color-paper-2)] md:border-b-0 md:border-r"
          >
            <div class="border-b border-[var(--color-rule)] p-4">
              <span
                class="font-mono text-[10px] uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
              >
                RELEVANT SPECIMEN FILES
              </span>
            </div>

            <div class="flex-1 space-y-3 overflow-y-auto p-4">
              <div v-for="file in currentGroup.files" :key="file.id">
                <button
                  @click="selectedFileId = file.id"
                  class="flex w-full flex-col gap-1.5 border p-3 text-left font-mono text-xs transition-all"
                  :class="[
                    selectedFileId === file.id
                      ? 'border-[var(--color-ink)] bg-[var(--color-paper)] font-semibold text-[var(--color-ink)] shadow-sm'
                      : 'border-transparent text-[var(--color-ink-2)] hover:border-[var(--color-rule-2)] hover:text-[var(--color-ink)]'
                  ]"
                >
                  <div class="flex items-center justify-between">
                    <span
                      class="text-[10px] font-semibold uppercase tracking-wider text-[var(--color-accent)]"
                    >
                      {{ file.category }}
                    </span>
                    <span
                      class="border border-[var(--color-rule-2)] px-1 py-0.5 text-[9px] uppercase"
                      :class="
                        file.lang === 'elixir'
                          ? 'text-amber-500'
                          : file.lang === 'vue'
                            ? 'text-emerald-500'
                            : 'text-sky-500'
                      "
                    >
                      {{ file.lang }}
                    </span>
                  </div>
                  <span class="truncate font-sans text-sm font-medium text-[var(--color-ink)]">
                    {{ file.name }}
                  </span>
                  <span class="truncate text-[10px] text-[var(--color-ink-2)]">
                    {{ file.path }}
                  </span>
                </button>
              </div>
            </div>
          </aside>

          <!-- Right Panel: Code Viewer -->
          <main
            v-if="selectedFile"
            class="flex flex-col overflow-hidden bg-[var(--color-paper-2)] text-[var(--color-ink)] dark:bg-[#0d1117] dark:text-gray-200"
          >
            <!-- File Info Header -->
            <div
              class="flex items-center justify-between border-b border-[var(--color-rule-2)] bg-[var(--color-paper)] px-6 py-3 font-mono text-xs text-[var(--color-ink-2)] dark:border-gray-800 dark:bg-[#161b22] dark:text-gray-400"
            >
              <div class="flex items-center gap-3 truncate">
                <span class="font-bold text-[var(--color-accent)]">$</span>
                <span class="truncate font-semibold text-[var(--color-ink)] dark:text-gray-200">{{
                  selectedFile.path
                }}</span>
              </div>
              <div class="flex shrink-0 items-center gap-4 text-[10px]">
                <span>{{ lineCount }} lines</span>
                <span class="font-semibold uppercase tracking-widest text-[var(--color-accent)]">{{
                  selectedFile.lang
                }}</span>
              </div>
            </div>

            <!-- Code Content Body -->
            <div class="flex-1 overflow-auto p-6 font-mono text-xs leading-relaxed">
              <div
                v-if="isLoadingCode"
                class="flex h-full items-center justify-center text-gray-500"
              >
                <span>Rendering syntax highlighting...</span>
              </div>
              <div v-else class="shiki-container select-text" v-html="highlightedCodeHtml"></div>
            </div>
          </main>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
:deep(.shiki-container pre) {
  background-color: transparent !important;
  margin: 0;
  padding: 0;
  font-family: var(--font-mono);
  font-size: 13px;
  line-height: 1.65;
}
:deep(.shiki-container code) {
  font-family: var(--font-mono);
}
</style>
