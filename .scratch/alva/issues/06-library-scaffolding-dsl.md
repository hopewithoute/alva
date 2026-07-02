# 06 - Slice 1: Alva Library Scaffolding & Spark DSL Foundation

Status: done

## Parent
`docs/prd.md` (Phase 1 & Phase 2)

## What to build
Inisialisasi project Elixir baru `alva` sebagai library mandiri (berada di luar folder `alva_demo` atau bersebelahan dengannya) dan konfigurasikan `alva_demo` untuk menggunakan library ini via *path dependency*.
Buat ekstensi Spark DSL `Alva.Resource` yang mendefinisikan blok `live_vue do ... end` serta entitas `event` di dalam Ash Resource.
Terapkan ekstensi ini pada resource `Student` di aplikasi demo untuk memastikan DSL bisa dikompilasi (misal mendeklarasikan `event "students.list", action: :read`).

## Acceptance criteria
- [ ] Project library `alva` terbuat dan terhubung ke `alva_demo`.
- [ ] Ekstensi Spark `Alva.Resource` terdefinisi dan valid.
- [ ] Resource `Student` berhasil dikompilasi setelah ditambahkan blok `live_vue` beserta definisi *event*.

## Blocked by
None - can start immediately
