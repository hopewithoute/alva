# 10 - DSL Verifier for Action Existence & Public Status

Status: ready-for-agent

## Parent
`docs/prd.md` (Phase 2 & Key Invariant 8.1)

## What to build
Membuat `Alva.Resource.Verifiers.VerifyActions` (sebuah _Spark Verifier_) yang akan dieksekusi pada saat _compile-time_. Verifier ini bertugas mengecek setiap definisi `event` di dalam `live_vue do ... end`. Verifier akan menggagalkan kompilasi menggunakan `Spark.Error.DslError` jika:
1. Action yang ditunjuk oleh `event` tidak ada di dalam resource tersebut.
2. Action yang ditunjuk ada, namun tidak diatur sebagai `public?: true`.
Tambahkan verifier ini ke modul `Alva.Resource`.

## Acceptance criteria
- [ ] Tersedia `Alva.Resource.Verifiers.VerifyActions` yang mengimplementasi `Spark.Dsl.Verifier`.
- [ ] Verifier ditambahkan ke konfigurasi extension `Alva.Resource`.
- [ ] Proses kompilasi akan error jika action tidak ada.
- [ ] Proses kompilasi akan error jika action berstatus *private* (`public?: false`).

## Blocked by
None - can start immediately
