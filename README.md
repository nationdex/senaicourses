# SENAI Course Intelligence

Public SENAI course offerings and open seats for 19 Brazilian states, in one searchable page. Data comes from each state's own portal.

The whole product runs in SurrealDB. Scrapers are SurrealQL functions that call `http::get`. Storage is SurrealKV. Pages and HTMX fragments are `DEFINE API` routes that return HTML. The browser loads HTMX, Alpine.js and UnoCSS from CDNs. There is no JavaScript runtime, package manager or build step.

## Quick start

Needs Docker (or a local `surreal` binary), `curl` and `jq`.

```sh
app/run.sh                  # start SurrealDB, load schema, seed states
app/crawl.sh sp mg          # fetch courses for two states (no args: all 19; SP alone takes ~45 min cold)
```

Open `http://127.0.0.1:8000/api/senai/cursos/home`.

## Layout

```
app/
├── schema.surql    tables and indexes
├── lib/            config, fn::db::* write API, crawl dispatcher
├── scrapers/       one fn::scrape::<uf>::step per state (status in STATUS.md)
├── ui/             render functions and page routes
├── api/            /health, /assets/*, guarded /crawl* and /retention
├── seed/           the 27 states (19 active)
├── assets/         state flags and logo
├── run.sh          start, load, seed
├── load.sh         load SurrealQL files into a database
└── crawl.sh        drive the scraper steps
```

Tooling is POSIX `sh` with `curl` and `jq`.

## Routes

Base path `/api/senai/cursos`.

| Route | Purpose |
|---|---|
| `/home?uf=&area=&unit=` | main page |
| `/main` | htmx fragment |
| `/privacidade` | privacy page |
| `/ui.css` | base stylesheet |
| `/assets/*path` | flags and logo |
| `/health` | liveness check |

Operational routes need the header `x-crawl-key`. The key is written to `app/.crawl-key` on first boot and is git-ignored.

- `/crawl/:uf/:n`, `/crawl-status`, `/crawl-report/:uf/:result`, `/crawl-skip/:uf/:n`
- `/retention/:days`

## Configuration

`run.sh` reads `SURREAL_CONTAINER`, `SURREAL_DB`, `SURREAL_PORT`, `SURREAL_USER`, `SURREAL_PASS`, `SURREAL_DATA`, `SURREAL_IMAGE`, `SURREAL_ALLOW_NET`, `SURREAL_URL`.

`crawl.sh` reads `CRAWL_STATE_CONCURRENCY`, `CRAWL_DELAY_MS`, `CRAWL_RETRIES`, `CRAWL_FAILURE_LIMIT`, `CRAWL_STEP_TIMEOUT_S`, `CRAWL_BUDGET_S`, `CRAWL_MAX_AGE_S`, `CRAWL_RETENTION_DAYS`.

## Contributing

### Stack rules

Only HTMX, Alpine.js, UnoCSS, SurrealQL, SurrealDB and SurrealKV. No JavaScript runtime, package manager or build step, and no standalone JavaScript files. Tooling is POSIX `sh`, `curl`, `jq` and Docker. The full rules and the state-adding checklist are in [CLAUDE.md](CLAUDE.md).

### Where things go

- Scrapers: `app/scrapers/<uf>.surql`, persisting only through `fn::db::*`. Small idempotent steps; read `app/scrapers/STATUS.md`.
- UI: `app/ui/` (see `app/ui/README.md` and `app/ui/DESIGN.md`). The UI never calls `http::get`.
- Routes, assets, crawl plumbing: `app/api/`, `app/lib/dispatch.surql`.
- Shared contract and data model: [app/CONTRACT.md](app/CONTRACT.md).

### Iterating

Reload one file: `app/load.sh cursos app/ui/20_pages.surql` (parse and statement errors are printed). Do not reload `app/scrapers/_common.surql` during a crawl.

### Data collection

Be polite: sequential requests, an identifiable `User-Agent`, no hammering. Keep only offers the source lists as open with real availability. `vagas = null` means the source gives no seat count; never invent one.

### Verifying a change

1. `app/load.sh cursos` runs with no errors.
2. Crawl the touched state(s) and compare against the live source.
3. Open `/api/senai/cursos/home` in a real browser at 360 and 1280 px. The console must be clean.

CI (`.github/workflows/ci.yml`) runs the same load and smoke checks and must pass.

### Pull requests

Describe what changed and how you verified it. Keep the change focused. By contributing you agree your work is licensed under Apache-2.0.

## Disclaimer

This software independently aggregates publicly accessible data from each state's SENAI portal. It is not affiliated with, endorsed by, sponsored by, or associated with SENAI, SESI, FIESP or CNI.

Availability, schedules, vacancies and prices change without notice. Check the official portal before enrolling.

## License

Apache License 2.0. See [LICENSE](LICENSE).
