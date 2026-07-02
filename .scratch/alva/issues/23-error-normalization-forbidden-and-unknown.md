# 23 - Error Normalization: Forbidden, Conflict, and Unknown Fallback

Status: ready-for-agent

## Parent
`docs/prd.md` (Phase 5 / Error Normalization)

## What to build
Perbarui `Alva.Error` untuk menangani bentuk error baru dan memastikan keamanan data internal:
1. Tangani `Ash.Error.Forbidden` (atau error otorisasi dari policy) dan kembalikan struktur: `%{type: "forbidden", message: "Forbidden"}` (atau sesuai error).
2. Tangani `Ash.Error.Invalid` khusus yang merupakan error domain/conflict kustom (jika dimungkinkan, kita akan pastikan bentuk dasarnya). Untuk MVP, jika ada `code` atau domain conflict, mapping ke `type: "conflict"`. 
3. Fallback error ("unknown") tidak boleh mengekspos isi pesan exception (`Exception.message(error)`) karena bisa membocorkan stacktrace atau SQL error. Ganti pesannya menjadi "Internal server error". Gunakan `Logger.error/2` untuk mencetak pesan error asli ke konsol server demi kepentingan debugging.
4. Pastikan `Alva.ErrorTest` atau tes terkait mencakup skenario di atas.

## Acceptance criteria
- [ ] `Alva.Error.format/1` menangani error `Ash.Error.Forbidden`.
- [ ] Fallback error "unknown" hanya mengembalikan "Internal server error", bukan pesan dari exception aslinya.
- [ ] Fallback error mencatat error ke konsol menggunakan `require Logger` dan `Logger.error`.
- [ ] Terdapat tes untuk Forbidden dan Unknown error di `alva/test/alva/error_test.exs`.

## Blocked by
None
