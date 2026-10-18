# Rewrite contract (SurrealDB-hosted app)

Shared by the three workstreams: **A** core/infra/integration, **B** UI, **C** scrapers.
Read this whole file first. Do not change it; if something here is wrong or missing, say so in your final report.

## Hard constraints (owner's orders — violations are bugs)

- Allowed in the product: **HTMX, Alpine.js, UnoCSS, SurrealQL, SurrealDB, SurrealKV.** Nothing else.
- Forbidden anywhere: `package.json`/lockfiles/`node_modules`, **Bun, Node.js, npm/npx/pnpm, ts-node/tsc**, TypeScript, React, Tailwind, and standalone `.js` files with application logic. Browser behavior = Alpine `x-data`/directives written inline in the markup + htmx attributes. Server = SurrealQL inside SurrealDB.
- Allowed as *tooling*: `curl`, `jq`, `docker`, POSIX `sh`, `git`, and a real browser (Playwright MCP tools) for checking the UI. The Claude-in-Chrome extension is not connected.
- Do not run `git commit`/`git push`/`git add`. Do not touch files outside the directories you own. Do not start a Node/Bun process for any reason, including "just to test".

## Environment (verified)

- SurrealDB **3.3.4** runs in Docker as `senai-surreal`: `http://127.0.0.1:8000`, user `root` / pass `root`, namespace **`senai`**, SurrealKV storage in `~/.local/share/senai-surreal` (mounted at `/data`), flags `--allow-net --allow-experimental files`. **Only workstream A may recreate the container** (and must tell the others via its report). Others: do not stop/remove it.
- **Each workstream uses its own database** so you do not trample each other: A → `cursos`, B → `cursos_ui`, C → `cursos_scrape`. Custom APIs are served at `/api/senai/<database>/<path>`.
- Load files: `app/load.sh <database> [file ...]` (curl only; with no files it loads `schema.surql`, `lib/*`, `scrapers/*`, `ui/*`, `api/*`, `seed/*` in that order, prints every statement error). Ad-hoc queries: `curl -s -u root:root -X POST http://127.0.0.1:8000/sql -H 'Accept: application/json' -H 'surreal-ns: senai' -H 'surreal-db: <db>' --data-binary "<SurrealQL>" | jq`.
- Legacy implementation (Bun/JS) is the **behavior reference only**: `git show HEAD:src/adapters/sp.js`, `HEAD:src/server/routes/ui.js`, `HEAD:src/views/...`, `HEAD:public/css/aero.css`. Do not edit or run it. The legacy server is still running on `http://localhost:3010` — its JSON API (`/api/states`, `/api/areas?uf=`, `/api/units?uf=&area=`, `/api/courses/all?uf=&unit=&area=`) is the **oracle** to compare your output against.

## Verified SurrealDB 3.3.4 facts

- `DEFINE API OVERWRITE '/path/:id' FOR get THEN { RETURN { status: 200, headers: { 'content-type': 'text/html; charset=utf-8' }, body: '<html>…' }; };` serves HTML at `/api/senai/<db>/path/<id>`. Response headers are strings (e.g. `HX-Trigger`, `HX-Push-Url`, `Cache-Control` all pass through).
- `$request.params.id` (path param), `$request.query` is an object (`$request.query.uf ?? 'x'`), `$request.headers`, `$request.method`, `$request.body`.
- `'/*rest'` captures the remainder as an **array** of segments (use `array::join`).
- The route `'/'` is NOT reachable (404). Use a named route such as `/home`. Every URL you emit must be prefixed with `fn::cfg::base()` (returns `/api/<ns>/<db>`).
- An error anywhere inside a route (including a failed `http::get`) → HTTP 500 for the whole request. SurrealQL has **no try/catch**. A failing statement in a plain `/sql` multi-statement query does not stop the next statement.
- `http::get(url)` (and `http::get(url, {headers})`): JSON content-type → parsed value; anything else → string. Any non-2xx → error. No timeout/retry options. Works inside functions. Needs `--allow-net` (on).
- String functions confirmed: `string::split`, `string::slice(s, start, end)` (end index, exclusive), `string::replace(s, /regex/, repl)`, `string::matches(s, /regex/)`, `string::slug`, `string::trim`, `string::lowercase`, `string::words`, `string::starts_with`, `string::html::encode` (also encodes spaces as `&#32;` — fine, but prefer your own minimal escape for visible text), `array::len`, `time::now()`. **No regex capture groups** — parse with split/slice/replace.
- Functions: `DEFINE FUNCTION OVERWRITE fn::a::b($x: string) { … }`; `LET`, `FOR $x IN $arr { }`, `IF … { } ELSE { }`, `UPSERT type::record('tbl', $id) CONTENT {…}` all work in function bodies.
- Files/buckets need `DEFINE BUCKET … BACKEND 'file:/data/…'` and the server's folder allowlist (the first attempt, `file:/data/public`, failed with "File access denied") — workstream A figures this out and serves `/assets/*`.

