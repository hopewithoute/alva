# 13 - Destroy and Generic Action Support

Status: done

## Parent
`docs/prd.md` (Phase 3)

## What to build
Perbarui `Alva.Dispatcher.dispatch/3` untuk mendukung eksekusi action bertipe `:destroy` dan `:action` (generic).
- Untuk `:destroy`: Eksekusi `Ash.destroy(record)` seperti halnya `:update`, di mana record dicari terlebih dahulu menggunakan `lookup_field`. Respons kembalian harus berupa `{ok: true, data: record_yang_dihapus}`.
- Untuk `:action` (generic action): Gunakan `Ash.ActionInput.for_action` lalu panggil `Ash.run_action`. Kembalian berupa `{ok: true, data: result}`.

## Acceptance criteria
- [ ] Dispatcher mendukung `action.type == :destroy`
- [ ] Dispatcher mendukung `action.type == :action`
- [ ] Error handling tersambung dengan `Alva.Error.format`
- [ ] Terdapat test untuk verifikasi `:destroy` dan `:action` di dalam `alva/test/alva/dispatcher_test.exs`

## Blocked by
None
