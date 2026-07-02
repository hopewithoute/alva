# 03 - Spike: Write Happy Path (students.create)

Status: done

## Parent
`docs/prd.md`

## What to build
Menangani input pengguna dan mutasi data baru (happy path).
Tambahkan action `:create` pada `AlvaDemo.Academics.Student`.
Perbarui `Alva.dispatch/3` untuk merespons event `"students.create"`, melakukan parsing *params*, memanggil mutasi `create`, dan mengembalikan DTO data baru.
Update `StudentsIndex.vue` dengan form sederhana untuk membuat student baru.

## Acceptance criteria
- [ ] Action `:create` tersedia di resource `Student`
- [ ] `Alva.dispatch/3` mendukung `"students.create"` dan mengembalikan `{ok: true, data: {...}}`
- [ ] `StudentsIndex.vue` memiliki form input (e.g. `name`) dan saat disubmit data berhasil masuk ke DB dan muncul di UI.

## Blocked by
- `.scratch/alva/issues/02-read-path-spike.md`
