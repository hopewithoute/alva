Status: done

## Parent
`.scratch/alva/PRD.md` (Phase 1-5 Architectural Completion)

## Problem Statement

Meskipun Phase 1 hingga Phase 6 (klien Vue) telah diselesaikan secara fungsional, terdapat 5 lubang arsitektur di sisi backend (Elixir) yang terlewat dari PRD utama. Kekurangan ini mencakup tidak adanya `Alva.LiveView` sebagai jembatan *lifecycle*, kebocoran data internal karena absennya *Auto-DTO stripping*, tidak adanya injeksi *Policy Hints* untuk referensi UI, pemrosesan file upload yang masih manual, dan pembuangan *custom metadata* secara sepihak. Jika dibiarkan, ini akan menyebabkan *security leaks* dan memblokir pembuatan TypeScript Codegen (Phase 7) yang membutuhkan kontrak *Auto-DTO* yang kuat.

## Solution

Melengkapi 5 elemen arsitektur inti backend Alva dalam satu inisiatif terintegrasi:
1. Menerapkan *Auto-DTO Extraction* di tingkat *compiler* untuk menyaring *payload* secara ketat.
2. Menyisipkan *Policy Hints* (`can_*` calculations) ke dalam objek `_permissions`.
3. Mengizinkan *Custom Metadata Opt-in* melalui pengaturan DSL.
4. Membuat makro `Alva.LiveView` yang membajak (hijack) `mount`, `handle_event`, dan `handle_info` untuk *Zero Boilerplate*.
5. Mengintegrasikan `consume_uploaded_entries` di dalam `Alva.Dispatcher` agar berjalan selaras dengan `ash_storage`.

## User Stories

1. As a backend developer, I want Alva to automatically extract `public?: true` fields during compilation, so that I don't accidentally leak private database fields to the Vue client.
2. As a backend developer, I want the Dispatcher to passively group all calculations starting with `can_` into a `meta._permissions` object, so that the Vue UI can hide or show buttons without causing N+1 policy evaluation queries on list endpoints.
3. As a backend developer, I want to explicitly expose custom metadata (like `sync_token`) via `expose_metadata: [...]` in the DSL, so that I can send extra operational data securely under the `meta` key.
4. As a backend developer, I want to type `use Alva.LiveView` in my LiveView module, so that I get automatic fallbacks for `mount`, `handle_event`, and `handle_info` without writing repetitive glue code.
5. As a backend developer, I want `Alva.LiveView` to automatically hook into `mount` and call `allow_upload` for any exposed events requiring files, so that file uploads work natively with zero configuration.
6. As a frontend developer, I want to receive specific PubSub events via `ash.on()`, which are safely intercepted by `Alva.LiveView`'s `handle_info` and forwarded via `push_event`, so that my Vue components can update reactively.
7. As a backend developer, I want `Alva.Dispatcher` to automatically call `consume_uploaded_entries` for file arguments before dispatching the Ash action, so that I don't have to manage file temp paths manually.

## Implementation Decisions

- **Auto-DTO Compilation**: An `on_compile` hook in `Alva.Resource` will extract a list of `public?: true` attributes, calculations, and relationships. `Alva.Dispatcher.strip_metadata/1` will use this list to drop unexposed fields and natively reject `%Ash.NotLoaded{}` and `%Ash.ForbiddenField{}` values.
- **Policy Hints Packaging**: `Alva.Dispatcher` will inspect the returned records. If it finds any keys matching `^can_.*`, it will group them into `meta: { _permissions: { ... } }`. Evaluation itself remains the responsibility of the Ash Action (via calculations).
- **Custom Metadata**: Execution metadata (`record.__metadata__`) will be stripped unless explicitly whitelisted via an `expose_metadata` configuration in the `event` DSL. Approved metadata will be merged into the JSON `meta` object.
- **`Alva.LiveView` Macro**: A new module that leverages `defmacro __using__`. It will inject `mount/3` (to configure `allow_upload`), `handle_event/3` (to route to `Alva.Dispatcher.dispatch/4`), and `handle_info/2` (to catch `%Ash.Notifier.Notification{}` and issue `push_event`).
- **Upload Consumption**: The signature of `Alva.Dispatcher.dispatch` will be updated to accept `socket`. It will inspect the LiveView `socket.assigns.uploads` and cross-reference it with the action's arguments to invoke `consume_uploaded_entries` immediately prior to `Ash.run_action`.

## Testing Decisions

*What makes a good test:* Tests should verify the external boundary (the data structure returned to the caller or the side effects pushed to the socket) rather than internal function calls.

We will test these features across **two primary seams**:
1. **Dispatcher Level (`Alva.DispatcherTest`)**: The highest point of testing for payload transformation. We will pass a dummy `socket` and parameters into `dispatch/4` and assert that:
   - Output `data` is stripped to only public fields (Auto-DTO).
   - Output `meta._permissions` correctly bundles `can_*` calculations.
   - Output `meta.custom_key` contains exposed metadata.
   - Mocked `consume_uploaded_entries` logic executes successfully when uploads are present.
2. **LiveView Level (`Alva.LiveViewTest`)**: We will create a dummy `DemoLive` module utilizing `use Alva.LiveView` and use `Phoenix.LiveViewTest` to assert:
   - The `mount` lifecycle correctly initializes `allow_upload`.
   - `render_event` routes to `Dispatcher`.
   - `send`ing an `%Ash.Notifier.Notification{}` pushes an event to the LiveView client.

## Out of Scope

- TypeScript Codegen (Phase 7). The strict data structures defined here prepare the ground for it, but generation logic is out of scope.
- Complex nested file uploads (if unsupported natively by standard Ash storage mechanisms).
- Global pubsub broadcasts (subscriptions must remain explicit in `mount` per our ADR).

## Further Notes
These 5 components conceptually belong to Phase 1-5 but were deferred. Resolving this issue fully cements the backend architecture before Codegen locks the client contracts.
