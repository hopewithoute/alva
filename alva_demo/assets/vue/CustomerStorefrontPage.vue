<script setup lang="ts">
import { ref, computed, nextTick, watch } from "vue";
import { createAlvaApi } from "../js/alva/client";
import { useChatMessages } from "./composables/useChatMessages";
import { getStatusColor } from "./utils/ui";
import Button from "./components/ui/button/Button.vue";

import type {
  Order,
  Product,
  Conversation,
  SupportMessage,
} from "../js/alva/types";

const props = defineProps<{
  sales_orders?: Order[];
  products?: Product[];
  support_messages?: SupportMessage[];
}>();

const customer_name = ref("");
const order_error = ref<string | null>(null);
const order_notice = ref<string | null>(null);
const ordering_product_id = ref<string | null>(null);
const is_orders_open = ref(false);
const selected_order_id = ref<string | null>(null);

const active_conversation = ref<Conversation | null>(null);
const connected_customer_name = ref<string | null>(null);
const historical_messages = ref<SupportMessage[]>([]);
const new_message_text = ref("");
const is_joining_chat = ref(false);
const is_sending_message = ref(false);
const chat_error = ref<string | null>(null);
const chat_messages_el = ref<HTMLElement | null>(null);
let chat_request_id = 0;

const api = createAlvaApi();

const formatPrice = (cents: number) => {
  return `$${(cents / 100).toFixed(2)}`;
};

const current_customer_name = computed(() => customer_name.value.trim());

const getProductName = (product_id: string) => {
  const product = props.products?.find(
    (candidate: Product) => candidate.id === product_id,
  );
  return product ? product.name : product_id;
};

const customer_orders = computed(() => {
  const customerName = current_customer_name.value.toLowerCase();

  if (!customerName || !props.sales_orders) {
    return [];
  }

  return props.sales_orders.filter(
    (order) => order.customer_name.trim().toLowerCase() === customerName,
  );
});

const recent_order_count = computed(() => customer_orders.value.length);
const recent_order_items = computed(() => {
  return customer_orders.value.reduce((sum, order) => sum + order.quantity, 0);
});

const selected_order = computed(() => {
  if (!selected_order_id.value) {
    return customer_orders.value[0] ?? null;
  }

  return (
    customer_orders.value.find(
      (order) => order.id === selected_order_id.value,
    ) ??
    customer_orders.value[0] ??
    null
  );
});

const is_chat_connected = computed(() => {
  return Boolean(
    active_conversation.value &&
    connected_customer_name.value === current_customer_name.value,
  );
});

const chat_status = computed(() => {
  if (!current_customer_name.value) {
    return "Enter your customer name to unlock orders and support chat.";
  }

  if (is_joining_chat.value) {
    return "Connecting your support conversation...";
  }

  if (is_chat_connected.value) {
    return `Connected as ${connected_customer_name.value}.`;
  }

  return "Connect once, then keep chatting with merchant support here.";
});

const active_conversation_id = computed(() => active_conversation.value?.id);
const chat_messages = useChatMessages(
  active_conversation_id,
  historical_messages,
  computed(() => props.support_messages),
);

const scrollChatToBottom = async () => {
  await nextTick();

  if (chat_messages_el.value) {
    chat_messages_el.value.scrollTop = chat_messages_el.value.scrollHeight;
  }
};

const resetChatState = () => {
  chat_request_id += 1;
  active_conversation.value = null;
  connected_customer_name.value = null;
  historical_messages.value = [];
  new_message_text.value = "";
  is_joining_chat.value = false;
  is_sending_message.value = false;
  chat_error.value = null;
};

const openRecentOrders = () => {
  if (customer_orders.value.length === 0) return;

  if (!selected_order_id.value) {
    selected_order_id.value = customer_orders.value[0].id;
  }

  is_orders_open.value = true;
};

const closeRecentOrders = () => {
  is_orders_open.value = false;
};

const selectOrder = (order_id: string) => {
  selected_order_id.value = order_id;
};

