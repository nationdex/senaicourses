# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Stack

HTMX + Alpine.js + UnoCSS in the browser, plain ES-module JavaScript on Bun, SurrealDB (SurrealKV engine) queried with SurrealQL. **No `package.json`, no `node_modules`, no bundler, no TypeScript** — do not add any. Browser libraries load from CDNs pinned in `src/views/layout.js` and `public/js/{uno,cursors}.js`.

## Commands

- `make dev` — server on http://localhost:3010 (`bun --watch`; creates `config/config.js` from `config/config.example.js` on first run). `make start` — production.
- `make lint` (what CI runs) / `make check` (autofix). Biome runs via `bunx @biomejs/biome@2.5.11`; the version is pinned in the Makefile, keep it matching `biome.json`'s `$schema`.
- SurrealDB needs the `surreal` binary on `$PATH` (https://surrealdb.com/install). The server spawns it itself; without it the site runs from memory only and logs `[db] sem persistência`.

## Testing

No automated test suite. Verify by hitting endpoints and loading the page:

- JSON: `GET /api/units?uf=sp&area=tecnologia-da-informacao`, `/api/courses/all?uf=sp&unit=403`.
- Fragments: `GET /ui/state?uf=mg`, `/ui/areas?uf=mg`, `/ui/units?uf=mg&area=…`, `/ui/content?uf=…&area=…&unit=…`. Each returns the target's HTML plus `hx-swap-oob` blocks.
- UI changes: load the page in a real browser, desktop + mobile width, check the console for errors, and walk the chain state → área → unit → refresh. A cold state can take a minute (catalog scrape).
- Server code changes need a restart if you ran `bun` without `--watch`. Edits to `public/` are served `no-cache` in dev, so a reload is enough.

## Architecture

One Bun process (`src/server/index.js`) serves pages, htmx fragments, the JSON API and static files from `public/`.

**UI flow.** Server holds all state; every selection is an `hx-get` returning HTML. First paint (`GET /`, `views/pages/home.js`) renders *placeholders* that load themselves in a chain: `/ui/areas` → `/ui/units` → `/ui/content` (each placeholder has `hx-trigger="load"`), so a cold scrape never blocks the shell. Responses update other regions with `hx-swap-oob`, announce selection with an `HX-Trigger: {"ctx": …}` header (client mirrors it into `html[data-uf|data-area|data-hue]`, and `app.js` drops stale chained responses by comparing against it), and push the shareable URL with `HX-Push-Url`.

**Views** (`src/views/`) are functions returning strings built with the escaping `html` tag (`views/html.js`). Use `raw()`/`jsonAttr()` only for trusted markup; everything else is escaped. Popover panels are Alpine `x-if` templates — they call `htmx.process($el)` on mount so `hx-*` inside them work.

**CSS.** UnoCSS *runtime* (`public/js/uno.js`, `presetWind4`, Tailwind-v4-compatible class names) generates utilities in the browser; theme colors/radii map to CSS variables in `public/css/aero.css`. That hand-written sheet is deliberately **unlayered and loaded after** the runtime's output, so its rules win ties — don't wrap it in `@layer`. `--brand-hue` is registered via `@property` so hue changes transition. The body is `un-cloak`ed until the runtime has styled it.

**Adapters** (`src/adapters/*.js`) — one per active state, implementing `StateAdapter` (typedef in `src/shared/types.js`). Two shapes: bespoke scrapers (SP, SC) and the shared VTEX backend `createFuturoDigitalAdapter(uf, "UF|")` (`futuro-digital.js`; account `tewbhv`, cluster 137; states differ only by the `"UF|"` prefix on `productReferenceCode`).

`src/adapters/registry.js`'s `ADAPTERS` is the source of truth for active-vs-coming-soon (checked against `KNOWN_ACTIVE` in `src/shared/state-meta.js` at dev startup). A state with metadata but no registry entry renders as "coming soon".

**Critical invariant:** wire a state into `ADAPTERS` only after confirming real products **and** at least one offer with `IsAvailable: true` at the live source — a loading page is not enough. Rejected on this basis: AC, AM, AP, BA, PB, RJ, RR, SE. Use `/verify-adapter <uf>`.

**Cache & persistence.** `KeyedAsyncCache` (`adapters/keyed-cache.js`): in-memory single-flight TTL per (state, área); never caches an empty result (treated as transient failure). `src/db/` persists last-known-good rows: `schema.surql` (tables, indexes, `fn::*` stored queries, applied with `OVERWRITE` on every boot), `surreal.js` (spawns `surreal start … surrealkv://…`, SurrealQL over `POST /rpc`, no SDK), `index.js` (reads/writes). `server/l1.js` adds a 5s response cache to GET handlers; `server/startup.js` does warm-up, proactive refresh and stale cleanup. Respect `catalogConcurrency`, `turmasConcurrency`, `warmupConcurrency` — don't hammer upstream sources.

**Cursors.** Real `.cur`/`.ani` files in `public/assets/cursors/`; `.ani` decoded in the browser by `ani-cursor` (`public/js/cursors.js`), recolored per state via `data-ani="busy-red"` attributes the server emits (`views/cursor.js`).

## Adding a state

1. Determine if it's the shared VTEX backend (a `"UF|"` prefix on `productReferenceCode` at the `tewbhv` account) or bespoke.
2. VTEX: add `src/adapters/<uf>.js` calling `createFuturoDigitalAdapter(uf, "UF|")`. Bespoke: full `StateAdapter` impl.
3. Verify real products + a real available turma **before** step 4.
4. Register in `ADAPTERS` (`registry.js`), add cosmetics to `state-meta.js`, add the uf to `KNOWN_ACTIVE`.

## Config

`config/config.js` (gitignored; copy of `config/config.example.js`) — every field also settable via env var: port/host, SurrealDB binary/storage/bind/credentials/autostart, cache TTLs, fetch timeout/retries, concurrency limits, default unit, refresh interval.
