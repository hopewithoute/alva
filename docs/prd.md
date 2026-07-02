# PRD v0.1 — Alva (Ash Live Vue Adapter)

## 1. Ringkasan

**Alva** adalah layer integrasi antara **Ash Framework**, **Phoenix LiveView**, dan **LiveVue**.

Tujuannya adalah mengubah Ash resource/action menjadi **LiveView event contract** yang bisa dipanggil dari Vue component melalui LiveVue, tanpa membuat REST API, JSON API manual, Phoenix Channel custom, atau tRPC backend terpisah.

Formula utama:

```text
Ash Resource/Action
→ LiveView Event Dispatcher
→ LiveVue Client Helper
→ Vue Page Runtime
```

Prinsip utama:

```text
Vue owns the view.
LiveView owns the transport/session.
Ash owns the domain/action/policy.
```

Package ini tidak bertujuan menggantikan Ash, LiveView, atau LiveVue. Package ini hanya menghilangkan glue code repetitif antara ketiganya.

---

## 2. Problem Statement

Ketika menggunakan Ash + LiveView + LiveVue, developer biasanya menulis pola berulang:

```text
Vue pushEvent
→ LiveView handle_event
→ ambil current_user
→ ambil tenant
→ cast params
→ call Ash action
→ handle ok/error
→ map resource ke DTO
→ reply ke Vue
→ update assign/stream
→ tulis TypeScript type manual
```

Pola ini berulang di hampir semua resource:

```text
students.create
students.update
students.archive

teachers.create
teachers.update
teachers.archive

schedule.preview_conflict
schedule.move
schedule.commit

chat.send_message
chat.load_more
```

Akibatnya:

1. `handle_event/3` LiveView menjadi penuh boilerplate.
2. Format error antar-page tidak konsisten.
3. DTO mapping tersebar di banyak tempat.
4. Actor/tenant injection rawan lupa.
5. Vue memanggil string event manual tanpa type-safety.
6. Ash action sudah deklaratif, tapi tidak otomatis menjadi contract untuk LiveVue.
7. Developer tergoda membuat REST/tRPC layer baru padahal Ash + LiveView sudah cukup sebagai backend authority.

---

## 3. Product Goal

Membuat Alva yang memungkinkan developer menulis:

```elixir
live_vue do
  event "students.create",
    action: :create
    # DTO is handled automatically via on_compile public field gathering
    # Result is handled out-of-band via PubSub / LiveView Streams

  event "students.archive",
    action: :archive
end
```

Lalu di Vue:

```ts
const api = useAlvaApi()

await api.call("students.create", {
  name: "Alya",
  grade_id: "grade_1"
})
```

Dan di LiveView cukup:

```elixir
def handle_event(event, params, socket) do
  AppWeb.Alva.dispatch(event, params, socket)
end
```

---

## 4. Non-Goals

Alva **bukan**:

1. Bukan pengganti AshJsonApi.
2. Bukan pengganti AshTypescript.
3. Bukan pengganti Phoenix Channel.
4. Bukan tRPC clone penuh.
5. Bukan frontend state manager.
6. Bukan generator UI otomatis.
7. Bukan cara untuk expose semua Ash action secara otomatis.
8. Bukan cara untuk membuat Vue menjadi source of truth domain.
9. Bukan package headless component.
10. Bukan framework baru di atas LiveView.

---

## 5. Target User

### Primary User

Developer Elixir/Phoenix yang memakai:

```text
Ash Framework
Phoenix LiveView
LiveVue
Vue / TypeScript
shadcn-vue / Reka UI
```

dan ingin membangun aplikasi domain-heavy seperti:

```text
ERP
Sistem akademik
Scheduling
Admin dashboard
Internal tools
Multi-tenant SaaS
Realtime chat/notification
Workflow-heavy application
```

### Secondary User

Developer yang ingin memakai Vue sebagai view runtime, tapi tidak ingin membuat full SPA dengan REST/tRPC/API layer terpisah.

---

## 6. Core Concept

Alva memperlakukan event Vue sebagai **domain intent**, bukan sebagai low-level HTTP request.

Contoh intent:

```text
students.list
students.create
students.update
students.archive

schedule.move
schedule.preview_conflict
schedule.commit

chat.send_message
chat.load_more
```

Intent ini dipetakan ke Ash action:

```text
students.create
→ App.Academics.Student :create

students.archive
→ App.Academics.Student :archive

schedule.preview_conflict
→ App.Scheduling.Schedule :preview_conflict

chat.send_message
→ App.Chat.Message :send_message
```

---

## 7. Endgoal

Endgoal package ini adalah:

