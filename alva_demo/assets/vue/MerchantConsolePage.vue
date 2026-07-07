<script setup lang="ts">
import { ref, computed, reactive, nextTick, watch } from "vue";
import { ashUpload as ash_upload, usePageEvent } from "alva";
import type { MerchantConsoleLiveEvents } from "../js/alva/MerchantConsoleLive.events";
import { createAlvaApi } from "../js/alva/client";
import { getStatusColor } from "./utils/ui";
import Button from "./components/ui/button/Button.vue";

import type {
  Order,
  Product,
  Conversation,
  SupportMessage,
} from "../js/alva/types";

const LOW_STOCK_THRESHOLD = 25;

type OrderStatusFilter = "all" | Order["lifecycle_status"];
type MerchantConsoleTab = "orders" | "inventory" | "support";

const props = defineProps<{
  sales_orders?: Order[];
  products?: Product[];
  conversations?: Conversation[];
  active_conversation_id?: string | null;
  support_messages?: SupportMessage[];
}>();


const pending_order_actions = ref<Record<string, "processing" | "fulfilling">>(
  {},
);
const operation_error = ref<string | null>(null);

const pending_stock_updates = ref<Record<string, boolean>>({});
const adjustment_error = ref<string | null>(null);
const stock_input = ref<Record<string, number>>({});

const media_upload = ash_upload("media", { maxFiles: 1 });
const uploading_media_product_id = ref<string | null>(null);
const upload_error = ref<string | null>(null);

const new_message_text = ref("");
const is_sending_reply = ref(false);
const send_reply_error = ref<string | null>(null);
const chat_messages_el = ref<HTMLElement | null>(null);

const order_filters = reactive<{
  status: OrderStatusFilter;
  customer_query: string;
  product_query: string;
}>({
  status: "all",
  customer_query: "",
  product_query: "",
});

const inventory_filters = reactive({
  query: "",
  low_stock_only: false,
});

const conversation_filters = reactive({
  customer_query: "",
  waiting_on_merchant_only: false,
});

const api = createAlvaApi();
const active_tab = ref<MerchantConsoleTab>("orders");
const active_conversation_id = computed(
  () => props.active_conversation_id ?? null,
);
const chat_messages = computed(() => props.support_messages ?? []);

const selectConversationEvent = usePageEvent<MerchantConsoleLiveEvents, "support.select_conversation">("support.select_conversation");

const order_status_options: Array<{ label: string; value: OrderStatusFilter }> =
  [
    { label: "All", value: "all" },
    { label: "New", value: "new" },
    { label: "Processing", value: "processing" },
    { label: "Fulfilled", value: "fulfilled" },
  ];

const all_orders = computed(() => props.sales_orders ?? []);
const all_products = computed(() => props.products ?? []);
const all_conversations = computed(() => props.conversations ?? []);

const new_orders_count = computed(() => {
  return all_orders.value.filter((order) => order.lifecycle_status === "new")
    .length;
});

const processing_orders_count = computed(() => {
  return all_orders.value.filter(
    (order) => order.lifecycle_status === "processing",
  ).length;
});

const waiting_conversations_count = computed(() => {
  return all_conversations.value.filter(
    (conversation) => conversation.needs_merchant_reply,
  ).length;
});

const low_stock_count = computed(() => {
  return all_products.value.filter(
    (product) => product.stock <= LOW_STOCK_THRESHOLD,
  ).length;
});

const merchant_attention_count = computed(() => {
  return new_orders_count.value + waiting_conversations_count.value;
});

const merchant_tabs = computed<
  Array<{
    label: string;
    value: MerchantConsoleTab;
    count: number;
    description: string;
  }>
>(() => [
  {
    label: "Orders",
    value: "orders",
    count: new_orders_count.value,
    description: "Advance the order lifecycle and inspect filters.",
  },
  {
    label: "Inventory",
    value: "inventory",
    count: low_stock_count.value,
    description: "Track low stock and update media or counts in place.",
  },
  {
    label: "Support",
    value: "support",
    count: waiting_conversations_count.value,
    description: "Work the shopper queue without losing realtime context.",
  },
]);

const has_order_query = computed(() => {
  return (
    order_filters.status !== "all" ||
    Boolean(order_filters.customer_query.trim()) ||
    Boolean(order_filters.product_query.trim())
  );
});

const has_inventory_query = computed(() => {
  return (
    inventory_filters.low_stock_only || Boolean(inventory_filters.query.trim())
  );
});

