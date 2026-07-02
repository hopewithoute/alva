# 17 - Sort Support for List Events

Status: done

## Parent
`docs/prd.md` (Phase 3)

## What to build
List events harus mendukung param `sort` agar Vue component dapat mengubah urutan tampilan list.
Implementasikan dukungan untuk membaca opsi `sort` (misal `sort: "-created_at"`, `sort: "name"`) dari payload event, lalu men-translate param tersebut ke format `Ash.Query.sort` dan mengaplikasikannya ke query action read.
Pastikan juga keamanan: hindari melempar sembarang *untrusted string* tanpa divalidasi ke Ash. Atau lebih baik serahkan ke kapabilitas aman bawaan Ash.

## Acceptance criteria
- [ ] Dispatcher meneruskan argumen `sort` ke read action `Ash.Query`.
- [ ] Sort order diterapkan dan diverifikasi di test dispatcher.

## Blocked by
None