> Developer cukup mendefinisikan domain di Ash, expose action secara eksplisit ke LiveVue, lalu mendapat LiveView dispatcher, normalized reply, DTO projection, error shape, dan TypeScript event client.

End state yang diinginkan:

```text
Ash
= domain model, actions, policies, validations

LiveView
= authenticated event transport, socket state, streams, PubSub

LiveVue
= Vue reactive UI runtime inside LiveView

Alva
= contract, dispatcher, DTO, error, TS helper
```

Dengan hasil praktis:

```text
No REST controller.
No custom JSON API.
No Phoenix Channel auth duplication.
No tRPC backend.
No repeated handle_event boilerplate.
No raw Ash resource leaking to client.
No manual event string chaos in Vue.
```

---

## 8. Key Invariants

### 8.1 Explicit Exposure & Public Requirement

Ash action tidak boleh otomatis tersedia ke Vue.

Setiap event harus diekspos eksplisit melalui DSL, dan action yang dituju **wajib** berstatus `public? true` di level Ash resource. Jika action bersifat *private*, proses kompilasi akan digagalkan (Compile Error).

```elixir
live_vue do
  # Action :archive wajib public? true di blok actions
  event "students.archive", action: :archive
end
```

Layer `live_vue` ini tetap mutlak diperlukan (tidak bisa otomatis *expose* semua *public action*) karena layer ini bertugas untuk:
1. Memetakan nama action ke nama *event string* yang spesifik (`:archive` -> `"students.archive"`).
2. Mendefinisikan konfigurasi spesifik UI seperti *lookup field* (`lookup: :id`).
3. Menghindari *public action* yang diperuntukkan bagi *server-to-server* atau API terekspos ke Vue secara otomatis.

Invariant:

```text
No explicit expose = no client access.
Not public? true = Compile Error.
```

---

### 8.2 Server Authority

Vue tidak pernah menjadi authority domain.

Vue boleh meminta:

```text
students.archive
schedule.move
chat.send_message
```

Tapi keputusan final selalu di server:

```text
LiveView/Ash validates.
Ash policies authorize.
Ash actions mutate.
DB persists.
```

Invariant:

```text
Vue requests intent.
Ash decides truth.
```

---

### 8.3 Process-based Actor Injection

Payload dari Vue tidak boleh dipercaya untuk menentukan actor/tenant. Alva menggunakan Process-based Actor Injection bawaan Ash (`Ash.set_actor/1`), sehingga eksekusi action otomatis menggunakan konteks *current user* tanpa perlu melempar konfigurasi actor/tenant secara manual di setiap dispatch event.

Invariant:

```text
actor/tenant are injected via Process dictionary (Ash.set_actor), never trusted from client payload.
```

---

### 8.4 Auto-DTO and Policy Delegation

Ash resource mentah tidak boleh langsung dikirim ke Vue.
Semua result dilewatkan melalui **Auto-DTO** yang di-generate saat `on_compile` dengan mengumpulkan public fields.
Auto-DTO ini berfungsi ganda sebagai sumber TypeScript codegen, dan mendelegasikan redaction keamanan sepenuhnya ke **Ash Field Policies**.

Invariant:

```text
Auto-DTO acts as a dumb serializer. Ash Policies handle redaction (%Ash.NotLoaded{}).
```

---

### 8.5 Stable Result Shape

Semua event reply harus memakai bentuk konsisten:

```ts
type LiveResult<T> =
  | { ok: true; data: T; meta?: Record<string, unknown> }
  | { ok: false; error: LiveError }
```

Error shape:

```ts
type LiveError = {
  type:
    | "validation"
    | "forbidden"
    | "not_found"
    | "conflict"
    | "stale"
    | "unknown"

  message: string
  code?: string
  fields?: Record<string, string[]>
  meta?: unknown
}
```

Invariant:

```text
Every client-callable event returns a predictable shape.
```

---

### 8.6 Auto-DTO Policy Hints (Authorization Always Rechecked)

UI permission hanya untuk UX.
Server (Ash Policies) adalah penentu mutlak otorisasi. Untuk membantu Vue menyembunyikan elemen UI tanpa duplikasi aturan bisnis, **Auto-DTO akan meng-inject Policy Hints** (e.g. `_permissions: { can_archive: true }`) berdasarkan hasil evaluasi `Ash.can?`.

Invariant:

```text
Client permission is hint (generated via Auto-DTO). Server permission is law.
```

---

### 8.7 No Global SPA Creep

Alva tidak boleh mendorong Vue menjadi full app authority.

Yang boleh di Vue:

```text
local UI state
forms
dialogs
dropdowns
tables
drag preview
combobox query
temporary selection
chart interaction
```

Yang tidak boleh pindah ke Vue:

```text
authorization
tenant boundary
business invariant
persistence decision
audit trail
canonical domain state
```

Invariant:

```text
Vue owns interaction state, not domain truth.
```

---

### 8.8 Resource-Level DSL (No Central Registry)

Tidak ada registry terpusat. Event mapping dideklarasikan langsung di dalam Ash Resource menggunakan **Spark DSL**. Setiap event string harus unik.

Invariant:

```text
Event mapping is defined explicitly in the resource extension. No central registry.
```

---

### 8.9 Secure by Default

Default behavior:

```text
do not expose all actions
do not include private fields
do not trust client ids without tenant scope
do not bypass Ash policies
do not leak internal error details
do not return stacktrace to client
do not expose custom metadata by default (except standard pagination)
```

---

### 8.10 End-to-End Casing (snake_case)

Alva ini tidak akan mentransformasi `snake_case` (dari Elixir) menjadi `camelCase` di TypeScript/Vue. Pendekatan ini dipilih untuk menjaga pemetaan 1:1, menghindari *transformation overhead*, dan memberikan sinyal visual yang jelas kepada developer frontend bahwa data tersebut adalah *domain state* dari server, bukan *local state*.

Invariant:

```text
Domain data is strictly snake_case from DB to Vue. No on-the-fly casing transformation.
```

---

### 8.11 Static Field Selection & Loaded State (No GraphQL-style queries)

Vue tidak diizinkan mendikte secara dinamis *field* apa yang ingin di-*fetch* (tidak ada fitur `fields: ["id", "title"]`). Bentuk data (shape) dikunci secara statis pada saat kompilasi ke dalam Auto-DTO. Kontrol reduksi data mutlak berada di tangan server melalui Ash Field Policies.

Auto-DTO murni merefleksikan *loaded state* dari Ash Action. Jika server membutuhkan relasi, kalkulasi, atau agregat tertentu untuk dikirim ke Vue, hal tersebut harus diload di dalam server (misal melalui `prepare build(load: [:comment_count])`). Auto-DTO secara otomatis akan menyertakan data yang ter-load dan membuang relasi/kalkulasi yang berstatus `%Ash.NotLoaded{}`.

Invariant:

```text
Server dictates the DTO shape and loaded state. Client accepts the contract.
```

---

### 8.12 Strict by Default Filtering & Sorting

Vue secara *default* tidak diizinkan mengirim *Filter AST* dinamis (seperti `and`, `or`, `ilike`). Setiap event `:read` secara bawaan hanya merespons terhadap *Action Arguments* statis yang sudah didefinisikan (misal argumen `search` atau `status`). Jika developer membutuhkan filter dan sort dinamis dari Vue (misal untuk komponen *Datatable*), mereka harus secara eksplisit membuka izin tersebut di blok event DSL (`enable_filter: true`, `enable_sort: true`).

Invariant:

```text
Dynamic filter/sort from client is opt-in per event. Secure against query abuse by default.
```

---

### 8.13 Pagination Payload (Meta Extraction)

Ketika menggunakan event yang di-paginasi, properti `data` di dalam payload akan **selalu** dipertahankan sebagai *pure domain array* murni (`T[]`). Informasi mengenai halaman (seperti `count`, `has_more`, dan *cursors*) akan diekstrak dan diletakkan secara terisolasi ke dalam properti opsional `meta.pagination`. Hal ini memastikan komponen UI *list* tetap *reusable* terlepas dari status paginasi action tersebut.

Invariant:

```text
data is always the domain array. Pagination bounds live in meta.pagination.
```

---

### 8.14 Custom Action Metadata (Strict Opt-in)

Secara bawaan, segala bentuk *custom metadata* yang dihasilkan oleh aksi Ash akan dibuang sebelum dikirim ke Vue demi mencegah kebocoran data internal server. Jika developer benar-benar membutuhkan data ekstra dari eksekusi action (seperti `sync_token`), mereka harus mendaftarkannya secara eksplisit via `expose_metadata: [:sync_token]` di dalam deklarasi event DSL. Data tersebut kemudian akan digabungkan ke dalam objek `meta` di payload respons.

Invariant:

```text
Custom action metadata is dropped by default unless explicitly exposed via DSL.
```

---

### 8.15 Type-Safe PubSub (Realtime Events)

Pembaruan data *realtime* yang dikirim dari server (via Ash PubSub) ke client (via `ash.on`) harus *type-safe*. Alva akan menganalisis blok `pub_sub` pada resource Ash, mendeteksi event yang berstatus `public? true`, dan membaca nilai `returns` atau `transform: :calc` untuk men-generate tipe TypeScript secara otomatis. 