const has_conversation_query = computed(() => {
  return (
    conversation_filters.waiting_on_merchant_only ||
    Boolean(conversation_filters.customer_query.trim())
  );
});

const normalizeQuery = (value: string) => value.trim().toLowerCase();

const matchesQuery = (
  haystacks: Array<string | null | undefined>,
  query: string,
) => {
  const normalized_query = normalizeQuery(query);
  if (!normalized_query) return true;

  return haystacks.some((candidate) =>
    (candidate ?? "").toLowerCase().includes(normalized_query),
  );
};

const visible_orders = computed(() => {
  const source = all_orders.value.filter((order) => {
    if (
      order_filters.status !== "all" &&
      order.lifecycle_status !== order_filters.status
    ) {
      return false;
    }

    if (!matchesQuery([order.customer_name], order_filters.customer_query)) {
      return false;
    }

    return matchesQuery(
      [order.product?.name, getProductName(order.product_id)],
      order_filters.product_query,
    );
  });

  return [...source].sort((left, right) => {
    const left_created_at = Date.parse(left.created_at || "");
    const right_created_at = Date.parse(right.created_at || "");

    if (!Number.isNaN(left_created_at) && !Number.isNaN(right_created_at)) {
      return right_created_at - left_created_at;
    }

    return left.customer_name.localeCompare(right.customer_name);
  });
});

const visible_products = computed(() => {
  const source = all_products.value.filter((product) => {
    if (
      inventory_filters.low_stock_only &&
      product.stock > LOW_STOCK_THRESHOLD
    ) {
      return false;
    }

    return matchesQuery(
      [product.name, product.description],
      inventory_filters.query,
    );
  });

  return [...source].sort((left, right) => {
    if (left.stock === right.stock) {
      return left.name.localeCompare(right.name);
    }

    return left.stock - right.stock;
  });
});

const visible_conversations = computed(() => {
  const source = all_conversations.value.filter((conversation) => {
    if (
      conversation_filters.waiting_on_merchant_only &&
      !conversation.needs_merchant_reply
    ) {
      return false;
    }

    return matchesQuery(
      [conversation.customer_name],
      conversation_filters.customer_query,
    );
  });

  return [...source].sort((left, right) => {
    const left_time = Date.parse(left.last_message_at || "");
    const right_time = Date.parse(right.last_message_at || "");

    if (!Number.isNaN(left_time) || !Number.isNaN(right_time)) {
      return right_time - left_time;
    }

    return left.customer_name.localeCompare(right.customer_name);
  });
});

const active_conversation = computed(() => {
  if (!active_conversation_id.value) return null;

  return (
    visible_conversations.value.find(
      (conversation) => conversation.id === active_conversation_id.value,
    ) ??
    all_conversations.value.find(
      (conversation) => conversation.id === active_conversation_id.value,
    ) ??
    null
  );
});

const setPendingOrderAction = (
  order_id: string,
  action: "processing" | "fulfilling" | null,
) => {
  if (action) {
    pending_order_actions.value = {
      ...pending_order_actions.value,
      [order_id]: action,
    };
    return;
  }

  const { [order_id]: _removed, ...rest } = pending_order_actions.value;
  pending_order_actions.value = rest;
};

const setPendingStockUpdate = (product_id: string, pending: boolean) => {
  if (pending) {
    pending_stock_updates.value = {
      ...pending_stock_updates.value,
      [product_id]: true,
    };
    return;
  }

  const { [product_id]: _removed, ...rest } = pending_stock_updates.value;
  pending_stock_updates.value = rest;
};

const formatPrice = (cents: number) => {
  return `$${(cents / 100).toFixed(2)}`;
};

const formatDateTime = (value?: string | null) => {
  if (!value) return "No activity yet";

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "No activity yet";

  return date.toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
};

const getProductName = (product_id: string) => {
  if (!props.products) return product_id;
  const product = props.products.find(
    (candidate) => candidate.id === product_id,
  );
  return product ? product.name : product_id;
};

const getOrderProductName = (order: Order) => {
  return order.product?.name ?? getProductName(order.product_id);
};

const getProductStockTone = (product: Product) => {
  if (product.stock <= LOW_STOCK_THRESHOLD) {
    return "border-amber-200 bg-amber-50 text-amber-700";
  }

  return "border-zinc-200 bg-zinc-50 text-zinc-600";
};

const clearOrderFilters = () => {
  order_filters.status = "all";
  order_filters.customer_query = "";
  order_filters.product_query = "";
};

const clearInventoryFilters = () => {
  inventory_filters.query = "";
  inventory_filters.low_stock_only = false;
};

