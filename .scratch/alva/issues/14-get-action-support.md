# 14 - Get Action Support via :read + lookup

Status: done

## Parent
`docs/prd.md` (Phase 3)

## What to build
Saat ini, `Alva.Dispatcher` pada `action.type == :read` langsung memanggil `Ash.read!` yang selalu mengembalikan list (array).
Sesuai PRD, jika konfigurasi event pada `live_vue` memiliki opsi `lookup` (misal `lookup: :id`), maka dispatcher harus berasumsi ini adalah operasi **Get** (mengambil 1 data). 
Dispatcher harus mencari data tersebut menggunakan `Ash.get` (atau `Ash.read` + filter) dan mengembalikan satu object `data: record` bukan array. Jika tidak ditemukan, kembalikan error `not_found`.

## Acceptance criteria
- [ ] Dispatcher `:read` memeriksa keberadaan `event_def.lookup`.
- [ ] Jika ada `lookup`, kembalikan single object (atau error not_found).
- [ ] Jika tidak ada `lookup`, kembalikan array seperti biasa.
- [ ] Test diupdate untuk mencakup skenario "Get" read action.

## Blocked by
None