Invariant:

```text
Server pushed events via PubSub are strongly typed based on Ash publication definitions. ash.on() is never untyped.
```

---

## 9. Proposed API

### 9.1 Resource-Level DSL

```elixir
defmodule App.Academics.Student do
  use Ash.Resource,
    domain: App.Academics,
    extensions: [Alva.Resource]

  actions do
    defaults [:read, :create, :update]

    update :archive do
      change set_attribute(:status, :archived)
    end
  end

  live_vue do
    type "students"

    event "students.list",
      action: :read

    event "students.get",
      action: :read,
      lookup: :id

    event "students.create",
      action: :create

    event "students.update",
      action: :update,
      lookup: :id

    event "students.archive",
      action: :archive,
      lookup: :id
  end
end
```

---

### 9.3 Zero-Boilerplate LiveView Integration

```elixir
defmodule AppWeb.StudentsLive.Index do
  use AppWeb, :live_view
  use Alva.LiveView # Menambahkan fallback otomatis untuk mount, handle_event, dll.

  # Opsi 1: Developer bisa melakukan override `mount` untuk menyediakan initial data (SSR)
  # def mount(_params, _session, socket) do
  #   {:ok, assign(socket, :initial_data, ...)}
  # end

  def render(assigns) do
    ~H"""
    <.vue
      v-component="pages/StudentsIndex"
      initial_data={@initial_data}
      permissions={@ui_permissions}
    />
    """
  end
  
  # Opsi 2: Jika dibiarkan kosong, Vue akan melakukan client-side fetch via ashQuery (menampilkan loading skeleton awal).
end
```

---

### 9.4 Vue Client API & Composables

API di sisi Vue dirancang dengan sekumpulan komposable bawaan (*built-in*) yang sangat *advanced* dan terspesialisasi:

1. **`ashCall`**: Untuk memanggil event (mutasi) secara *type-safe*. Dirancang dengan dukungan (atau jalur menuju) **Optimistic UI**, memungkinkan perubahan state layar secara instan sebelum server membalas.
2. **`ashQuery`**: Untuk mengambil data (*data fetching*) berbasis *Query Builder* dan secara otomatis melakukan *auto-refresh* serta bertindak sebagai akumulator state via *streams*.
3. **`ash.on`**: Untuk men-*subscribe* event *PubSub* secara langsung dari Vue.
4. **`ashUpload`**: Untuk menangani seluruh mekanisme unggah file (*upload*) yang otomatis terhubung ke `ash_storage`.
5. **`ashForm`**: Untuk menangani *state form*, *auto-validation*, dan *error field mapping*. Termasuk dukungan cerdas untuk melakukan *cache* di memori (*in-memory caching*) pada validasi yang melakukan pengecekan ke *database*, serta integrasi *Optimistic UI*.
6. **Global Hooks / Interceptors**: `useAlvaApi` menerima konfigurasi hooks (`onError`, `onSuccess`) saat inisialisasi agar developer bisa mengatur penanganan global (seperti *toast notifications* atau *telemetry*) satu kali saja tanpa mengulang kode di setiap komponen.

---

### 9.5 File Upload Integration

Seluruh logika validasi (batas ukuran, tipe file, dll) didefinisikan secara natif di dalam konfigurasi Ash Resource/Action. Alva ini terintegrasi erat dengan `ash_storage`. Ketika action yang dikonfigurasi untuk menerima file dijalankan, Alva akan secara otomatis memproses unggahan tersebut (meniadakan kebutuhan menulis logika `consume_uploaded_entries` manual di LiveView).

---

## 10. Event Result Strategies

Result handling tidak lagi di-hardcode di DSL (`result: {:stream_insert}`). Sebaliknya, arsitektur menggunakan pendekatan *two-pronged*:

1. **Immediate Promise Reply**: Event di sisi Vue (melalui LiveVue Client Wrapper) selalu mengembalikan *LiveResult* promise seketika eksekusi selesai untuk menangani form loading state dan validasi.
2. **LiveView Streams & PubSub**: Pembaruan state aplikasi secara menyeluruh (seperti *list/table*) ditangani *out-of-band* melalui Ash PubSub dan LiveView streams.

---

## 11. Auto-DTO Contract

DTO tidak lagi ditulis manual secara berulang. Menggunakan **Auto-DTO** yang terintegrasi dengan Spark DSL:

1. **On-Compile Generation**: Field publik dikumpulkan saat proses kompilasi.
2. **TypeScript Sync**: Auto-DTO menjadi *source of truth* untuk pembentukan TypeScript.
3. **Policy Delegation**: Visibilitas data kondisional diurus sepenuhnya oleh Ash Field Policies. Jika Ash mengubah data menjadi `%Ash.NotLoaded{}` atau `%Ash.ForbiddenField{}`, Auto-DTO otomatis membuangnya dari payload JSON.
4. **Server-Side Validation Only (No Zod/Valibot)**: Sistem sama sekali tidak melakukan validasi kompleks di *client*. `ashForm` beroperasi layaknya *form* LiveView biasa (melakukan *debounce validation event* ke server). Server (Ash) adalah *Source of Truth* mutlak untuk validasi (termasuk cek unik ke DB). Client murni bertugas me-render *field errors* yang dikembalikan oleh Ash, dengan tambahan validasi minimal dari bawaan HTML5 (`required`, `type="email"`).

---

## 12. Error Normalization

Alva harus mengubah Ash errors menjadi error client yang stabil.

### 12.1 Validation Error

```json
{
  "ok": false,
  "error": {
    "type": "validation",
    "message": "Data tidak valid",
    "fields": {
      "name": ["can't be blank"],
      "grade_id": ["is required"]
    }
  }
}
```

### 12.2 Forbidden Error

```json
{
  "ok": false,
  "error": {
    "type": "forbidden",
    "message": "Tidak diizinkan"
  }
}
```

### 12.3 Not Found Error

```json
{
  "ok": false,
  "error": {
    "type": "not_found",
    "message": "Data tidak ditemukan"
  }
}
```

### 12.4 Domain Conflict

```json
{
  "ok": false,
  "error": {
    "type": "conflict",
    "code": "teacher_double_booked",
    "message": "Guru sudah mengajar di slot ini",
    "meta": {
      "teacher_id": "teacher_123",
      "slot_id": "slot_456"
    }
  }
}
```

---

## 13. TypeScript Generation

### 13.1 Type Mapping & Relation Resolution

Proses generasi TypeScript (Codegen) bekerja secara otomatis dengan mengandalkan Auto-DTO:
- **Type Mapping**: Secara otomatis memetakan tipe bawaan Ash ke tipe TypeScript (misal: `Ash.Type.String` -> `string`, `Ash.Type.Integer` -> `number`).
- **Relation Resolution**: Relasi (relationships) yang diekspos akan di-resolve tipenya secara rekursif saat fase kompilasi (`on_compile`), sehingga bentuk akhir nested object/array terjamin *type-safe* tanpa perlu penulisan manual.

---

### 13.2 Generated Event Maps (RPC & PubSub)

Target generated output:

```ts
export type AlvaEvents = {
  "students.create": {
    input: {
      name: string
      grade_id: string
    }
    output: LiveResult<Student>
  }

  "students.archive": {
    input: {
      id: string
    }
    output: LiveResult<Student>
  }

  "schedule.preview_conflict": {
    input: {
      teacher_id: string
      room_id: string
      slot_id: string
    }
    output: LiveResult<ConflictPreview>
  }
}

export type AlvaPubSubEvents = {
  "post_created": { id: string, title: string | null }
  "post_updated": string
}
```

---

### 13.3 Generic Client

```ts
const api = useAlvaApi<AlvaEvents>()

await api.call("students.create", {
  name: "Alya",
  grade_id: "grade_1"
})

// ash.on uses AlvaPubSubEvents
ash.on("post_created", (payload) => {
  // payload is fully typed
})
```

---

### 13.4 Optional Namespace Client

Generated ergonomic client:

```ts
await api.students.create({
  name: "Alya",
  grade_id: "grade_1"
})

await api.schedule.previewConflict({
  teacher_id,
  room_id,
  slot_id
})
```

---

## 14. LiveView Page Pattern (Router)

Sistem menggunakan **LiveView Router** standar sebagai tulang punggung navigasi (misal: `live "/students", StudentsLive.Index`). LiveView bertindak sebagai host (cangkang), sementara interaktivitas penuh ada di komponen Vue.

Recommended page pattern:

```text
One LiveView route
→ one Vue page component
→ all UI subtree inside Vue
→ all backend intent through LiveView event adapter
```

Example:

```elixir
~H"""
<.vue
  v-component="pages/ScheduleBoard"
  schedule={@schedule}
  teachers={@teachers}
  rooms={@rooms}
  permissions={@ui_permissions}
/>
"""
```

Vue handles:

```text
shadcn-vue UI
local state
dialogs
dropdowns
drag/drop
tables
forms
command palette
```

LiveView handles:

