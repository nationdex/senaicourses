# Contributing to SENAI Course Intelligence

Welcome! This project aggregates, normalizes, and visualizes public course offerings across multiple Brazilian SENAI state federations. We welcome contributions from software engineers, data engineers, UX/UI designers, researchers, and enthusiasts.

---

## Before You Start

- Review existing [GitHub Issues](https://github.com/ariel-aram/senai-cursos/issues) and [Pull Requests](https://github.com/ariel-aram/senai-cursos/pulls) before starting substantial new work.
- Any change touching data ingestion must respect the upstream source it's fetching from (rate limits, caching, no bypassing access controls).
- Keep communication respectful and constructive.

---

## Development Environment Setup

### Prerequisites

- [Bun](https://bun.sh) (v1.1.0 or higher)
- The [`surreal` binary](https://surrealdb.com/install) (optional — without it the site runs from memory only)
- Git

### Local Setup

```bash
git clone https://github.com/ariel-aram/senai-cursos.git
cd senai-cursos
bun install
make dev   # also copies config/config.example.js to config/config.js on first run
```

The app is served at `http://localhost:3010`.

> **Storage note:** SurrealDB runs as a child `surreal` process on the SurrealKV engine (`surrealkv://./data/senai.kv` by default; install the binary from <https://surrealdb.com/install>). The server talks SurrealQL to it over HTTP. If the binary is missing or the connection fails, the server keeps working from in-memory cache alone; persistence is a durability layer, not a hard dependency.

---

## Project Structure

```text
senai-cursos/
├── config/
│   └── config.example.js        # Runtime configuration template — copied to config.js by `make setup`
├── data/                        # SurrealKV files (local, gitignored)
├── public/                      # Served as-is — no build step
│   ├── assets/                  # Flags, logos, and the Aero cursor pack (assets/cursors/)
│   ├── css/aero.css             # The hand-written Frutiger Aero design layer
│   └── js/
│       ├── uno.js               # UnoCSS runtime config (theme tokens)
│       ├── app.js               # Alpine components + htmx hooks
│       ├── cursors.js           # Aero cursor system (.cur/.ani rendering)
│       └── cursor-color.js      # hue -> cursor color mapping (shared with the server)
├── src/
│   ├── adapters/                # One StateAdapter implementation per active state
│   │   ├── registry.js          # uf -> adapter map — the real "active vs coming-soon" source of truth
│   │   ├── futuro-digital.js    # Shared VTEX-backend adapter factory (used by several states)
│   │   ├── keyed-cache.js       # In-memory single-flight TTL cache used by every adapter
│   │   ├── http.js              # Shared fetch/retry/concurrency helpers
│   │   └── <uf>.js              # sp.js, sc.js, ma.js, ... one file per state
│   ├── db/
│   │   ├── schema.surql         # SurrealQL: tables, indexes and stored queries (fn::*)
│   │   ├── surreal.js           # Starts the `surreal` process, SurrealQL-over-HTTP client
│   │   └── index.js             # Reads/writes used by the adapters
│   ├── server/
│   │   ├── index.js             # Bun.serve entry point
│   │   ├── routes/              # pages.js (full pages), ui.js (htmx fragments), api.js (JSON)
│   │   ├── startup.js           # Warm-up, proactive refresh, stale cleanup
│   │   ├── l1.js, selection.js, static.js
│   ├── shared/
│   │   ├── state-meta.js        # Static per-state cosmetic data (name, logo, flag, hue)
│   │   ├── constants.js         # Default área slug/label
│   │   └── types.js             # JSDoc typedefs: Course, UnitInfo, Area, StateAdapter
│   └── views/                   # Server-side HTML (html`` template tag)
│       ├── layout.js, html.js, icons.js, urls.js, cursor.js
│       ├── components/          # header, selectors, content, footer, atmosphere
│       └── pages/               # home.js, privacy.js
├── scripts/                     # One-off tooling (platform probe)
├── Makefile                     # dev / start / lint / check — there is no package.json
└── biome.json
```

---

## Areas for Contribution

1. **New State Adapters:** The biggest lever for impact — see [Adding a State](README.md#adding-a-state) in the README. Every new adapter must be verified against the *real* live source (real products, real available turmas) before being wired into the active registry — a state that looks active but returns an empty catalog is worse than leaving it "coming soon".
2. **Bug Fixes:** Parsing errors, UI issues, edge cases in any adapter.
3. **Data Pipeline & Reliability:** Cache invalidation, concurrency tuning, resilience to upstream format changes.
4. **Frontend & UX:** Accessibility, responsive layout, the Frutiger Aero visual language (glass panels, cursor set, brand-hue theming).
5. **Documentation:** This file, the README, and code comments.

---

## Data Collection Guidelines

Every adapter fetches from a real, public upstream source. When touching adapter code:

- **Respect concurrency limits** (`config.catalogConcurrency`, `turmasConcurrency`, `warmupConcurrency`) — don't hammer a state's source.
- **Cache-first:** Always go through `KeyedAsyncCache` (`src/adapters/keyed-cache.js`) or SurrealDB before a fresh network call.
- **Defensive parsing:** Upstream HTML/JSON shapes change without notice. Parsing must fail gracefully — no uncaught exceptions taking down a route.
- **Public data only.** Never attempt to bypass access controls or scrape non-public data.
- **Verify before activating:** Before adding a state to `ADAPTERS` in `src/adapters/registry.js`, confirm real products *and* at least one real available turma exist at the source — not just that a page loads. See the comments at the top of any existing `<uf>.js` adapter for the kind of verification expected.

---

## Development Workflow

### Branch Conventions

- `feature/<description>`
- `fix/<description>`
- `docs/<description>`
- `refactor/<description>`

### Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat: add SENAI-XX adapter`
- `fix: handle empty turma list in futuro-digital adapter`
- `docs: update adapter guide in CONTRIBUTING.md`
- `refactor: extract hue-to-color mapping into cursor-color.js`
- `chore: bump htmx version`

---

## Code Quality & Verification

Before opening a PR:

```bash
make check     # Biome format + lint (autofix)
make lint      # Same checks, no autofix (what CI runs)
```

### Testing Notice

The repository relies on linting and manual runtime verification — there is no automated test suite yet (a welcome contribution area). When changing an adapter or route:

1. Hit the affected endpoints directly (`GET /api/units?uf=sp&area=tecnologia-da-informacao`, etc.) and check the shape/values look real.
2. Exercise the UI change in both desktop and mobile viewports.
3. For a new/changed adapter, confirm against the real upstream source, not just that the request doesn't throw.

---

## Pull Request Checklist

1. **Title:** Clear, imperative, conventional-commit style.
2. **Context:** Why this change, what problem it solves.
3. **Implementation:** Key structural changes, especially for a new adapter (what backend, how verified).
4. **Verification:** What you actually checked (commands run, screenshots for UI changes).
5. **Quality gates:** `make lint` passes clean.

---

## Code of Conduct

Contributors and maintainers are expected to keep interactions inclusive, professional, and respectful.

## License

By contributing, you agree your contributions are licensed under the [Apache License 2.0](LICENSE).
