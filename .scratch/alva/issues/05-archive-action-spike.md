# 05 - Spike: Action Lookup & Not Found (students.archive)

Status: ready-for-agent

## Parent
`docs/prd.md`

## What to build
Mendukung action tipe mutasi (`update`/`destroy`) yang membutuhkan identifier (ID) dan menangani error `not_found`.
Tambahkan action `update :archive` di resource `Student`.
Perbarui `Alva.dispatch/3` untuk event `"students.archive"`. Dispatcher harus mengambil payload `id`, mencari resource, dan mengeksekusi action.
Jika ID tidak ditemukan, kembalikan `{ok: false, error: {type: "not_found", message: "..."}}`.
Tambahkan tombol "Archive" untuk tiap student di Vue UI.

## Acceptance criteria
- [ ] Action `:archive` tersedia di resource `Student`.
- [ ] `Alva.dispatch/3` mendukung `"students.archive"` dengan payload `id`.
- [ ] Response normal mengembalikan `{ok: true, data: {...}}`.
- [ ] Response gagal lookup mengembalikan error tipe `not_found`.
- [ ] Tombol Archive di UI Vue berfungsi dan menyembunyikan/mencoret student yang di-archive.

## Blocked by
- `.scratch/alva/issues/04-validation-error-spike.md`
