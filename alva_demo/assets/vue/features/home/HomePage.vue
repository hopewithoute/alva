<script setup lang="ts">
import { onMounted } from "vue";
import { Link } from "live_vue";
import ShowcaseStatus from "../../shared/layout/ShowcaseStatus.vue";

onMounted(() => {
  // Simple reveal observer
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-in");
        }
      });
    },
    { threshold: 0.1 }
  );
  
  document.querySelectorAll(".reveal").forEach((el) => {
    observer.observe(el);
  });
});
</script>

<template>
  <section id="commerce-showcase-entry" class="grid items-center gap-12 lg:grid-cols-[1.1fr_0.9fr]">
    <!-- Left: Title + Lede -->
    <div class="space-y-8 reveal">
      <div class="space-y-6">
        <p class="text-sm font-medium uppercase tracking-widest text-[var(--color-ink-2)]" style="font-family: var(--font-mono);">
          Alva Showcase
        </p>
        <h1 class="text-5xl font-semibold tracking-tight text-[var(--color-ink)]" style="font-family: var(--font-display); line-height: 1.1;">
          Commerce operations over Ash, LiveView, and Vue.
        </h1>
        <p class="max-w-xl text-lg text-[var(--color-ink-2)]" style="line-height: 1.6;">
          Start from either side of the sample: the Customer Storefront for shopper activity, or the Merchant Console for operational work. Built to ship—demonstrating real-time streams and signal callbacks in isolated slices.
        </p>
      </div>

      <div class="flex flex-wrap items-center gap-4">
        <Link
          navigate="/console"
          class="btn--primary px-5 py-2.5 text-sm font-medium transition-transform hover:scale-[1.02]"
        >
          Open Console
        </Link>
        <Link
          navigate="/storefront"
          class="rounded-md border border-[var(--color-rule)] bg-transparent px-5 py-2.5 text-sm font-medium text-[var(--color-ink)] transition-colors hover:border-[var(--color-rule-2)] hover:bg-[var(--color-rule)]"
        >
          View Storefront
        </Link>
      </div>
    </div>

    <!-- Right: Code Hero -->
    <div class="reveal" style="transition-delay: 150ms;">
      <div class="code-card w-full overflow-hidden text-sm shadow-xl">
        <div class="flex items-center gap-3 border-b border-[var(--color-rule-2)] bg-black/20 px-4 py-3">
          <div class="flex gap-1.5">
            <div class="h-2.5 w-2.5 rounded-full bg-zinc-600"></div>
            <div class="h-2.5 w-2.5 rounded-full bg-zinc-600"></div>
            <div class="h-2.5 w-2.5 rounded-full bg-zinc-600"></div>
          </div>
          <div class="text-xs font-medium text-zinc-400">terminal</div>
        </div>
        
        <div class="p-6">
          <div class="flex font-mono text-zinc-300">
            <span class="mr-4 text-zinc-600">$</span>
            <div class="overflow-hidden whitespace-nowrap border-r-2 border-[var(--color-accent)] pr-1" style="animation: typing 1.5s steps(20, end) forwards, blink 1s step-end infinite;">
              <span class="tok-key">mix</span> <span class="text-white">phx.server</span>
            </div>
          </div>
          
          <div class="mt-6 space-y-2 font-mono text-sm opacity-0" style="animation: fade-in 0.5s ease-out 1.6s forwards;">
            <div class="text-zinc-400">[info] Running AlvaDemoWeb.Endpoint with inline Vue...</div>
            <div class="text-zinc-400">[info] Booting commerce engine... <span class="text-zinc-500">done</span></div>
            <div class="text-white">LiveVue loaded in 24ms.</div>
          </div>
          
          <div class="mt-6 border-t border-[var(--color-rule-2)] pt-4 opacity-0" style="animation: fade-in 0.5s ease-out 1.8s forwards;">
            <div class="flex items-center justify-between">
              <div class="status--ok">200 OK</div>
              <!-- Keep original showcase status hidden or styled for dev test -->
              <div class="hidden">
                <ShowcaseStatus surface="entry" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
  @keyframes typing {
    from { width: 0 }
    to { width: 140px }
  }
  @keyframes blink {
    from, to { border-color: transparent }
    50% { border-color: var(--color-accent) }
  }
  @keyframes fade-in {
    from { opacity: 0; transform: translateY(5px); }
    to { opacity: 1; transform: none; }
  }
</style>