const buyProduct = async (product_id: string) => {
  const customerName = current_customer_name.value;
  if (!customerName) {
    order_error.value = "Enter your name before placing an order.";
    order_notice.value = null;
    return;
  }

  const product = props.products?.find(
    (candidate: Product) => candidate.id === product_id,
  );
  ordering_product_id.value = product_id;
  order_error.value = null;
  order_notice.value = null;

  const result = await api.call("sales.create_order", {
    customer_name: customerName,
    product_id: product_id,
    quantity: 1,
  });

  ordering_product_id.value = null;

  if (result.ok) {
    order_notice.value = `Order placed for ${product?.name || "this product"}. Open Recent Orders to track the status.`;
    selected_order_id.value = result.data.id;
    is_orders_open.value = true;
  } else {
    order_error.value = `Failed to create order: ${result.error?.message || "Unknown error"}`;
  }
};

const joinChat = async () => {
  const customerName = current_customer_name.value;
  if (!customerName || is_joining_chat.value) return;

  if (is_chat_connected.value) {
    chat_error.value = null;
    await scrollChatToBottom();
    return;
  }

  const requestId = ++chat_request_id;
  is_joining_chat.value = true;
  chat_error.value = null;

  try {
    const result = await api.call("support.create", {
      customer_name: customerName,
    });

    if (requestId !== chat_request_id) return;

    if (result.ok) {
      active_conversation.value = result.data as Conversation;
      connected_customer_name.value = customerName;
      historical_messages.value = [];

      const messagesRes = await api.call("support.list_messages", {
        conversation_id: active_conversation.value.id,
      });

      if (requestId !== chat_request_id) return;

      if (messagesRes.ok) {
        historical_messages.value = messagesRes.data as SupportMessage[];
        await scrollChatToBottom();
      } else {
        chat_error.value =
          messagesRes.error?.message || "Failed to load messages.";
      }
    } else {
      chat_error.value = result.error?.message || "Failed to join chat.";
    }
  } finally {
    if (requestId === chat_request_id) {
      is_joining_chat.value = false;
    }
  }
};

const sendMessage = async () => {
  const text = new_message_text.value.trim();
  if (!text || is_sending_message.value) return;

  if (!is_chat_connected.value) {
    await joinChat();
  }

  if (!active_conversation.value) return;

  new_message_text.value = "";
  is_sending_message.value = true;
  chat_error.value = null;

  try {
    const result = await api.call("support.send_message", {
      text: text,
      sender: "shopper",
      conversation_id: active_conversation.value.id,
    });

    if (!result.ok) {
      chat_error.value = result.error?.message || "Failed to send message.";
      new_message_text.value = text;
    } else {
      await scrollChatToBottom();
    }
  } finally {
    is_sending_message.value = false;
  }
};

watch(chat_messages, async () => {
  await scrollChatToBottom();
});

watch(
  customer_orders,
  (orders) => {
    if (orders.length === 0) {
      selected_order_id.value = null;
      is_orders_open.value = false;
      return;
    }

    if (
      !selected_order_id.value ||
      !orders.some((order) => order.id === selected_order_id.value)
    ) {
      selected_order_id.value = orders[0].id;
    }
  },
  { immediate: true },
);

watch(current_customer_name, (next, prev) => {
  if (!next) {
    order_notice.value = null;
    closeRecentOrders();
  }

  if (connected_customer_name.value && next !== connected_customer_name.value) {
    resetChatState();
  }

  if (prev && next !== prev) {
    order_error.value = null;
    order_notice.value = null;
  }
});
</script>

