# 15 - Query and Filter Params for List Events

Status: done

## Parent
`docs/prd.md` (Phase 3)

## What to build
Secara default, event `:read` yang berupa *list* saat ini tidak menerima parameter filter dari client. 
Implementasikan dukungan filter argument di `Alva.Dispatcher`. 
Catatan: Sesuai aturan PRD (8.12), client tidak boleh melempar AST sembarangan. Filter harus berupa argumen statis action, atau query terstruktur yang sah menurut `Ash.Query.filter`. Pastikan params dilempar ke action read dengan aman (e.g., via `Ash.Query.for_read` atau langsung memberikan args ke `Ash.read`).
Kita perlu menambahkan opsi `enable_filter: true` pada DSL `event` nantinya, tapi untuk issue ini, cukup pastikan parameter (action arguments) diteruskan ke fungsi read.

## Acceptance criteria
- [ ] Dispatcher meneruskan `params` (tanpa key meta) sebagai argumen/input ke `Ash.read` (via `Ash.Query.for_read`).
- [ ] Test tersedia untuk membuktikan arguments dapat dipassing ke list event.

## Blocked by
None
