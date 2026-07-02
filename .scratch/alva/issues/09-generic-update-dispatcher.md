# 09 - Slice 4: Generic Dispatcher for Update & ID Lookup

Status: ready-for-agent

## Parent
`docs/prd.md` (Phase 1 & Phase 3)

## What to build
Perbarui DSL di `Alva.Resource` agar entitas *event* dapat menerima konfigurasi opsional `lookup: :id` (atau semacamnya).
Perluas `Alva.Dispatcher` agar saat menangani aksi bertipe `:update`, dispatcher akan:
1. Membaca `id` dari *params*.
2. Memanggil data (*get by id*) menggunakan Ash.
3. Merespons error *Not Found* jika data tidak ada.
4. Mengeksekusi aksi `:update` pada *record* yang ditemukan.
Gantikan *hardcoded routing* `"students.archive"` di demo dengan dispatcher ini.

## Acceptance criteria
- [ ] DSL mendukung penentuan cara pencarian *record* (misal argumen *lookup*).
- [ ] Dispatcher mampu melakukan alur pengambilan data -> mutasi data untuk *event* bertipe update.
- [ ] Validasi *Not Found* dikonversi secara standar oleh library.
- [ ] UI Archive di demo berfungsi utuh menggunakan integrasi library.

## Blocked by
- `.scratch/alva/issues/08-generic-create-dispatcher.md`
