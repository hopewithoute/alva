# 18 - Actor and Tenant Injection

Status: done

## Parent
`docs/prd.md` (Phase 3 / Refinement)

## What to build
Sesuai PRD (8.3), Alva harus mendelegasikan otoritas *actor* (user) dan *tenant* pada state *process-based* via `Ash.set_actor` dan `Ash.set_tenant`. Saat ini, `Alva.Dispatcher.dispatch/3` memiliki signature yang tidak mengatur actor. 
Ubah arsitekturnya (atau pastikan ada hook di tingkat controller/channel/socket) agar ketika event LiveView di-handle, `current_user` dan `tenant` dari `socket.assigns` diset ke Process dictionary sebelum mengeksekusi `Ash.read`/`Ash.create`/dsb.

## Acceptance criteria
- [ ] Dispatcher mendukung argumen opsional `actor:` dan `tenant:` di opts.
- [ ] Aturan Otorisasi Ash dapat mengenali actor yang di-inject.
- [ ] Test untuk dispatcher yang membuktikan actor berhasil di-pass ke dalam call ke Ash.

## Blocked by
None
