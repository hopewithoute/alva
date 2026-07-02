# 01 - Scaffolding Phoenix + Ash + LiveVue Sandbox

Status: ready-for-agent

## Parent
`docs/prd.md`

## What to build
Inisialisasi project Elixir baru (mix project) sebagai sandbox/testbed untuk pengembangan library Alva. Aplikasi ini (`AppWeb` atau `AlvaDemo`) harus berisi:
- Phoenix LiveView
- Ash Framework
- LiveVue (termasuk Node.js dan Vue setup)

Tujuannya murni untuk scaffolding dari "state 0" dan memastikan integrasi dasar (Phoenix + LiveVue) bisa berjalan dan merender komponen Vue sederhana ("Hello World") di dalam halaman LiveView. Tidak perlu menambahkan resource domain apapun pada tahapan ini.

## Acceptance criteria
- [ ] Project Phoenix dapat dibuild dan dijalankan (`mix phx.server`).
- [ ] Ash Framework terpasang dengan benar (tidak error saat kompilasi).
- [ ] LiveVue terpasang dan dapat me-render Vue component.
- [ ] Terdapat satu halaman LiveView yang memuat komponen Vue "Hello World".

## Blocked by
None - can start immediately
