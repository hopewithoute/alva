<script setup lang="ts">
import { ref, onMounted, onUnmounted } from "vue";
import { Link } from "live_vue";

const isCommandPaletteOpen = ref(false);
const isDarkMode = ref(false);

const toggleDarkMode = () => {
  isDarkMode.value = !isDarkMode.value;
  if (isDarkMode.value) {
    document.documentElement.classList.add('dark');
  } else {
    document.documentElement.classList.remove('dark');
  }
};

const handleKeydown = (e: KeyboardEvent) => {
  if ((e.metaKey || e.ctrlKey) && e.key === "k") {
    e.preventDefault();
    isCommandPaletteOpen.value = true;
  }
  if (e.key === "Escape" && isCommandPaletteOpen.value) {
    isCommandPaletteOpen.value = false;
  }
};

onMounted(() => {
  if (document.documentElement.classList.contains('dark')) {
    isDarkMode.value = true;
  } else if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
    isDarkMode.value = true;
    document.documentElement.classList.add('dark');
  }
  window.addEventListener("keydown", handleKeydown);
});
onUnmounted(() => {
  window.removeEventListener("keydown", handleKeydown);
});
</script>

<template>
  <div class="min-h-screen">
    <header class="nav sticky top-0 z-40 bg-[var(--color-paper)]/80">
      <nav class="mx-auto flex max-w-7xl items-center justify-between px-5 py-4">
        <div class="flex items-center gap-8">
          <Link navigate="/" class="flex items-center gap-2 text-sm font-semibold tracking-wide text-[var(--color-ink)]" style="font-family: var(--font-display);">
            <img :src="'/images/alva-logo.png'" alt="Alva" class="h-6 w-auto object-contain" />
            Alva
          </Link>
          <div class="hidden items-center gap-6 text-sm md:flex">
            <Link navigate="/storefront" class="hover:text-[var(--color-accent)] transition-colors">
              Storefront
            </Link>
            <Link navigate="/console" class="hover:text-[var(--color-accent)] transition-colors">
              Console
            </Link>
          </div>
        </div>

        <div class="flex items-center gap-4">
          <button 
            @click="isCommandPaletteOpen = true"
            class="hidden md:flex items-center gap-3 rounded-md border border-[var(--color-rule)] bg-transparent px-3 py-1.5 text-xs text-[var(--color-ink-2)] hover:border-[var(--color-rule-2)] transition-colors"
          >
            <span>Search demos...</span>
            <kbd style="font-family: var(--font-mono); font-size: 10px;" class="rounded border border-[var(--color-rule)] px-1.5 py-0.5">⌘K</kbd>
          </button>
          <button @click="toggleDarkMode" class="rounded-md p-2 text-[var(--color-ink-2)] hover:bg-[var(--color-rule)] transition-colors">
            <svg v-if="!isDarkMode" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
            </svg>
            <svg v-else class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
            </svg>
          </button>
          <Link navigate="/console" class="btn--primary px-4 py-2 text-sm font-medium transition-colors hover:opacity-90">
            Open Console
          </Link>
        </div>
      </nav>
    </header>

    <main class="mx-auto max-w-7xl px-5 py-12 md:py-24">
      <slot />
    </main>

    <!-- Command Palette Overlay -->
    <div v-if="isCommandPaletteOpen" class="fixed inset-0 z-50 flex items-start justify-center pt-[20vh]" role="dialog" aria-modal="true">
      <div class="fixed inset-0 bg-[var(--color-ink)]/20 backdrop-blur-sm" @click="isCommandPaletteOpen = false"></div>
      <div class="relative w-full max-w-xl overflow-hidden rounded-xl border border-[var(--color-rule-2)] bg-[var(--color-paper)] shadow-2xl">
        <div class="flex items-center border-b border-[var(--color-rule)] px-4 py-3">
          <svg class="mr-3 h-5 w-5 text-[var(--color-ink-2)]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          <input type="text" class="w-full bg-transparent text-sm text-[var(--color-ink)] outline-none placeholder:text-[var(--color-ink-2)]" placeholder="Search demos and docs..." style="font-family: var(--font-body);" autofocus />
          <kbd style="font-family: var(--font-mono); font-size: 10px;" class="rounded border border-[var(--color-rule)] px-1.5 py-0.5 text-[var(--color-ink-2)]">ESC</kbd>
        </div>
        <div class="p-2">
          <div class="px-2 py-1.5 text-xs font-semibold text-[var(--color-ink-2)] uppercase tracking-wider mt-2 mb-1" style="font-family: var(--font-mono);">Realtime Demos</div>
          <Link navigate="/demo/chat" @click="isCommandPaletteOpen = false" class="block w-full rounded-md px-3 py-2 text-left text-sm hover:bg-[var(--color-rule)] hover:text-[var(--color-accent)] transition-colors">
            Chat (Stream)
          </Link>
          <Link navigate="/demo/load-more" @click="isCommandPaletteOpen = false" class="block w-full rounded-md px-3 py-2 text-left text-sm hover:bg-[var(--color-rule)] hover:text-[var(--color-accent)] transition-colors">
            Infinite Scroll (Signal)
          </Link>
          <Link navigate="/demo/notifications" @click="isCommandPaletteOpen = false" class="block w-full rounded-md px-3 py-2 text-left text-sm hover:bg-[var(--color-rule)] hover:text-[var(--color-accent)] transition-colors">
            Toast (Global)
          </Link>
        </div>
      </div>
    </div>
  </div>
</template>
