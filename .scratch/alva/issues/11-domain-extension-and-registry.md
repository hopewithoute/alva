# 11 - Domain Extension & O(1) Static Registry

Status: ready-for-agent

## Parent
`docs/prd.md` (Phase 2)

## What to build
Membuat extension baru bernama `Alva.Domain` yang dapat digunakan pada `Ash.Domain`. Extension ini harus menyertakan _Spark Verifier_ atau _Transformer_ yang akan:
1. Mengiterasi semua `Ash.Domain.Info.resources/1` pada saat _compile-time_.
2. Mengumpulkan semua definisi `event` LiveVue menggunakan `Alva.Resource.Info.events/1`.
3. Memastikan tidak ada nama *event* yang duplikat antar resource dalam satu domain (jika ada, gagalkan kompilasi).
4. Men-*generate* helper `Alva.Domain.Info.alva_event_map/1` yang mereturn static map dengan struktur: `%{ "event_name" => {ResourceModule, EventStruct} }`.

## Acceptance criteria
- [ ] Tersedia `Alva.Domain` (dan verifier/transformer-nya) yang mengekstrak semua event di dalam domain.
- [ ] Kompilasi akan gagal jika dua resource mendaftarkan nama event string yang sama persis.
- [ ] Tersedia `Alva.Domain.Info.alva_event_map(domain)` yang membalikkan _map_ *O(1)* untuk _routing_ event.

## Blocked by
- `.scratch/alva/issues/10-dsl-verifier-for-action-existence.md`