```text
mount (via default fallback)
handle_params
handle_event (via default fallback)
handle_info (via default fallback)
uploads (via default fallback)
streams
PubSub
auth
tenant
flash/navigation
```

Ash handles:

```text
actions
policies
validations
changes
preparations
calculations
aggregates
persistence
```

---

## 15. Reference Implementation Targets

This package should learn from the following implementation patterns:

### 15.1 Ash Extension Pattern

Use Spark DSL extension pattern:

```text
Spark.Dsl.Extension
Spark.Dsl.Section
Spark.Dsl.Entity
Spark.InfoGenerator
Spark.Dsl.Verifier
Spark.Dsl.Transformer
```

Primary use:

```text
define live_vue section
define event entity
generate info functions
verify exposed actions exist
```

---

### 15.2 AshJsonApi Pattern

Use as reference for:

```text
resource/action exposure
explicit route/action mapping
transport-specific behavior
filter/sort/pagination inspiration
safe public interface layer
```

But do not copy HTTP semantics directly.

Alva target is not HTTP route. Target is LiveView event.

---

### 15.3 AshTypescript Pattern

Use as reference for:

```text
TypeScript generation
input/output type generation
action contract generation
frontend helper generation
```

Prefer integration/reuse where possible instead of duplicating all type-generation logic.

---

### 15.4 LiveVue Pattern

Use as reference for:

```text
Vue component rendering inside LiveView
props from LiveView assigns
events from Vue to LiveView
useLiveVue
useEventReply
useLiveForm
useLiveUpload
streams support
```

---

### 15.5 LiveView Pattern

Use as reference for:

```text
stateful socket lifecycle
handle_event
handle_info
assign
stream_insert
stream_delete
push_event
redirect/patch
session/current_user handling
```

---

## 16. Implementation Architecture

```text
Alva
├── Resource Extension (Spark DSL)
│   ├── live_vue DSL section
│   ├── event DSL entity
│   └── Auto-DTO generation & Type mapping
│
├── Compiler & Lookup Table
│   ├── on_compile resource analysis
│   └── static O(1) event routing map generation (No runtime registry)
│
├── Dispatcher
│   ├── receive event from Zero-Boilerplate LiveView
│   ├── O(1) lookup to find Resource/Action
│   ├── inject actor/tenant via Ash.set_actor
│   ├── emit `:telemetry` events for granular structured logging
│   ├── run Ash action (with integrated ash_storage uploads)
│   └── normalize result/error
│
├── TypeScript Codegen
│   ├── event map generator
│   └── Supabase-style query factory builder
│
└── Vue Runtime Helper
    ├── useAlvaApi (RPC Mutations)
    ├── useAshQuery (Reactive Stream Composable)
    └── error & loading helpers
```

---

## 17. Roadmap Implementasi

## Phase 0 — Research & Spike

Goal:

```text
Prove Ash action can be called from LiveVue through LiveView event with normalized reply.
```

Deliverables:

1. Sample Phoenix app.
2. Ash resource: Student.
3. LiveVue page: StudentsIndex.vue.
4. Manual Alva function.
5. One event: `students.create`.
6. One event: `students.archive`.
7. One DTO.
8. One normalized error shape.

Acceptance Criteria:

```text
Vue can create/archive student via LiveView event.
Ash policy is enforced.
Actor comes from socket.
DTO is returned.
Validation error appears in Vue.
No REST endpoint exists.
```

---

## Phase 1 — Internal Dispatcher MVP

Goal:

```text
Remove repeated handle_event boilerplate.
```

Deliverables:

1. `Alva.Dispatcher`.
2. Explicit event registry.
3. Basic action executor for create/update/read/destroy.
4. Actor/tenant injection.
5. DTO mapping.
6. Reply shape:

```ts
{ ok: true, data }
{ ok: false, error }
```

Example:

```elixir
def handle_event(event, params, socket) do
  AppWeb.Alva.dispatch(event, params, socket)
end
```

Acceptance Criteria:

```text
At least 5 events across 2 resources run through dispatcher.
No event-specific handle_event needed for normal CRUD.
```

---

## Phase 2 — DSL Extension MVP

Goal:

```text
Move event exposure into Ash resource DSL.
```

Deliverables:

1. `Alva.Resource`.
2. `live_vue do ... end` DSL section.
3. `event` DSL entity.
4. `Alva.Resource.Info`.
5. Registry builder from domains/resources.
6. Duplicate event detection.

Example DSL:

```elixir
live_vue do
  type "students"

  event "students.create",
    action: :create,
    dto: AppWeb.DTO.Student,
    result: {:stream_insert, :students}
end
```

