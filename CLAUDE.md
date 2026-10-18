# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Stack — HARD CONSTRAINTS (set by the owner; do not "improve" on them)

**Allowed:** HTMX, Alpine.js, UnoCSS, SurrealQL, SurrealDB, SurrealKV. Nothing else in the project.

**Forbidden:** `package.json` (or any lockfile / `node_modules`), Bun, Node.js, npm/npx, TypeScript, React, Tailwind, and standalone JavaScript files with application logic. Behavior in the browser is Alpine (`x-data` inline in the markup) + htmx attributes only; the server side is SurrealQL running inside SurrealDB.

**Target architecture (decided, see "Migration status"):** `surreal start` is the only server process. Pages and htmx fragments are `DEFINE API` endpoints (GA since SurrealDB 3.0) that return HTML built by `fn::ui::*` SurrealQL functions; scrapers are SurrealQL using `http::get` (`--allow-net` limited to the SENAI hosts); storage is SurrealKV. Browser libraries load from CDNs via `<script>` tags in the SurrealQL-rendered layout.

**Migration status — read before touching code:** the checked-in server under `src/server/`, `src/db/*.js`, `src/adapters/*.js`, `public/js/app.js`, the `Makefile` and the Biome setup are the OLD Bun/JS implementation and violate the constraints above. They stay only until the SurrealQL replacement reaches parity; do not extend them with new features — port instead.

## Commands

- `app/run.sh` — start SurrealDB (the `surreal` binary if on PATH, else the `senai-surreal` Docker container), load every `.surql` into database `cursos`, seed, and write the crawl secret (`app/.crawl-key`, git-ignored). `app/run.sh --load` reloads into a running server.
- `app/load.sh <db> [file ...]` — curl-only loader; prints every statement error and parse error.
- `app/crawl.sh [uf ...]` — drives the scrapers (see "Crawling"). A full cold cycle takes ~35-40 min (`CRAWL_BUDGET_S` raises the budget).
- Site: `http://127.0.0.1:8000/api/senai/cursos/home`. Ad-hoc queries: `curl -s -u root:root -X POST http://127.0.0.1:8000/sql -H 'Accept: application/json' -H 'surreal-ns: senai' -H 'surreal-db: cursos' --data-binary "<SurrealQL>"`.

## Testing

No automated suite. CI (`.github/workflows/ci.yml`) starts the SurrealDB image, runs `app/load.sh`, and curls health, home, assets and the guarded routes. Locally: load, crawl one or two states, open `/home` in a real browser at 360 and 1280 px and check the console. Reload `_common.surql` only while no crawl is running.

## Architecture

SurrealDB is the only server. Everything lives in `app/` and loads in this order: `schema.surql`, `lib/`, `scrapers/`, `ui/`, `api/`, `seed/`. Custom APIs are served at `/api/senai/<database>/<path>`; every emitted URL is prefixed with `fn::cfg::base()`.

- `schema.surql`, `lib/db.surql`: tables `state area unit course` and `fn::db::*`, the only write path for scrapers.
- `scrapers/`: `fn::scrape::<uf>::step($n) -> {next, done, note}` for the 19 active states, helpers in `_common.surql`. See `scrapers/STATUS.md` for per-state notes. Steps are small, idempotent and roll back on failure.
- `lib/dispatch.surql`: `fn::scrape::step($uf, $n)` dispatcher, `crawl_state` (strikes/back-off), `crawl_secret`.
- `api/`: `/health`, `/assets/*path` (file bucket on `app/assets`, needs `SURREAL_BUCKET_FOLDER_ALLOWLIST`), and the guarded routes `/crawl/:uf/:n`, `/crawl-skip/:uf/:n`, `/crawl-status`, `/crawl-report/:uf/:result`, `/retention/:days` (header `x-crawl-key`).
- `ui/`: `fn::ui::*` render functions and the page/htmx routes (`/home`, `/main`, `/privacidade`, `/ui.css`); see `ui/README.md` and `ui/DESIGN.md`. The UI only reads tables.
- `seed/states.surql`: the 27 states (19 active). `assets/`: flags and the single logo.

## Crawling

`crawl.sh` follows `next` until `done` (the last step prunes stale courses, so a cycle must finish). It runs at most 2 states at once, pauses with jitter, retries failed steps with back-off, calls `skip_task` after 3 failures of a queue-driven step (sc ce to mt sp), drops a state after 8 consecutive failed steps and skips it for 1/2/4/8 cycles, honours a time budget, and skips states finished within `CRAWL_MAX_AGE_S`. Respect upstream sites: never add parallelism inside a scraper.

## Adding a state

1. Write `fn::scrape::<uf>::step` in `app/scrapers/<uf>.surql` (persist only via `fn::db::*`; verify real products with open turmas first).
2. Add it to `fn::scrape::active()` and the dispatcher in `lib/dispatch.surql`, and set `status: 'active'` in `seed/states.surql`.
3. Expose the default área slug `tecnologia-da-informacao` when the source has a TI category.

## Gotchas (SurrealDB 3.3.4)

`DEFINE API` bodies must be string/bytes; no closures with `NOT`; use `!fn()` or parentheses; no try/catch (any error is HTTP 500); `string::slice(s, start, end)`; `load.sh` reports parse errors. Old JavaScript files may still exist in the working tree until removed; never extend them.