const clearConversationFilters = () => {
  conversation_filters.customer_query = "";
  conversation_filters.waiting_on_merchant_only = false;
};

const triggerMediaUpload = (product_id: string) => {
  if (uploading_media_product_id.value) return;

  uploading_media_product_id.value = product_id;
  upload_error.value = null;

  const upload_request = media_upload.dispatch(async ({ primaryReference }) => {
    const result = await api.call("catalog.upload_media", {
      id: product_id,
      media: primaryReference,
    });

    if (!result.ok) {
      throw new Error(result.error?.message || "Unknown error");
    }

    return result;
  });

  media_upload.showFilePicker();

  void upload_request
    .catch((error) => {
      upload_error.value = `Failed to upload media: ${error instanceof Error ? error.message : "Unknown error"}`;
    })
    .finally(() => {
      uploading_media_product_id.value = null;
    });
};

const beginProcessing = async (order_id: string) => {
  setPendingOrderAction(order_id, "processing");
  operation_error.value = null;

  const result = await api.call("sales.begin_processing", { id: order_id });
  setPendingOrderAction(order_id, null);

  if (!result.ok) {
    operation_error.value = `Failed to begin processing: ${result.error?.message || "Unknown error"}`;
  }
};

const fulfill = async (order_id: string) => {
  setPendingOrderAction(order_id, "fulfilling");
  operation_error.value = null;

  const result = await api.call("sales.fulfill", { id: order_id });
  setPendingOrderAction(order_id, null);

  if (!result.ok) {
    operation_error.value = `Failed to fulfill order: ${result.error?.message || "Unknown error"}`;
  }
};

const adjustStock = async (product_id: string) => {
  let new_stock = stock_input.value[product_id];
  if (new_stock === undefined) {
    const product = props.products?.find(
      (candidate) => candidate.id === product_id,
    );
    if (product) new_stock = product.stock;
  }
  if (new_stock === undefined || new_stock < 0) return;

  setPendingStockUpdate(product_id, true);
  adjustment_error.value = null;

  const result = await api.call("catalog.adjust_stock", {
    id: product_id,
    stock: new_stock,
  });

  setPendingStockUpdate(product_id, false);

  if (!result.ok) {
    adjustment_error.value = `Failed to adjust stock: ${result.error?.message || "Unknown error"}`;
  }
};

const selectConversation = async (conversation_id: string) => {
  await selectConversationEvent.call({
    conversation_id: conversation_id,
  });
};

const sendReply = async () => {
  const text = new_message_text.value.trim();
  if (!text || !active_conversation_id.value || is_sending_reply.value) return;

  new_message_text.value = "";
  is_sending_reply.value = true;
  send_reply_error.value = null;

  try {
    const result = await api.call("support.send_message", {
      text: text,
      sender: "merchant",
      conversation_id: active_conversation_id.value,
    });

    if (!result.ok) {
      send_reply_error.value = result.error?.message || "Failed to send reply.";
      new_message_text.value = text;
    }
  } finally {
    is_sending_reply.value = false;
  }
};

watch(chat_messages, async () => {
  await nextTick();
  if (chat_messages_el.value) {
    chat_messages_el.value.scrollTop = chat_messages_el.value.scrollHeight;
  }
});

const orderActionLabel = (order: Order) => {
  const pending = pending_order_actions.value[order.id];

  if (pending === "processing") return "Processing...";
  if (pending === "fulfilling") return "Fulfilling...";
  if (order.lifecycle_status === "new") return "Begin Processing";
  if (order.lifecycle_status === "processing") return "Fulfill Order";
  return "Completed";
};

const hasOrderAction = (order: Order) => {
  return (
    order.lifecycle_status === "new" || order.lifecycle_status === "processing"
  );
};

const runOrderAction = (order: Order) => {
  if (pending_order_actions.value[order.id]) return;

  if (order.lifecycle_status === "new") {
    void beginProcessing(order.id);
  } else if (order.lifecycle_status === "processing") {
    void fulfill(order.id);
  }
};
</script>