## Data model (already written, tested): `app/schema.surql`

Tables `state{uf,name,source_label,status('active'|'coming-soon'),sort}`, `area{uf,slug,label}`, `unit{uf,unit_id,name,official_id?}`, `course{uf,area,unit_id,course_id,name,slug,hours,vagas(number|null),turmas,start_dates,schedules[{periodo,horario}],prices,is_paid,is_bolsa,url?,scraped_at}`. `vagas = null` means "source gives no seat count" — never invent one. The default área slug is `tecnologia-da-informacao` (every state with a TI category must expose it under that slug).

**Scrapers write, the UI reads. The UI never calls `http::get`.**

Write API (already written, tested): `app/lib/db.surql` — `fn::db::upsert_areas($uf, $rows)`, `fn::db::upsert_units($uf, $rows)`, `fn::db::upsert_courses($uf, $area, $unit_id, $is_paid, $rows)`, `fn::db::prune_unit(...)`, `fn::db::delete_stale($cutoff)`. Read their headers for row shapes. Scrapers may only persist through these.

## Scraper step contract (workstream C implements, A drives)

For each active state `<uf>` (`sp sc al rs ma mg ms go to pi ro ce mt df pr es pa pe rn`):

`DEFINE FUNCTION OVERWRITE fn::scrape::<uf>::step($n: int) -> object` returning `{ next: int | NONE, done: bool, note: string }`.

- `step(0)` = catalog step: discover areas, units and anything the catalog pages give for free; persist with `fn::db::*`.
- `step(n>0)` = one bounded unit of work (e.g. one unit × one área, free+paid); persist; return the next `n`.
- Each step must be **small** (a handful of `http::get`, well under ~30 s) because one failed request fails the whole step; the driver retries the same `n`. Steps are **idempotent** and may be re-run any time. `done: true` ends the cycle. Expected-empty results are not errors.
- Cross-step state lives in the database (e.g. a `crawl_state` row or the tables themselves), not in memory.
- Shared helpers go in `app/scrapers/_common.surql` (`fn::scrape::common::*`), loaded before the per-state files. Also reuse upstream politeness: sequential requests, identifiable `User-Agent` header like the legacy adapters.
- Dispatcher (A): `fn::scrape::step($uf, $n)` maps `uf` → `fn::scrape::<uf>::step($n)`. Route: `GET {base}/crawl/:uf/:n` (guarded by a secret header; see A). Driver: `app/crawl.sh` (curl loop with delays/back-off).

## UI contract (workstream B implements)

- B owns `app/ui/*.surql`: `fn::ui::*` render functions **and** the `DEFINE API` routes for the public pages and htmx fragments (`/home`, `/privacidade`, fragments…). B documents route names/params in `app/ui/README.md`.
- Reads only from the tables above. Links/assets: `fn::cfg::base() + '/assets/flags/<uf>.png'` (all 27 states) and `fn::cfg::base() + '/assets/senai.svg'` (the single logo) — served by A's `/assets/*path` route. Every other asset is a CDN `<script>/<link>` or inline CSS.
- Browser stack: htmx (CDN), Alpine.js (CDN, plugins from CDN allowed), UnoCSS runtime (CDN). **No `.js` files.** Inline `<script>` is allowed only as a CDN `<script src>` include, or the smallest possible UnoCSS config block if it is truly unavoidable (flag it in the report).

## Ownership

- **A:** `app/api/*` (non-UI routes: health, assets, crawl), `app/lib/dispatch.surql`, `app/seed/*`, `app/assets/*`, `app/run.sh`, `app/crawl.sh`, container lifecycle, CI, README/CONTRIBUTING/CLAUDE.md, integration into database `cursos`, and — **last, only after C and B are done and the end-to-end check passes** — deletion of the legacy Bun/JS/Biome/Makefile files.
- **B:** `app/ui/*` (and `app/ui/dev/*` for dev seeds, which `load.sh` does not auto-load).
- **C:** `app/scrapers/*`.
- Shared files (`schema.surql`, `lib/cfg.surql`, `lib/db.surql`, this file) are frozen. Need a change? Report it; A applies it.

## Done means

Verified by running it (curl/jq/browser), not by reading it. Final report: what exists (paths), what you ran and the result, what is unverified or broken, what you need from the others. Keep it short.