Acceptance Criteria:

```text
Events declared inside resource can be discovered by Alva.
Duplicate event name fails compile or boot verification.
Missing action fails verification.
```

---

## Phase 3 — Ash Action Coverage

Goal:

```text
Support all common Ash action types.
```

Deliverables:

1. Read action support (List, returns `LiveResult<T[]>`)
2. Get action support via `:read` + `lookup` (Returns `LiveResult<T>`)
3. Create action support.
4. Update action support.
5. Destroy action support.
6. Generic action support.
7. Lookup by `id`.
8. Lookup by custom field.
9. Query/filter params for list events.
10. Pagination support.
11. Sort support.

Acceptance Criteria:

```text
students.list
students.create
students.update
students.archive
schedule.preview_conflict
schedule.commit
all run through same adapter.
```

---

## Phase 4 — Result Strategies

Goal:

```text
Support LiveView-specific result updates.
```

Deliverables:

1. `{:reply, :data}`.
2. `{:assign, key}`.
3. `{:stream_insert, key}`.
4. `{:stream_delete, key}`.
5. `:no_reply`.
6. `{:custom, module}`.
7. Optional `push_event` support.
8. Optional `navigate/patch` result support.

Acceptance Criteria:

```text
Create action can stream_insert.
Archive action can stream_delete.
Preview action can reply only.
Commit action can assign page state.
```

---

## Phase 5 — Error Normalization

Goal:

```text
Give Vue one consistent error model.
```

Deliverables:

1. Validation error mapper.
2. Forbidden error mapper.
3. Not found mapper.
4. Conflict/domain error mapper.
5. Unknown error fallback.
6. Field errors for forms.
7. Safe logging of internal errors server-side.

Acceptance Criteria:

```text
Vue never receives raw Ash error structs.
Vue receives stable LiveError shape.
Internal error details are not leaked.
```

---

## Phase 6 — Vue Client API Suite

Goal:

```text
Make Vue calls ergonomic, consistent, and reactive with a full suite of composables.
```

Deliverables:

1. `ashCall` (RPC mutations).
2. `ashQuery` (Data fetching & reactive stream accumulation).
3. `ash.on` (PubSub subscription).
4. `ashUpload` (File upload mechanism).
5. `ashForm` (Form handling with auto-validation and in-memory caching for DB hits).

Acceptance Criteria:

```text
Vue pages build queries smoothly with auto-complete.
List data automatically syncs via stream events without manual array mutation.
Forms handle server validations efficiently without spamming the DB.
```

---

## Phase 7 — TypeScript Codegen

Goal:

```text
Generate typed event contract from exposed Ash actions.
```

Deliverables:

1. Mix task:

```bash
mix alva.codegen
```

2. Output path diisolasi secara default ke dalam folder khusus (contoh: `assets/js/alva/`) agar tidak bentrok.
3. Generated `types.ts` (Pure DTOs, Enums, and Shared Types).
4. Generated `events.ts` (Event Map Contract linking event strings to input/output types).
5. Generated `client.ts` (Initialization file to bind `events.ts` with the SDK).
6. Adapt/vendor `TypeMapper` & `Introspection` module logic dari `ash_typescript` (tanpa dependensi eksternal) untuk menangani *advanced types* (Embedded resources, Unions, Enums).
7. **PENTING**: Vendor logika *codegen Filter AST* dari `ash_typescript` khusus untuk event yang mengaktifkan `enable_filter: true`.
8. Optional namespace client:

```ts
api.students.create(...)
api.schedule.preview_conflict(...) // Strict snake_case
```

Acceptance Criteria:

```text
Wrong event name fails TypeScript.
Wrong input shape fails TypeScript.
Output data has typed DTO.
```

---

## Phase 8 — Forms Integration

Goal:

```text
Make create/update forms smooth with LiveVue.
```

Deliverables:

1. Convention for Ash validation errors to Vue form fields.
2. Integration examples with `useLiveForm`.
3. Nested object errors.
4. Dynamic array errors.
5. Server-side validation flow.
6. Submit action flow.

Acceptance Criteria:

```text
Vue form receives field-level errors from Ash action.
Dynamic nested forms can show server validation errors.
```

---

## Phase 9 — Streams & Realtime

Goal:

```text
Make chat/feed/list use cases first-class.
```

Deliverables:

1. Stream insert/delete strategy.
2. PubSub example.
3. Chat example.
4. Notification feed example.
5. Load-more event example.
6. Stream DTO projection.

Acceptance Criteria:

```text
chat.send_message persists via Ash and updates clients through stream/PubSub.
chat.load_more returns older messages through event reply.
```