<template>
  <div class="space-y-6" data-testid="merchant-console-vue">
    <section class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
      <div
        class="flex flex-col gap-6 xl:flex-row xl:items-start xl:justify-between"
      >
        <div class="space-y-2">
          <p class="text-sm font-medium text-zinc-500">
            Merchant Console surface
          </p>
          <h1 class="text-2xl font-semibold text-zinc-950">
            Operate orders, inventory, and support from one queue.
          </h1>
          <p class="max-w-3xl text-sm text-zinc-500">
            This showcase keeps the merchant side operational: new orders, low
            stock, and customer replies stay visible while filters stay on the
            same collection-backed surface.
          </p>
        </div>

        <div class="grid gap-3 sm:grid-cols-2 xl:min-w-[420px] xl:grid-cols-2">
          <div class="rounded-lg border border-red-200 bg-red-50 p-4">
            <p class="text-xs font-medium uppercase tracking-wide text-red-600">
              Needs Attention
            </p>
            <div class="mt-2 flex items-end justify-between gap-3">
              <span class="text-3xl font-semibold text-red-700">{{
                merchant_attention_count
              }}</span>
              <span
                class="rounded-full bg-white px-2.5 py-1 text-xs font-medium text-red-700"
              >
                {{ new_orders_count }} new /
                {{ waiting_conversations_count }} chat
              </span>
            </div>
          </div>

          <div class="rounded-lg border border-zinc-200 bg-zinc-50 p-4">
            <p
              class="text-xs font-medium uppercase tracking-wide text-zinc-500"
            >
              Orders In Flight
            </p>
            <div class="mt-2 flex items-end justify-between gap-3">
              <span class="text-3xl font-semibold text-zinc-950">{{
                processing_orders_count
              }}</span>
              <span
                class="rounded-full bg-white px-2.5 py-1 text-xs font-medium text-zinc-600"
              >
                processing
              </span>
            </div>
          </div>

          <div class="rounded-lg border border-amber-200 bg-amber-50 p-4">
            <p
              class="text-xs font-medium uppercase tracking-wide text-amber-700"
            >
              Low Stock
            </p>
            <div class="mt-2 flex items-end justify-between gap-3">
              <span class="text-3xl font-semibold text-amber-800">{{
                low_stock_count
              }}</span>
              <span
                class="rounded-full bg-white px-2.5 py-1 text-xs font-medium text-amber-700"
              >
                at or below {{ LOW_STOCK_THRESHOLD }}
              </span>
            </div>
          </div>

          <div class="rounded-lg border border-emerald-200 bg-emerald-50 p-4">
            <p
              class="text-xs font-medium uppercase tracking-wide text-emerald-700"
            >
              Live Conversations
            </p>
            <div class="mt-2 flex items-end justify-between gap-3">
              <span class="text-3xl font-semibold text-emerald-800">{{
                all_conversations.length
              }}</span>
              <span
                class="rounded-full bg-white px-2.5 py-1 text-xs font-medium text-emerald-700"
              >
                {{ waiting_conversations_count }} waiting
              </span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section
      class="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm sm:p-6"
      data-testid="merchant-console-tabs"
    >
      <div
        class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between"
      >
        <div class="max-w-2xl">
          <p class="text-sm font-medium text-zinc-900">Workspace Tabs</p>
          <p class="mt-1 text-sm text-zinc-500">
            Keep the operational summary in view, then focus one workflow at a
            time without resetting query or chat state.
          </p>
        </div>

        <div
          class="grid gap-3 sm:grid-cols-3"
          role="tablist"
          aria-label="Merchant Console workflows"
        >
          <button
            v-for="tab in merchant_tabs"
            :id="`merchant-console-tab-${tab.value}`"
            :key="tab.value"
            :data-testid="`merchant-console-tab-${tab.value}`"
            type="button"
            role="tab"
            :aria-selected="active_tab === tab.value"
            :aria-controls="`merchant-console-panel-${tab.value}`"
            class="min-w-[200px] rounded-lg border px-4 py-3 text-left transition-colors"
            :class="
              active_tab === tab.value
                ? 'border-zinc-950 bg-zinc-950 text-white shadow-sm'
                : 'border-zinc-200 bg-white text-zinc-700 hover:bg-zinc-50'
            "
            @click="active_tab = tab.value"
          >
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <p class="text-sm font-medium">{{ tab.label }}</p>
                <p
                  class="mt-1 text-xs leading-5"
                  :class="
                    active_tab === tab.value ? 'text-zinc-300' : 'text-zinc-500'
                  "
                >
                  {{ tab.description }}
                </p>
              </div>
              <span
                class="inline-flex min-w-[2.25rem] items-center justify-center rounded-full px-2 py-1 text-xs font-medium"
                :class="
                  active_tab === tab.value
                    ? 'bg-white/10 text-white'
                    : 'bg-zinc-100 text-zinc-700'
                "
              >
                {{ tab.count }}
              </span>
            </div>
          </button>
        </div>
      </div>
    </section>

    <section
      v-show="active_tab === 'orders'"
      :id="'merchant-console-panel-orders'"
      aria-labelledby="merchant-console-tab-orders"
      role="tabpanel"
      class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm"
      data-testid="merchant-console-panel-orders"
    >
      <div class="mb-6 space-y-4 border-b border-zinc-200 pb-5">
        <div
          class="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between"
        >
          <div>
            <div class="flex items-center gap-2">
              <h2 class="text-xl font-semibold text-zinc-950">
                Order Lifecycle
              </h2>
              <span
                class="inline-flex items-center rounded-full bg-red-100 px-2.5 py-1 text-xs font-medium text-red-700"
              >
                {{ new_orders_count }} new
              </span>
            </div>
            <p class="mt-1 text-sm text-zinc-500">
              Filter active orders without losing the realtime route collection
              underneath.
            </p>
          </div>

          <div
            class="flex flex-wrap items-center gap-2 text-xs font-medium text-zinc-500"
          >
            <span
              class="inline-flex items-center rounded-full bg-zinc-100 px-2.5 py-1 text-zinc-700"
            >
              {{ all_orders.length }} total
            </span>
          </div>
        </div>

        <div
          class="flex flex-col gap-3 xl:flex-row xl:items-end xl:justify-between"
        >
          <div class="flex flex-wrap gap-2">
            <button
              v-for="option in order_status_options"
              :key="option.value"
              type="button"
              class="inline-flex min-w-[110px] items-center justify-center rounded-md border px-3 py-2 text-sm font-medium transition-colors"
              :class="
                order_filters.status === option.value
                  ? 'border-zinc-950 bg-zinc-950 text-white'
                  : 'border-zinc-300 bg-white text-zinc-700 hover:bg-zinc-50'
              "
              @click="order_filters.status = option.value"
            >
              {{ option.label }}
            </button>
          </div>

          <div class="flex flex-col gap-3 sm:flex-row">
            <label
              class="flex min-w-[220px] flex-col gap-2 text-sm font-medium text-zinc-700"
            >
              <span>Customer Query</span>
              <input
                v-model="order_filters.customer_query"
                data-testid="merchant-order-customer-query"
                type="text"
                placeholder="Search customer"
                class="h-10 rounded-md border border-zinc-300 px-3 text-sm font-normal text-zinc-950"
              />
            </label>
            <label
              class="flex min-w-[220px] flex-col gap-2 text-sm font-medium text-zinc-700"
            >
              <span>Product Query</span>
              <input
                v-model="order_filters.product_query"
                data-testid="merchant-order-product-query"
                type="text"
                placeholder="Search product"
                class="h-10 rounded-md border border-zinc-300 px-3 text-sm font-normal text-zinc-950"
              />
            </label>
            <Button
              variant="secondary"
              class="sm:self-end"
              :disabled="!has_order_query"
              @click="clearOrderFilters"
            >
              Reset
            </Button>
          </div>
        </div>

        <div
          v-if="operation_error"
          class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700"
        >
          {{ operation_error }}
        </div>
      </div>

      <div
        v-if="visible_orders.length === 0"
        class="rounded-lg border border-dashed border-zinc-200 bg-zinc-50 px-4 py-5 text-sm text-zinc-500"
      >
        No orders match the current Merchant Console query.
      </div>
      <div v-else class="space-y-3">
        <div
          v-for="order in visible_orders"
          :key="order.id"
          class="flex flex-col gap-4 rounded-lg border border-zinc-200 p-4 transition-colors hover:bg-zinc-50 lg:flex-row lg:items-center lg:justify-between"
        >
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <p class="font-medium text-zinc-900">
                Order by
                <span class="font-semibold">{{ order.customer_name }}</span>
              </p>
              <span
                v-if="order.lifecycle_status === 'new'"
                class="inline-flex items-center rounded-full bg-red-100 px-2.5 py-1 text-[11px] font-medium uppercase tracking-wide text-red-700"
              >
                New
              </span>
            </div>
            <p class="mt-1 text-sm text-zinc-500">
              {{ getOrderProductName(order) }} (Qty: {{ order.quantity }})
            </p>
            <p class="mt-2 text-xs text-zinc-400">
              {{ formatDateTime(order.created_at) }}
            </p>
          </div>

          <div class="flex flex-wrap items-center gap-3 lg:justify-end">
            <div
              :class="[
                'rounded-full border px-3 py-1 text-sm font-medium capitalize',
                getStatusColor(order.lifecycle_status),
              ]"
            >
              {{ order.lifecycle_status }}
            </div>

            <div class="flex min-w-[136px] justify-end">
              <Button
                v-if="hasOrderAction(order)"
                variant="secondary"
                size="sm"
                class="min-w-[136px]"
                @click="runOrderAction(order)"
                :disabled="Boolean(pending_order_actions[order.id])"
              >
                {{ orderActionLabel(order) }}
              </Button>
              <span
                v-else
                class="inline-flex min-w-[136px] items-center justify-center rounded-md border border-emerald-200 bg-emerald-50 px-3 py-1.5 text-xs font-medium text-emerald-700"
              >
                Completed
              </span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section
      v-show="active_tab === 'inventory'"
      :id="'merchant-console-panel-inventory'"
      aria-labelledby="merchant-console-tab-inventory"
      role="tabpanel"
      class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm"
      data-testid="merchant-console-panel-inventory"
    >
      <div class="mb-6 space-y-4 border-b border-zinc-200 pb-5">
        <div
          class="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between"
        >
          <div>
            <div class="flex items-center gap-2">
              <h2 class="text-xl font-semibold text-zinc-950">
                Inventory Snapshot
              </h2>
              <span
                v-if="low_stock_count > 0"
                class="inline-flex items-center rounded-full bg-amber-100 px-2.5 py-1 text-xs font-medium text-amber-700"
              >
                {{ low_stock_count }} low stock
              </span>
            </div>
            <p class="mt-1 text-sm text-zinc-500">
              Search the catalog, isolate low stock products, then update stock
              or media in place.
            </p>
          </div>

          <div
            class="flex flex-wrap items-center gap-2 text-xs font-medium text-zinc-500"
          >
            <span
              class="inline-flex items-center rounded-full bg-zinc-100 px-2.5 py-1 text-zinc-700"
            >
              {{ all_products.length }} products
            </span>
          </div>
        </div>

        <div
          class="flex flex-col gap-3 xl:flex-row xl:items-end xl:justify-between"
        >
          <label
            class="flex min-w-[260px] flex-col gap-2 text-sm font-medium text-zinc-700"
          >
            <span>Product Query</span>
            <input
              v-model="inventory_filters.query"
              data-testid="merchant-inventory-query"
              type="text"
              placeholder="Search product name or description"
              class="h-10 rounded-md border border-zinc-300 px-3 text-sm font-normal text-zinc-950"
            />
          </label>

          <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
            <label
              class="inline-flex items-center gap-2 text-sm font-medium text-zinc-700"
            >
              <input
                v-model="inventory_filters.low_stock_only"
                type="checkbox"
                class="h-4 w-4 rounded border-zinc-300"
              />
              Low stock only
            </label>
            <Button
              variant="secondary"
              :disabled="!has_inventory_query"
              @click="clearInventoryFilters"
            >
              Reset
            </Button>
          </div>
        </div>

        <div
          v-if="adjustment_error"
          class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700"
        >
          {{ adjustment_error }}
        </div>

        <div
          v-if="upload_error"
          class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700"
        >
          {{ upload_error }}
        </div>

      </div>

      <div
        v-if="visible_products.length === 0"
        class="rounded-lg border border-dashed border-zinc-200 bg-zinc-50 px-4 py-5 text-sm text-zinc-500"
      >
        No products match the current inventory query.
      </div>
      <div v-else class="space-y-4">
        <div
          v-for="product in visible_products"
          :key="product.id"
          class="flex flex-col gap-4 rounded-lg border border-zinc-200 p-4 sm:flex-row sm:items-center sm:justify-between"
        >
          <div class="flex min-w-0 items-center gap-4">
            <div
              v-if="product.media_reference"
              class="h-12 w-12 shrink-0 overflow-hidden rounded border border-zinc-200 bg-zinc-100"
            >
              <img
                :src="`/images/${product.media_reference}`"
                class="h-full w-full object-cover"
              />
            </div>
            <div
              v-else
              class="flex h-12 w-12 shrink-0 items-center justify-center rounded border border-zinc-200 bg-zinc-100 text-xs text-zinc-400"
            >
              No img
            </div>

            <div class="min-w-0">
              <div class="flex flex-wrap items-center gap-2">
                <p class="font-medium text-zinc-900">{{ product.name }}</p>
                <span
                  :class="[
                    'inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-medium',
                    getProductStockTone(product),
                  ]"
                >
                  {{ product.stock }} in stock
                </span>
              </div>
              <p class="mt-1 text-sm text-zinc-500">
                {{ product.description }}
              </p>
              <p class="mt-2 text-xs font-medium text-zinc-500">
                {{ formatPrice(product.price) }}
              </p>
            </div>
          </div>

          <div class="flex flex-wrap items-center gap-3">
            <input
              type="number"
              min="0"
              class="w-24 rounded-md border border-zinc-300 px-3 py-1.5 text-sm"
              :value="stock_input[product.id] ?? product.stock"
              @input="
                (e) =>
                  (stock_input[product.id] =
                    parseInt((e.target as HTMLInputElement).value) || 0)
              "
            />
            <Button
              size="sm"
              variant="secondary"
              class="min-w-[104px]"
              @click="adjustStock(product.id)"
              :disabled="Boolean(pending_stock_updates[product.id])"
            >
              {{
                pending_stock_updates[product.id] ? "Saving..." : "Update Stock"
              }}
            </Button>

            <div class="flex w-28 flex-col gap-1">
              <Button
                :data-testid="`merchant-upload-media-${product.id}`"
                size="sm"
                variant="secondary"
                class="min-w-[112px]"
                @click="triggerMediaUpload(product.id)"
                :disabled="uploading_media_product_id === product.id"
              >
                {{
                  uploading_media_product_id === product.id
                    ? "Uploading..."
                    : "Upload Media"
                }}
              </Button>
              <div
                v-if="uploading_media_product_id === product.id"
                class="h-1.5 w-full overflow-hidden rounded-full bg-zinc-200"
              >
                <div
                  :data-testid="`merchant-upload-progress-bar-${product.id}`"
                  class="h-full bg-blue-600 transition-all duration-300"
                  :style="{ width: `${media_upload.progress.value}%` }"
                ></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section
      v-show="active_tab === 'support'"
      :id="'merchant-console-panel-support'"
      aria-labelledby="merchant-console-tab-support"
      role="tabpanel"
      class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm"
      data-testid="merchant-console-panel-support"
    >
      <div class="mb-4 space-y-4 border-b border-zinc-200 pb-5">
        <div
          class="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between"
        >
          <div>
            <div class="flex items-center gap-2">
              <h2 class="text-xl font-semibold text-zinc-950">Support Chat</h2>
              <span
                v-if="waiting_conversations_count > 0"
                class="inline-flex items-center rounded-full bg-red-100 px-2.5 py-1 text-xs font-medium text-red-700"
              >
                {{ waiting_conversations_count }} waiting
              </span>
            </div>
            <p class="mt-1 text-sm text-zinc-500">
              Conversations now carry merchant-facing summary fields, so the
              queue and badges stay actionable.
            </p>
          </div>

          <div
            class="flex flex-wrap items-center gap-2 text-xs font-medium text-zinc-500"
          >
            <span
              class="inline-flex items-center rounded-full bg-zinc-100 px-2.5 py-1 text-zinc-700"
            >
              {{ all_conversations.length }} threads
            </span>
          </div>
        </div>

        <div
          class="flex flex-col gap-3 xl:flex-row xl:items-end xl:justify-between"
        >
          <label
            class="flex min-w-[260px] flex-col gap-2 text-sm font-medium text-zinc-700"
          >
            <span>Conversation Query</span>
            <input
              v-model="conversation_filters.customer_query"
              data-testid="merchant-conversation-query"
              type="text"
              placeholder="Search customer name"
              class="h-10 rounded-md border border-zinc-300 px-3 text-sm font-normal text-zinc-950"
            />
          </label>

          <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
            <label
              class="inline-flex items-center gap-2 text-sm font-medium text-zinc-700"
            >
              <input
                v-model="conversation_filters.waiting_on_merchant_only"
                type="checkbox"
                class="h-4 w-4 rounded border-zinc-300"
              />
              Waiting on merchant only
            </label>
            <Button
              variant="secondary"
              :disabled="!has_conversation_query"
              @click="clearConversationFilters"
            >
              Reset
            </Button>
          </div>
        </div>

      </div>

      <div
        class="flex h-[560px] overflow-hidden rounded-lg border border-zinc-200"
      >
        <div
          class="w-[320px] overflow-y-auto border-r border-zinc-200 bg-zinc-50"
        >
          <div
            v-if="visible_conversations.length === 0"
            class="p-4 text-sm text-zinc-500"
          >
            No conversations match the current query.
          </div>
          <div v-else>
            <button
              v-for="conversation in visible_conversations"
              :key="conversation.id"
              :data-testid="`merchant-conversation-${conversation.id}`"
              type="button"
              class="w-full border-b border-zinc-200 p-4 text-left transition-colors hover:bg-zinc-100"
              :class="
                active_conversation_id === conversation.id ? 'bg-zinc-100' : ''
              "
              @click="selectConversation(conversation.id)"
            >
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0">
                  <p class="font-medium text-zinc-900">
                    {{ conversation.customer_name }}
                  </p>
                  <p class="mt-1 truncate text-xs text-zinc-500">
                    {{
                      conversation.last_message_preview || "No messages yet."
                    }}
                  </p>
                </div>
                <div class="flex flex-col items-end gap-1">
                  <span
                    v-if="conversation.needs_merchant_reply"
                    class="inline-flex items-center rounded-full bg-red-100 px-2 py-0.5 text-[11px] font-medium text-red-700"
                  >
                    Waiting
                  </span>
                  <span
                    class="inline-flex min-w-[2rem] items-center justify-center rounded-full bg-white px-2 py-0.5 text-[11px] font-medium text-zinc-600"
                  >
                    {{ conversation.message_count || 0 }}
                  </span>
                </div>
              </div>
              <p class="mt-2 text-[11px] uppercase tracking-wide text-zinc-400">
                {{ formatDateTime(conversation.last_message_at) }}
              </p>
            </button>
          </div>
        </div>

        <div class="flex min-w-0 flex-1 flex-col bg-white">
          <div
            v-if="!active_conversation"
            class="flex flex-1 items-center justify-center text-sm text-zinc-500"
          >
            Select a conversation to reply.
          </div>
          <template v-else>
            <div class="border-b border-zinc-200 bg-white p-4">
              <div class="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h3 class="font-medium text-zinc-950">
                    Chatting with {{ active_conversation.customer_name }}
                  </h3>
                  <p class="mt-1 text-xs text-zinc-500">
                    {{ formatDateTime(active_conversation.last_message_at) }}
                  </p>
                </div>
                <div class="flex items-center gap-2">
                  <span
                    v-if="active_conversation.needs_merchant_reply"
                    class="inline-flex items-center rounded-full bg-red-100 px-2.5 py-1 text-xs font-medium text-red-700"
                  >
                    Waiting on merchant
                  </span>
                  <span
                    v-else
                    class="inline-flex items-center rounded-full bg-emerald-100 px-2.5 py-1 text-xs font-medium text-emerald-700"
                  >
                    Merchant replied
                  </span>
                </div>
              </div>
            </div>

            <div
              ref="chat_messages_el"
              class="flex-1 space-y-3 overflow-y-auto bg-zinc-50/30 p-4"
            >
              <div
                v-if="selectConversationEvent.error.value || send_reply_error"
                class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700"
              >
                {{ (selectConversationEvent.error.value?.message) || send_reply_error }}
              </div>

              <div
                v-if="selectConversationEvent.isLoading.value"
                class="rounded-lg border border-dashed border-zinc-200 bg-white px-4 py-5 text-sm text-zinc-500"
              >
                Loading messages...
              </div>
              <div
                v-else-if="chat_messages.length === 0"
                class="mt-4 text-center text-sm text-zinc-500"
              >
                No messages yet.
              </div>
              <div
                v-for="msg in chat_messages"
                :key="msg.id"
                :class="[
                  'flex',
                  msg.sender === 'merchant' ? 'justify-end' : 'justify-start',
                ]"
              >
                <div
                  :class="[
                    'max-w-[80%] rounded-lg px-3 py-2 text-sm',
                    msg.sender === 'merchant'
                      ? 'bg-blue-600 text-white'
                      : 'border border-zinc-200 bg-white text-zinc-900',
                  ]"
                >
                  {{ msg.text }}
                </div>
              </div>
            </div>

            <div class="flex gap-2 border-t border-zinc-200 bg-white p-3">
              <input
                v-model="new_message_text"
                data-testid="merchant-reply-input"
                @keyup.enter="sendReply"
                type="text"
                placeholder="Type a reply..."
                class="flex-1 rounded-md border border-zinc-300 px-3 py-1.5 text-sm"
              />
              <Button
                size="sm"
                @click="sendReply"
                :disabled="!new_message_text.trim() || is_sending_reply"
              >
                <span class="inline-block min-w-[52px] text-center">
                  {{ is_sending_reply ? "Sending..." : "Send" }}
                </span>
              </Button>
            </div>
          </template>
        </div>
      </div>
    </section>
  </div>
</template>
