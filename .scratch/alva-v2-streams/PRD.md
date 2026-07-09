# PRD: Alva V2 Streams & Signals (Declarative Real-Time Architecture)

## 1. Problem Statement
The V1 architecture suffered from "Domain Leak". The `subscription` DSL block was located inside Ash Resources, which forced the domain layer to intimately understand LiveView sockets, URL parameters, and UI state (Stream filtering). This violated the separation of concerns where the Resource should be UI-agnostic. Additionally, there was a mismatch between Vue's global nature (where components can render anywhere and fetch data freely) and LiveView's localized page-bound state.

## 2. Solution: The Two-Part Projection Architecture
To solve this, we are splitting the real-time projection into two distinct boundaries:

1. **Resource Projection (Passive Declaration)**: Ash Resources will strictly own `event` and `signal` definitions. These are passive declarations that serve as the contract for TypeScript Codegen and the Global Projection Registry. No streams, scopes, or socket handling occur here.
2. **Page Projection (Active Activation)**: The LiveView layer will intercept `streams:` and dynamically handle `signals:` using local socket context (`assigns`). It acts as the gatekeeper.

## 3. Two Real-Time Paradigms
We explicitly support two distinct real-time strategies depending on UI requirements:

- **Paradigm A: Stateful Server Streams (LiveView-driven)**
  - Used for long lists, SSR, and SEO-critical pages (e.g., Merchant Dashboard Orders).
  - Defined explicitly in the LiveView macro (`streams: [...]`).
  - The server holds the initial data (`source`), evaluates the filter (`scope`), diffs PubSub updates automatically, and pushes `stream_insert` or `stream_delete` to Vue.

- **Paradigm B: Dynamic Client Signals (Vue-driven)**
  - Used for localized, transient components (e.g., Modals, Comboboxes, Toast Notifications).
  - Vue explicitly fetches data (`api.call`) and requests real-time updates via `ash.on(signal, payload)`.
  - The server intercepts the signal request, evaluates permissions dynamically using `authorize_with`, and forwards valid PubSub messages to Vue. Vue handles array manipulation manually.

## 4. Execution Details & Edge Cases Resolved
1. **Reconnect & Missed Events**: For Signal (Paradigm B), the Alva SDK will provide a reactive connection hook (e.g. `useAlvaConnection()`). It is the Vue developer's responsibility to use this hook and manually re-fetch data if they need strict accuracy after a disconnect.
2. **Memory Leaks & Unsubscribe**: The `ash.on` method in the Alva Vue SDK will automatically hook into Vue's `onUnmounted` lifecycle. When a component dies, it sends an `alva:unsubscribe_signal` event so LiveView can drop the `Phoenix.PubSub.subscribe`, preventing server ghost subscriptions.
3. **Payload Mapping for Authorization**: We use **Convention over Configuration**. Because `signal` is defined globally in the Ash Resource (e.g., `authorize_with: :read_room`), the payload sent from Vue (e.g., `{ room_id: 123 }`) is passed exactly as arguments to the `read_room` action. No mapping DSL is needed in LiveView.

## 5. Security Model (Lean on Ash Policy)
- **Streams**: Topic binding relies on the initial Ash read action (`source`). If the current actor fails the policy check for the initial read, the stream fails to load and the subscription never happens.
- **Signals**: Dynamic topic binding relies on an explicit `authorize_with: :action_name` policy check in the Ash Resource. No `Phoenix.PubSub.subscribe` occurs without Ash's explicit consent.

## 6. Implementation Decisions
- **Module Modified: `Alva.Extension`**: Full removal of the legacy `subscription` DSL, enforcing a hard compiler rejection with no deprecation period.
- **Module Modified: `Alva.LiveView`**: Add `streams:` DSL parsing, `mount` data injection, `handle_info` PubSub diffing logic, and dynamic `ash.on` signal subscription interception.

## 7. Testing Seams
- **Seam 1 (Macro Validation)**: Compile-time macro validation ensuring compiler error if legacy `subscription` is used, and validating `streams:` format in LiveView.
- **Seam 2 (SSR Prop Injection)**: Test that initial data is properly injected into `socket.assigns.streams` on mount.
- **Seam 3 (PubSub Diffing)**: Test `handle_info` for Streams. Assert that `stream_insert` or `stream_delete` are fired correctly depending on whether the PubSub update matches the `source` query.
- **Seam 4 (Demo Migration)**: Full migration of `AlvaDemo.Catalog.Product`, `MerchantConsoleLive`, and `CustomerStorefrontLive` to prove the architecture.
- **Seam 5 (Security Boundary)**: Test that if the `source` action returns an `Ash.Error.Forbidden`, or if the `authorize_with` action fails the policy check, the macro aborts stream initialization or signal subscription immediately.

## 8. DX Shape (Developer Experience)
This architecture provides a zero-boilerplate, type-safe developer experience.

### Backend: Ash Resource (Global Definitions)
```elixir
defmodule AlvaDemo.Chat.Room do
  use Ash.Resource, ...

  live_vue do
    event :send_message, action: :create_message

    signal :chat_typing do
      name "chat.user_typing"
      on [:user_started_typing]
      authorize_with: :read_room # Payload exactly matches action arguments
    end
  end
end
```

### Backend: Phoenix LiveView (Active Gatekeeper)
```elixir
defmodule AlvaDemoWeb.RoomLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    streams: [
      messages: [
        resource: AlvaDemo.Chat.Message,
        source: :list_messages,
        scope: %{room_id: :room_id},
        sync_on: [:create_message]
      ]
    ]
    # No `signals:` block needed! Handled dynamically by macro.
end
```

### Frontend: Vue + TypeScript (Client Consumer)
```vue
<script setup lang="ts">
import { ref } from 'vue'
import { api, ash } from 'alva-client'

// Paradigm A (Streams): SSR'd and magically diffed by server
const props = defineProps<{
  messages: LiveResult<Message>[]
}>()

// Paradigm B (Signals): Dynamic client subscription
const typingUsers = ref<string[]>([])

// TS Autocomplete works! Payload matches Ash action arguments
ash.on("chat.user_typing", { room_id: 123 }, (payload) => {
  typingUsers.value.push(payload.name)
})
// SDK handles `ash.off` on component unmount automatically.
</script>
```
