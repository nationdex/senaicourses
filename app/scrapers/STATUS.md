# Scrapers status (workstream C)

All 19 active states are ported to SurrealQL: `fn::scrape::<uf>::step($n) -> { next, done, note }`,
persisting only through `fn::db::*`. Everything is loaded from `app/scrapers/*.surql`
(`_common.surql` first). Verified in database `cursos_scrape` against the legacy oracle on
`localhost:3010` (areas, units, and every course field: id, name, slug, hours, vagas, turmas,
start dates, schedules, prices, is_bolsa, url) with live data on 2026-10-18.

"Steps" = number of calls in one full cold cycle (`step(0)`..`done`).

| uf | ported | how verified | steps/cycle | known gaps / differences |
|----|--------|--------------|-------------|--------------------------|
| sp | yes | TI área: all 70 oracle units compared, every course identical except `hours` (oracle shows 0 for 2nd+ units of a card: legacy 3000-char window bug; SQL value is the real one) and live `vagas` drift (+1/+2 seats taken between runs). `alimentos-e-bebidas` unit 105 identical. Other 12 áreas only sampled (politeness). | ~600 (≈4-5 s each: 2 POSTs per course/unit pair; ~45 min) | Unit names are read from the unit's own list item (legacy named a card's 2nd+ units after its 1st). EAD pairs get unit `A Distância` (legacy hid them). `official_id` only for the ~6 units on /unidades. `url` unset (UI has the SP fallback). |
| sc | yes | all 15 áreas, all units identical (oracle duplicates of one product in one unit are merged: vagas summed, turmas counted, since course ids are unique per unit) | ~143 | `url` unset (UI fallback). Paid only (as legacy). |
| al | yes | 8 áreas, all units identical (ids ignored) | 9 | `hours` 0 (source has none). |
| rs | yes | 11 áreas identical except 1 extra open offer per unit vs oracle; checked against live REST: 83 open offers = 83 written (oracle cache is stale) | 13 | Last REST page: if total is an exact multiple of 50 the next page answers 400 and the step fails (not the case today: 548). |
| ma | yes | TI, 5 units identical | 10 | Only the TI área (feed has no category). Unit ids are name hashes (oracle uses counters). |
| mg | yes | 4 áreas, all units identical | 1 | |
| ms | yes (VTEX) | 1 área / 1 unit identical | ~24 cold (3 warm) | One área only today. |
| go | yes (VTEX, own clusters 550/551/553/554) | 10 áreas, 12 units identical (unit ids are hashes, mapped by city name) | 17 | |
| to | yes | 33 áreas identical (only 4 TI units, 20 free + 11 paid in total) | ~447 (2 course pages per step) | One course page (`cursoId=4261`) answers HTTP 500 permanently; the step that fetches it fails every time. Needs `fn::scrape::common::skip_task` (see "For the driver"). That skip dropped the other course in the same task for this cycle. |
| pi | yes (VTEX) | 4 áreas identical | 27 | |
| ro | yes (VTEX) | 6 áreas identical | 29 | |
| ce | yes | 21 áreas identical | 35 | |
| mt | yes | 8 áreas identical (ids ignored) | 22 | No `tecnologia-da-informacao` área: its IT área is `infraestrutura-de-informacao-e-comunicacao` (same as legacy). All courses stored as paid with empty prices (source says "Consulte Valores"). |
| df | yes | TI, 4 units identical (ids ignored) | 1 | `course_id` = site id*100 + turma row (oracle uses a counter). Only TI (keyword filter), free only. Source page has "Vagas: N" in a commented block; kept `vagas: null` as legacy. |
| pr | yes | TI, 9 units identical | 1 | `url` is null for most courses in the source. |
| es | yes (VTEX) | 9 áreas identical | 32 | |
| pa | yes (VTEX) | 8 áreas identical | 31 | |
| pe | yes (VTEX) | 6 áreas identical | 29 | No TI área in the live data right now (legacy oracle agrees). |
| rn | yes (VTEX) | 7 áreas identical | 30 | |

Critical invariant: VTEX states only keep items with `IsAvailable: true`; HTML/JSON states only
keep rows the source lists as open turmas. Every state above has at least one such row in
`cursos_scrape` (totals: sp 1515 free + 905 paid, sc 302, ce 225, mg 102, rs 83, go 52, pe 54, ...).
States exposing `tecnologia-da-informacao`: al ce df es go ma pa pi pr ro sc sp to
(not: mg, ms, mt, pe, rs; the UI must fall back to another área for those).

## For the driver (A)

- Call `fn::scrape::<uf>::step($n)` starting at 0, then follow `next` until `done`.
- Queue-driven scrapers (sc ce to mt sp; also al/rs/vtex use staging) keep progress in the database
  (`scrape_queue`, `scrape_stage`, `scrape_meta`, `vtex_offer`, `vtex_page`). A failed step is rolled back
  completely (SurrealDB transaction), so retrying the same `n` is safe.
- If step `n` of a queue-driven scraper (sc ce to mt sp) fails 3 times in a row, call
  `fn::scrape::common::skip_task('<uf>', n)` and continue with `n+1` (returns `{skipped: bool}`).
  Needed today for `to` n=328 of the earlier cycle (course 4261 -> HTTP 500). Not available for the
  single-request scrapers (mg df pr) or the VTEX/al/rs staging pages.
- Cycle start prune: the last step of every queue/single-step scraper deletes the uf's courses not
  refreshed during the cycle (`scraped_at` older than step 0), so a cycle must run to `done`.
- VTEX states share a staging cache (30 min): run them back to back; the first one fetches the ~22
  master-cluster pages, the next ones skip them. Run `sp`/`to` with delays: they are long (hundreds of steps).
- Do not reload `scrapers/_common.surql` while a step is running (its `DEFINE INDEX OVERWRITE` cancels
  the running transaction).

## SurrealDB 3.3.4 facts learned (not in CONTRACT.md)

- `string::slice(s, start, end)` (end exclusive), not (start, len); same for `array::slice`.
- No `WHILE`; `LET` inside `FOR`/`IF`/closure blocks does not change outer variables (use `array::map/filter/fold`);
  `a / b` on ints truncates.
- `NOT fn(...)` does not parse (use `!fn(...)`); `option<string>` params reject `NULL` (use `any`).
- A failing `http::get` (any non-2xx) aborts the step and rolls its writes back; redirects are followed.
- Inline regex flags work: `/(?i)…/`, `[\s\S]` for newlines. `<string><bytes>[..]` converts code points.
- `app/load.sh` reports `ok` for files with a parse error (HTTP 400 body is not scanned for `ERR`).
