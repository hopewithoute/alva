# Frontend-Backend Contract Design

Keputusan arsitektural terkait bagaimana frontend (Vue) dan backend (Ash/Elixir) berinteraksi melalui AshLiveVue Bridge, berdasarkan perbandingan dengan kapabilitas dari `ash_typescript`.

## Keputusan

1. **End-to-End `snake_case`**
   Kita mempertahankan penggunaan `snake_case` dari ujung ke ujung (Elixir -> TypeScript/Vue) tanpa melakukan translasi *on the fly* ke `camelCase`. Ini mengorbankan aspek idiomatik JavaScript demi menghindari *transformation overhead*, mempertahankan pemetaan 1:1, dan memberikan sinyal visual yang jelas kepada developer UI bahwa suatu variabel adalah *domain state* dari server.
2. **Static Field Selection**
   Tidak seperti GraphQL atau `ash_typescript` yang mengizinkan pemanggilan dinamis (`fields: ["id", "title"]`), kita menggunakan **Static Auto-DTO**. Bentuk contract dikunci secara statis pada saat kompilasi. Jika field harus disembunyikan, server akan me-redact-nya lewat Ash Field Policies. Hal ini meminimalisir logika kompleks di frontend.
3. **Validasi Klien tanpa Zod**
   Untuk validasi form secara *client-side*, kita menghindari penggunaan *library* berat seperti Zod. Server akan men-generate validasi ringan (seperti *native rules object* atau JSON Schema) yang terintegrasi secara bawaan dengan `ashForm`. Hal ini menjamin ukuran *bundle* tetap kecil namun responsivitas UX tetap terjaga untuk validasi sederhana (e.g., *required*, *max_length*).
4. **Metadata pada Success Path**
   Objek balikan diubah bentuknya untuk mendukung metadata tambahan pada skenario sukses: `{ ok: true, data: T, meta?: Record<string, unknown> }`. Ini menyamakan derajat metadata pada saat *error* (`LiveError`), dan memungkinkan *actions* untuk menyisipkan informasi ekstra (seperti pesan peringatan yang tidak menyebabkan *abort* atau info *pagination*) tanpa mengotori bentuk `data` utama.
5. **Global Hooks / Interceptors di Vue**
   `useAshLiveVueApi` dikonfigurasi untuk menerima fungsi *hook* di root (`onError`, `onSuccess`). Ini mencegah kode *boilerplate* (seperti `if (!result.ok) toast.error()`) berulang di setiap komponen. Integrasi `ashForm` juga akan merespek konfigurasi notifikasi *toast* secara pintar (baik untuk di-disable atau di-kustomisasi pesannya).
