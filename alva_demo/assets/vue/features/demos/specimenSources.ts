import chatMessageResource from "../../../../lib/alva_demo/demos/chat_message.ex?raw";
import feedEntryResource from "../../../../lib/alva_demo/demos/feed_entry.ex?raw";
import notificationResource from "../../../../lib/alva_demo/demos/notification.ex?raw";
import productResource from "../../../../lib/alva_demo/catalog/product.ex?raw";

import demoChatLive from "../../../../lib/alva_demo_web/live/demo_chat_live.ex?raw";
import demoLoadMoreLive from "../../../../lib/alva_demo_web/live/demo_load_more_live.ex?raw";
import demoNotificationsLive from "../../../../lib/alva_demo_web/live/demo_notifications_live.ex?raw";
import demoQueryLookupLive from "../../../../lib/alva_demo_web/live/demo_query_lookup_live.ex?raw";
import demoOptimisticFormLive from "../../../../lib/alva_demo_web/live/demo_optimistic_form_live.ex?raw";

import demoChatVue from "./DemoChatPage.vue?raw";
import demoLoadMoreVue from "./DemoLoadMorePage.vue?raw";
import demoNotificationsVue from "./DemoNotificationsPage.vue?raw";
import demoQueryLookupVue from "./DemoQueryLookupPage.vue?raw";
import demoOptimisticFormVue from "./DemoOptimisticFormPage.vue?raw";

export interface SpecimenSourceFile {
  id: string;
  name: string;
  path: string;
  category: "Resource" | "LiveView" | "Vue Component" | "DTO & Composables";
  lang: "elixir" | "vue" | "typescript";
  content: string;
}

export interface SpecimenSourceGroup {
  id: string;
  title: string;
  subtitle: string;
  files: SpecimenSourceFile[];
}

export const specimenSourcesMap: Record<string, SpecimenSourceGroup> = {
  chat: {
    id: "chat",
    title: "Specimen № 01 — Realtime Chat Stream",
    subtitle: "Ash PubSub broadcast signals & Phoenix LiveVue integration",
    files: [
      {
        id: "chat-resource",
        name: "ChatMessage Resource",
        path: "lib/alva_demo/demos/chat_message.ex",
        category: "Resource",
        lang: "elixir",
        content: chatMessageResource
      },
      {
        id: "chat-live",
        name: "DemoChatLive Controller",
        path: "lib/alva_demo_web/live/demo_chat_live.ex",
        category: "LiveView",
        lang: "elixir",
        content: demoChatLive
      },
      {
        id: "chat-vue",
        name: "DemoChatPage.vue",
        path: "assets/vue/features/demos/DemoChatPage.vue",
        category: "Vue Component",
        lang: "vue",
        content: demoChatVue
      }
    ]
  },
  "load-more": {
    id: "load-more",
    title: "Specimen № 02 — Infinite Subscription Feed",
    subtitle: "Server-owned stream pagination with incremental slice requests",
    files: [
      {
        id: "feed-resource",
        name: "FeedEntry Resource",
        path: "lib/alva_demo/demos/feed_entry.ex",
        category: "Resource",
        lang: "elixir",
        content: feedEntryResource
      },
      {
        id: "feed-live",
        name: "DemoLoadMoreLive Controller",
        path: "lib/alva_demo_web/live/demo_load_more_live.ex",
        category: "LiveView",
        lang: "elixir",
        content: demoLoadMoreLive
      },
      {
        id: "feed-vue",
        name: "DemoLoadMorePage.vue",
        path: "assets/vue/features/demos/DemoLoadMorePage.vue",
        category: "Vue Component",
        lang: "vue",
        content: demoLoadMoreVue
      }
    ]
  },
  notifications: {
    id: "notifications",
    title: "Specimen № 03 — Semantic Signal Log",
    subtitle: "Standalone PubSub signal listeners without local state reconciliation",
    files: [
      {
        id: "signal-resource",
        name: "Notification Resource",
        path: "lib/alva_demo/demos/notification.ex",
        category: "Resource",
        lang: "elixir",
        content: notificationResource
      },
      {
        id: "signal-live",
        name: "DemoNotificationsLive Controller",
        path: "lib/alva_demo_web/live/demo_notifications_live.ex",
        category: "LiveView",
        lang: "elixir",
        content: demoNotificationsLive
      },
      {
        id: "signal-vue",
        name: "DemoNotificationsPage.vue",
        path: "assets/vue/features/demos/DemoNotificationsPage.vue",
        category: "Vue Component",
        lang: "vue",
        content: demoNotificationsVue
      }
    ]
  },
  "query-lookup": {
    id: "query-lookup",
    title: "Specimen № 04 — Query Lookups & AST Filters",
    subtitle: "Single-record detail queries, background polling & AST filters",
    files: [
      {
        id: "product-resource-lookup",
        name: "Product Resource",
        path: "lib/alva_demo/catalog/product.ex",
        category: "Resource",
        lang: "elixir",
        content: productResource
      },
      {
        id: "lookup-live",
        name: "DemoQueryLookupLive Controller",
        path: "lib/alva_demo_web/live/demo_query_lookup_live.ex",
        category: "LiveView",
        lang: "elixir",
        content: demoQueryLookupLive
      },
      {
        id: "lookup-vue",
        name: "DemoQueryLookupPage.vue",
        path: "assets/vue/features/demos/DemoQueryLookupPage.vue",
        category: "Vue Component",
        lang: "vue",
        content: demoQueryLookupVue
      }
    ]
  },
  "optimistic-form": {
    id: "optimistic-form",
    title: "Specimen № 05 — Optimistic Form UI & Server Rollback",
    subtitle: "Instant client-side form mutation feedback with server state restoration",
    files: [
      {
        id: "product-resource-form",
        name: "Product Resource",
        path: "lib/alva_demo/catalog/product.ex",
        category: "Resource",
        lang: "elixir",
        content: productResource
      },
      {
        id: "form-live",
        name: "DemoOptimisticFormLive Controller",
        path: "lib/alva_demo_web/live/demo_optimistic_form_live.ex",
        category: "LiveView",
        lang: "elixir",
        content: demoOptimisticFormLive
      },
      {
        id: "form-vue",
        name: "DemoOptimisticFormPage.vue",
        path: "assets/vue/features/demos/DemoOptimisticFormPage.vue",
        category: "Vue Component",
        lang: "vue",
        content: demoOptimisticFormVue
      }
    ]
  }
};