---

## Phase 10 — Security Hardening

Goal:

```text
Make unsafe usage difficult.
```

Deliverables:

1. Compile-time verifier for exposed actions.
2. Warning if DTO omitted.
3. Warning if actor/tenant config omitted.
4. No auto-expose mode by default.
5. Server-side authorization test helpers.
6. Redaction for internal error details.
7. Audit hook support.

Acceptance Criteria:

```text
Package defaults are safe for multi-tenant applications.
```

---

## Phase 11 — Public Package Readiness

Goal:

```text
Prepare Hex package quality release.
```

Deliverables:

1. Documentation.
2. Guides.
3. Example app.
4. Test matrix.
5. CI.
6. Changelog.
7. Version compatibility notes.
8. Migration guide.
9. Comparison docs:

```text
Alva vs AshJsonApi
Alva vs AshTypescript
Alva vs full SPA
Alva vs pure LiveView
```

Acceptance Criteria:

```text
A new Phoenix/Ash/LiveVue app can install package and expose one action in under 15 minutes.
```

---

## 18. MVP Definition

MVP should include only:

```text
explicit event mapping
manual DTO
create/update/read/destroy/generic action execution
actor/tenant injection
normalized ok/error reply
basic Vue helper
basic docs
```

MVP should not include yet:

```text
full TS codegen
auto namespace client
complex pagination
advanced form integration
stream abstraction
public package polish
auto DTO inference
```

MVP example (Inside Ash Resource):

```elixir
live_vue do
  type "students"

  event "students.create",
    action: :create

  event "students.archive",
    action: :archive,
    lookup: :id
end
```

---

## 19. Success Metrics

### Developer Productivity

```text
50%+ reduction in LiveView handle_event glue code.
80%+ of CRUD-ish Vue events go through Alva.
New Ash action can be exposed to Vue in under 5 minutes.
```

### Safety

```text
0 raw Ash resources sent to Vue.
0 actor/tenant values trusted from Vue payload.
All exposed events checked by Ash policies.
All client errors normalized.
```

### DX

```text
Vue developer calls typed event helper.
Elixir developer exposes action declaratively.
Errors have predictable shape.
No REST/tRPC layer required.
```

---

## 20. Example End-to-End Flow

### Vue

```ts
const result = await api.call("schedule.preview_conflict", {
  teacher_id,
  room_id,
  slot_id,
  starts_at,
  ends_at
})
```

### Alva

```text
resolve "schedule.preview_conflict"
→ resource App.Scheduling.Schedule
→ action :preview_conflict
→ actor from socket.assigns.current_user
→ tenant from socket.assigns.current_tenant
→ run Ash generic action
→ map result to ConflictPreviewDTO
→ reply LiveResult<ConflictPreview>
```

### Server Reply

```json
{
  "ok": true,
  "data": {
    "has_conflict": true,
    "conflicts": [
      {
        "type": "teacher_double_booked",
        "teacher_id": "teacher_123",
        "message": "Guru sudah mengajar di slot ini"
      }
    ]
  }
}
```

---

## 21. Strategic Positioning

Alva sits between these options:

```text
Pure LiveView
→ simple, but weak for complex browser UI

Full Vue/tRPC
→ strong client DX, but introduces full SPA/API complexity

Ash + LiveVue manual
→ powerful, but too much repeated glue code

Alva
→ Vue UI leverage + LiveView transport + Ash authority
```

Positioning statement:

> Alva gives Phoenix/Ash developers a tRPC-like frontend calling experience without abandoning LiveView session transport or Ash domain authority.

---

## 22. Long-Term Vision

Long-term, this package can become:

```text
AshJsonApi for LiveVue event transport.
AshTypescript companion for LiveView-backed Vue apps.
The default adapter for Ash + LiveVue applications.
```

The final developer experience:

```elixir
actions do
  create :create
  update :archive
end

live_vue do
  event "students.create", action: :create
  event "students.archive", action: :archive
end
```

Then:

```bash
mix alva.codegen
```

Then in Vue:

```ts
await api.students.create(input)
await api.students.archive({ id })
```

No manual controller.

No custom API.

No duplicated auth transport.

No repeated LiveView event boilerplate.

---

## 23. Final Endgoal

The endgoal is not just less code.

The endgoal is a clean architectural contract:

```text
Ash models the system.
LiveView carries authenticated intent.
Vue renders the experience.
Alva connects them safely.
```

When this is achieved, a developer can build rich Vue/shadcn-vue interfaces on top of Ash/Phoenix without falling into full SPA complexity and without fighting LiveView’s lack of native client-side reactive primitives.
