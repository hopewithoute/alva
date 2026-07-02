# 04 - Spike: Ash Error Normalization (Validation)

Status: done

## Parent
`docs/prd.md`

## What to build
Menangani sad path pada proses *create* dan menormalisasi error yang dilempar oleh Ash menjadi bentuk spesifik untuk dikonsumsi UI Vue.
Perbarui `Alva.dispatch/3` untuk menangkap `Ash.Error.Invalid` saat `"students.create"`.
Format error harus diubah ke bentuk: `{ok: false, error: {type: "validation", message: "...", fields: {name: ["can't be blank"]}}}`.
Di UI Vue, tampilkan error validasi tersebut di bawah field yang bersesuaian.

## Acceptance criteria
- [ ] Resource `Student` memiliki validasi (misal attribute name harus ada / tidak boleh kosong).
- [ ] Submit form kosong dari `StudentsIndex.vue` memicu error Ash di LiveView.
- [ ] `Alva.dispatch/3` merespons error dengan format *LiveError* sesuai PRD.
- [ ] Vue merender pesan "can't be blank" (atau serupa) tanpa crash.

## Blocked by
- `.scratch/alva/issues/03-write-path-spike.md`
