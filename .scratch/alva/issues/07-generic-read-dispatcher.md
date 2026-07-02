# 07 - Slice 2: Generic Dispatcher for Read (Migrate students.list)

Status: done

## Parent
`docs/prd.md` (Phase 1)

## What to build
Buat modul `Alva.Dispatcher` di dalam library `alva`. Dispatcher ini harus bisa menerima *event string*, mencari definisi event tersebut dari konfigurasi DSL (dari resource/domain yang terdaftar), lalu secara dinamis mengeksekusi aksi `:read` menggunakan API Ash.
Hapus *hardcoded routing* `"students.list"` yang saat ini ada di `AlvaDemoWeb.Alva`, lalu delegasikan pemanggilan ke `Alva.Dispatcher` library.

## Acceptance criteria
- [ ] Terdapat mekanisme (sementara/sederhana) untuk menemukan resource/action berdasarkan event string.
- [ ] `Alva.Dispatcher.dispatch/3` (di dalam library) berhasil mengeksekusi aksi `:read` dan mengembalikan format `{ok: true, data: [...]}`.
- [ ] Event `"students.list"` di aplikasi demo kini dilayani oleh dispatcher library tanpa mengubah fungsionalitas UI.

## Blocked by
- `.scratch/alva/issues/06-library-scaffolding-dsl.md`
