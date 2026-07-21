# Real-Time Signals (PubSub)

This guide covers real-time PubSub topic subscriptions and event broadcasts using Alva signals.

---

## 1. Overview & Conventions

Signals provide strongly-typed, real-time client subscriptions to backend Phoenix PubSub occurrences.

* **Authorization:** Every signal enforces authorization via `authorize_with: :read_action` using the current socket actor (`current_user`).
* **Block DSL Syntax:** Defined in Ash Resources using `signal :name do name("...") on(:action) authorize_with(:read) end`.
* **Subscription Lifecycle:** `alva.<domain>.on_<signal>({}, callback)` automatically subscribes on Vue component mount and unmounts cleanly.

---

## 2. Ash Backend Definition

Configure Ash PubSub notifications and map them to Alva signals in your resource:

```elixir
# lib/alva_demo/demos/notification.ex
defmodule AlvaDemo.Demos.Notification do
  use Ash.Resource,
    domain: AlvaDemo.Demos,
    data_layer: Ash.DataLayer.Ets,
    notifiers: [Ash.Notifier.PubSub],
    extensions: [Alva.Resource]

  pub_sub do
    module(AlvaDemoWeb.Endpoint)
    prefix("demo_notification")
    publish(:send, ["sent"])
  end

  alva do
    event(:demo_notifications_send, name: "demo_notifications.send", action: :send)

    signal :demo_notifications_sent do
      name("demo_notifications.sent")
      on(:send)
      authorize_with(:read)
    end
  end

  actions do
    defaults([:destroy])

    read :read do
      primary?(true)
      public?(true)
    end

    create :send do
      public?(true)
      primary?(true)
      accept([:title, :severity])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :title, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :severity, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:info, :success, :warning])
    end

    create_timestamp :created_at do
      public?(true)
    end
  end
end
```

---

## 3. LiveView Integration

Mount `Alva.LiveView` in your LiveView module. Signal subscription requests (`alva:subscribe_signal`) are handled automatically over WebSockets:

```elixir
# lib/alva_demo_web/live/demo_notifications_live.ex
defmodule AlvaDemoWeb.DemoNotificationsLive do
  use AlvaDemoWeb, :live_view
  use Alva.LiveView
end
```

---

## 4. Frontend TypeScript Library Usage

Subscribe to real-time signals inside your Vue component using `alva.<domain>.on_<signal>()`:

```vue
<script setup lang="ts">
import { useAlva } from "@/js/alva";

const alva = useAlva();

// 1-line reactive signal state array (auto-subscribes & unsubscribes on unmount)
const { data: notices, latest, count, clear } = alva.demo_notifications.use_sent_state();

// Publish a new notification via Alva action
const title = ref("Build finished cleanly.");
const severity = ref<NotificationSignal["severity"]>("success");
const sending = ref(false);

const sendNotification = async () => {
  if (!title.value.trim() || sending.value) return;

  sending.value = true;
  await alva.demo_notifications.send({
    title: title.value,
    severity: severity.value,
  });
  sending.value = false;
};
</script>

<template>
  <div class="notifications-page">
    <form @submit.prevent="sendNotification">
      <input v-model="title" placeholder="Title" />
      <button type="submit" :disabled="sending">Publish Signal</button>
    </form>

    <div class="signal-log">
      <h3>Received Signals ({{ notices.length }})</h3>
      <div v-for="notice in notices" :key="notice.id" class="notice-item">
        <span>[{{ notice.severity }}]</span> {{ notice.title }}
      </div>
    </div>
  </div>
</template>
```
