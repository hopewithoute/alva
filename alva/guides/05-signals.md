# Real-Time Signals (PubSub)

Alva supports strongly-typed, real-time subscriptions to Phoenix PubSub topics through the SDK. Any signal defined on the backend will be automatically exposed as an `on_[signal_name]` method on the respective domain.

## Subscribing to Signals

Signals are automatically subscribed and unsubscribed based on Vue's component lifecycle. When a component mounts, it tells the LiveView process to subscribe; when it unmounts, it unsubscribes.

### Example: Live Chat Messages

```vue
<script setup lang="ts">
import { ref } from "vue";
import { useAlva } from "@/alva";

const alva = useAlva();
const messages = ref<{ id: string, text: string }[]>([]);

// Subscribe to the 'message_created' signal on the 'demo_chat' domain.
// The first argument is the payload required to join the topic (e.g., a room ID or conversation ID).
alva.demo_chat.on_message_created(
  { conversation_id: "room_123" },
  (payload) => {
    // The payload type is strictly inferred from your Elixir struct definition!
    messages.value.push(payload);
  }
);
</script>

<template>
  <div class="chat-log">
    <div v-for="msg in messages" :key="msg.id" class="message">
      {{ msg.text }}
    </div>
  </div>
</template>
```

## How It Works

Behind the scenes, `on_signal` calls `live_vue`'s `useLiveEvent` and couples it with Phoenix LiveView lifecycle events (`alva:subscribe_signal` and `alva:unsubscribe_signal`). This ensures that your Elixir server only routes PubSub traffic to clients who actively have the relevant Vue component mounted on their screen.
