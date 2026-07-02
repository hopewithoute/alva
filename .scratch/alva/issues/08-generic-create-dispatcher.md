# 08 - Slice 3: Generic Dispatcher for Create & Error Normalization

Status: done

## Parent
`docs/prd.md` (Phase 1 & Phase 5)

## What to build
Perluas fungsionalitas `Alva.Dispatcher` pada library untuk mendukung aksi mutasi `:create`. 
Pindahkan logika `format_error/1` (yang bertugas menormalisasi `Ash.Error.Invalid` menjadi struktur error UI) dari `AlvaDemoWeb.Alva` ke dalam modul internal library (misal `Alva.Error`).
Gantikan *hardcoded routing* `"students.create"` di demo app agar ditangani oleh dispatcher library yang baru.

## Acceptance criteria
- [ ] Dispatcher library berhasil mengeksekusi aksi `:create` dengan menyuntikkan *params* yang dikirim dari Vue.
- [ ] Error normalisasi (`{type: "validation", fields: {...}}`) kini sepenuhnya ditangani secara internal oleh library.
- [ ] UI aplikasi demo tetap berfungsi normal saat *create* sukses maupun saat menemui error validasi.

## Blocked by
- `.scratch/alva/issues/07-generic-read-dispatcher.md`
