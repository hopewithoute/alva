# 12 - Dispatcher O(1) Optimization

Status: ready-for-agent

## Parent
`docs/prd.md` (Phase 2)

## What to build
Refaktorisasi `Alva.Dispatcher.dispatch/3` agar tidak lagi melakukan iterasi (`Enum.find`) pada runtime untuk mencocokkan nama event. Dispatcher harus menggunakan `Alva.Domain.Info.alva_event_map(domain)` untuk mendapatkan _map statis_, lalu melakukan *lookup* *O(1)* pada map tersebut. Perbarui juga aplikasi demo (`AlvaDemo.Academics`) untuk memasukkan `extensions: [Alva.Domain]` dan verifikasi semua alur event CRUD berjalan sukses dengan pendekatan yang lebih teroptimasi ini.

## Acceptance criteria
- [ ] `Alva.Dispatcher.dispatch/3` menggunakan pencarian *O(1)*.
- [ ] Aplikasi demo `AlvaDemo.Academics` mengkonfigurasi `Alva.Domain`.
- [ ] Semua pengujian di `alva_demo` tetap hijau tanpa error.

## Blocked by
- `.scratch/alva/issues/11-domain-extension-and-registry.md`
