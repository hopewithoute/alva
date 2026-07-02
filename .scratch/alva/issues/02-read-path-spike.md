# 02 - Spike: Read Path (students.list)

Status: done

## Parent
`docs/prd.md`

## What to build
Hubungkan database (PostgreSQL), Ash Framework, LiveView, dan Vue tanpa form atau mutasi (hanya read path).
Buat `AlvaDemo.Academics.Student` dengan action `:read`.
Buat `AlvaDemoWeb.Alva.dispatch/3` yang me-routing event `"students.list"` untuk memanggil action `read` tersebut secara hardcoded.
Buat `StudentsIndex.vue` yang ketika di-mount akan mengirimkan pushEvent `"students.list"` dan me-render hasil data ke layar.

## Acceptance criteria
- [ ] Terdapat domain `Academics` dengan resource `Student` dan action `:read`
- [ ] Tersedia `AlvaDemoWeb.Alva.dispatch/3` yang bisa menerima `"students.list"` dan memanggil `Student.read!`
- [ ] Dispatcher merespons dengan JSON/Map format: `{ok: true, data: [...]}`
- [ ] `StudentsIndex.vue` berhasil menampilkan daftar murid (statis di database) tanpa ada error.

## Blocked by
None - can start immediately
