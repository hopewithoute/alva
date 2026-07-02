# 16 - Pagination Support for List Events

Status: done

## Parent
`docs/prd.md` (Phase 3)

## What to build
Sesuai PRD (8.13), list events (`:read`) harus mendukung paginasi. 
Jika action Ash mendukung paginasi dan menerima parameter paginasi (misal `{page: [limit: 10, offset: 0]}`), dispatcher harus mengatur pemanggilan Ash query dengan parameter tersebut.
Jika balikan dari Ash memiliki struktur *page* (misal `Ash.Page.Keyset` atau `Ash.Page.Offset`), hasil dari page tersebut (metadata seperti `has_more`, `count`, dll) harus diekstrak dan dimasukkan ke dalam atribut terpisah `meta.pagination` pada payload LiveResult, sedangkan atribut `data` tetap berupa pure array dari domain structs.

## Acceptance criteria
- [ ] Dispatcher memeriksa dan meneruskan opsi paginasi dari payload client ke Ash Query.
- [ ] Jika hasil adalah `Ash.Page`, pisahkan records ke dalam `.data` dan info paginasi ke `.meta.pagination`.
- [ ] Test mencakup skenario eksekusi event list dengan paginasi.

## Blocked by
None