<template>
  <div
    class="grid gap-8 xl:grid-cols-[minmax(0,1fr)_360px]"
    data-testid="customer-storefront-vue"
  >
    <section class="min-w-0 space-y-6">
      <div class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
        <div class="space-y-6">
          <div class="space-y-2">
            <p class="text-sm font-medium text-zinc-500">
              Customer Storefront surface
            </p>
            <h1 class="text-2xl font-semibold text-zinc-950">
              Browse the catalog and keep your support thread close.
            </h1>
            <p class="max-w-2xl text-sm text-zinc-500">
              Enter your customer name once to place orders, track status from
              Recent Orders, and keep chatting with merchant support in the side
              panel.
            </p>
          </div>

          <div
            class="flex flex-col gap-3 lg:flex-row lg:items-end lg:justify-between"
          >
            <label
              class="flex min-w-[240px] flex-col gap-2 text-sm font-medium text-zinc-700"
            >
              <span>Your Name</span>
              <input
                id="customerName"
                v-model="customer_name"
                type="text"
                placeholder="e.g. Alice"
                class="h-11 rounded-md border border-zinc-300 px-3 text-sm font-normal text-zinc-950"
              />
            </label>

            <div class="flex flex-col gap-2 sm:flex-row sm:items-end">
              <button
                type="button"
                class="inline-flex h-11 min-w-[190px] items-center justify-between rounded-md border border-zinc-300 bg-white px-4 text-left transition-colors hover:bg-zinc-50 disabled:cursor-not-allowed disabled:border-zinc-200 disabled:bg-zinc-100"
                :disabled="recent_order_count === 0"
                @click="openRecentOrders"
              >
                <span class="space-y-0.5">
                  <span
                    class="block text-[11px] font-medium uppercase tracking-wide text-zinc-500"
                    >Recent Orders</span
                  >
                  <span class="block text-sm font-medium text-zinc-950">
                    {{
                      recent_order_count === 0
                        ? "No orders yet"
                        : `${recent_order_count} orders`
                    }}
                  </span>
                </span>
                <span
                  class="inline-flex min-w-[2rem] items-center justify-center rounded-full bg-zinc-950 px-2 py-1 text-xs font-semibold text-white"
                >
                  {{ recent_order_items }}
                </span>
              </button>
            </div>
          </div>
        </div>

        <div
          v-if="order_error"
          class="mt-4 rounded-md bg-red-50 p-3 text-sm text-red-700"
        >
          {{ order_error }}
        </div>
        <div
          v-if="order_notice"
          class="mt-4 rounded-md bg-emerald-50 p-3 text-sm text-emerald-700"
        >
          {{ order_notice }}
        </div>
      </div>

      <div
        v-if="!props.products"
        class="rounded-xl border border-dashed border-zinc-200 bg-white p-6 text-sm text-zinc-500"
      >
        Loading catalog...
      </div>
      <div v-else class="grid grid-cols-1 gap-6 sm:grid-cols-2 2xl:grid-cols-3">
        <div
          v-for="product in props.products"
          :key="product.id"
          class="flex flex-col overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm"
        >
          <div
            class="flex h-48 items-center justify-center overflow-hidden bg-zinc-100"
          >
            <img
              v-if="product.media_reference"
              :src="`/images/${product.media_reference}`"
              :alt="product.name"
              class="h-full w-full object-cover"
            />
            <div v-else class="text-zinc-400">No Image</div>
          </div>
          <div class="flex flex-1 flex-col p-5">
            <h3 class="text-lg font-medium text-zinc-900">
              {{ product.name }}
            </h3>
            <p class="mt-1 text-sm text-zinc-500">{{ product.description }}</p>
            <div class="mt-4 flex items-center justify-between text-sm">
              <span class="text-zinc-600"
                >Stock: {{ product.stock }} available</span
              >
              <span class="font-semibold text-zinc-900">{{
                formatPrice(product.price)
              }}</span>
            </div>

            <div class="mt-auto pt-5">
              <Button
                size="sm"
                class="w-full min-w-[112px]"
                @click="buyProduct(product.id)"
                :disabled="
                  ordering_product_id === product.id ||
                  product.stock <= 0 ||
                  !current_customer_name
                "
              >
                <span v-if="product.stock <= 0">Out of Stock</span>
                <span v-else-if="ordering_product_id === product.id"
                  >Ordering...</span
                >
                <span v-else>Buy Now</span>
              </Button>
            </div>
          </div>
        </div>
      </div>
    </section>

    <aside class="min-w-0">
      <div
        class="flex h-full min-h-[620px] flex-col rounded-xl border border-zinc-200 bg-white shadow-sm xl:sticky xl:top-24"
      >
        <div class="border-b border-zinc-200 px-5 py-4">
          <div class="flex items-start justify-between gap-3">
            <div>
              <p class="text-sm font-medium text-zinc-900">Support Chat</p>
              <p class="mt-1 text-sm text-zinc-500">{{ chat_status }}</p>
            </div>
            <span
              class="rounded-full border border-zinc-200 bg-zinc-50 px-2.5 py-1 text-[11px] font-medium uppercase tracking-wide text-zinc-500"
            >
              {{ is_chat_connected ? "live" : "standby" }}
            </span>
          </div>
        </div>

        <div
          ref="chat_messages_el"
          class="flex-1 overflow-y-auto bg-zinc-50/40 px-5 py-4"
        >
          <div
            v-if="chat_error"
            class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700"
          >
            {{ chat_error }}
          </div>
          <div
            v-else-if="!current_customer_name"
            class="rounded-lg border border-dashed border-zinc-200 bg-white px-4 py-5 text-sm text-zinc-500"
          >
            Add your customer name on the left to unlock a dedicated support
            conversation.
          </div>
          <div
            v-else-if="!is_chat_connected"
            class="rounded-lg border border-dashed border-zinc-200 bg-white px-4 py-5 text-sm text-zinc-500"
          >
            Connect your support chat to load past messages and start a live
            thread with the merchant console.
          </div>
          <div
            v-else-if="chat_messages.length === 0"
            class="rounded-lg border border-dashed border-zinc-200 bg-white px-4 py-5 text-sm text-zinc-500"
          >
            Send a message to start the conversation.
          </div>
          <div v-else class="space-y-3">
            <div
              v-for="msg in chat_messages"
              :key="msg.id"
              :class="[
                'flex',
                msg.sender === 'shopper' ? 'justify-end' : 'justify-start',
              ]"
            >
              <div
                :class="[
                  'max-w-[85%] rounded-2xl px-3 py-2 text-sm',
                  msg.sender === 'shopper'
                    ? 'bg-zinc-950 text-white'
                    : 'border border-zinc-200 bg-white text-zinc-900',
                ]"
              >
                {{ msg.text }}
              </div>
            </div>
          </div>
        </div>

        <div class="border-t border-zinc-200 bg-white px-5 py-4">
          <div v-if="!is_chat_connected" class="space-y-3">
            <Button
              class="w-full"
              @click="joinChat"
              :disabled="!current_customer_name || is_joining_chat"
            >
              {{ is_joining_chat ? "Connecting..." : "Connect Support Chat" }}
            </Button>
            <p class="text-xs text-zinc-500">
              We reuse one lightweight conversation per customer name for this
              showcase.
            </p>
          </div>
          <div v-else class="flex items-center gap-2">
            <input
              v-model="new_message_text"
              @keyup.enter="sendMessage"
              type="text"
              placeholder="Type a message..."
              class="h-10 flex-1 rounded-md border border-zinc-300 px-3 text-sm"
            />
            <Button
              size="sm"
              class="min-w-[88px]"
              @click="sendMessage"
              :disabled="!new_message_text.trim() || is_sending_message"
            >
              {{ is_sending_message ? "Sending..." : "Send" }}
            </Button>
          </div>
        </div>
      </div>
    </aside>

    <div
      v-if="is_orders_open"
      class="fixed inset-0 z-50 flex items-center justify-center bg-zinc-950/45 p-4"
      @click.self="closeRecentOrders"
    >
      <div
        class="w-full max-w-4xl rounded-2xl border border-zinc-200 bg-white shadow-2xl"
      >
        <div
          class="flex items-start justify-between gap-4 border-b border-zinc-200 px-6 py-5"
        >
          <div>
            <p class="text-sm font-medium text-zinc-500">Recent Orders</p>
            <h2 class="text-xl font-semibold text-zinc-950">
              {{ current_customer_name || "Customer" }}
            </h2>
            <p class="mt-1 text-sm text-zinc-500">
              {{ recent_order_count }} orders, {{ recent_order_items }} items
              currently tracked in this showcase.
            </p>
          </div>
          <Button
            size="sm"
            variant="secondary"
            class="min-w-[88px]"
            @click="closeRecentOrders"
          >
            Close
          </Button>
        </div>

        <div class="grid gap-4 p-6 lg:grid-cols-[280px_minmax(0,1fr)]">
          <div class="space-y-2">
            <button
              v-for="order in customer_orders"
              :key="order.id"
              type="button"
              class="w-full rounded-xl border px-4 py-3 text-left transition-colors"
              :class="
                selected_order?.id === order.id
                  ? 'border-zinc-900 bg-zinc-950 text-white'
                  : 'border-zinc-200 bg-white hover:bg-zinc-50'
              "
              @click="selectOrder(order.id)"
            >
              <div class="flex items-center justify-between gap-3">
                <span class="text-sm font-medium">{{
                  getProductName(order.product_id)
                }}</span>
                <span class="text-xs font-medium uppercase tracking-wide">
                  x{{ order.quantity }}
                </span>
              </div>
              <p
                class="mt-2 text-xs"
                :class="
                  selected_order?.id === order.id
                    ? 'text-zinc-300'
                    : 'text-zinc-500'
                "
              >
                {{ order.lifecycle_status }}
              </p>
            </button>
          </div>

          <div
            v-if="selected_order"
            class="rounded-xl border border-zinc-200 bg-zinc-50/60 p-5"
          >
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div>
                <p class="text-sm font-medium text-zinc-500">Order Detail</p>
                <h3 class="mt-1 text-2xl font-semibold text-zinc-950">
                  {{ getProductName(selected_order.product_id) }}
                </h3>
              </div>
              <div
                :class="[
                  'rounded-full border px-3 py-1 text-sm font-medium capitalize',
                  getStatusColor(selected_order.lifecycle_status),
                ]"
              >
                {{ selected_order.lifecycle_status }}
              </div>
            </div>

            <dl class="mt-6 grid gap-4 sm:grid-cols-2">
              <div class="rounded-lg border border-zinc-200 bg-white p-4">
                <dt
                  class="text-xs font-medium uppercase tracking-wide text-zinc-500"
                >
                  Customer
                </dt>
                <dd class="mt-2 text-sm font-medium text-zinc-950">
                  {{ selected_order.customer_name }}
                </dd>
              </div>
              <div class="rounded-lg border border-zinc-200 bg-white p-4">
                <dt
                  class="text-xs font-medium uppercase tracking-wide text-zinc-500"
                >
                  Quantity
                </dt>
                <dd class="mt-2 text-sm font-medium text-zinc-950">
                  {{ selected_order.quantity }} item(s)
                </dd>
              </div>
              <div
                class="rounded-lg border border-zinc-200 bg-white p-4 sm:col-span-2"
              >
                <dt
                  class="text-xs font-medium uppercase tracking-wide text-zinc-500"
                >
                  What happens next
                </dt>
                <dd class="mt-2 text-sm text-zinc-600">
                  <span v-if="selected_order.lifecycle_status === 'new'"
                    >The merchant will see this order in the Merchant Console
                    and can begin processing it.</span
                  >
                  <span
                    v-else-if="selected_order.lifecycle_status === 'processing'"
                    >The merchant is actively processing this order. Keep the
                    support chat nearby if you need help.</span
                  >
                  <span v-else
                    >This order has been fulfilled and should now be
                    complete.</span
                  >
                </dd>
              </div>
            </dl>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
