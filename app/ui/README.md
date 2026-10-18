# app/ui

Server-rendered UI: SurrealQL builds the HTML, htmx swaps fragments, Alpine handles dropdowns and theme. No `.js` files. See `DESIGN.md` for the visual contract.

Load: `app/load.sh <db>` (all files, incl. `ui/*.surql`). Dev data (not auto-loaded): `app/load.sh cursos_ui app/ui/dev/dev-seed.surql` (needs `seed/states.surql`).

## Routes (all under `/api/senai/<db>`)
| route | returns |
|---|---|
| `GET /home?uf=&area=&unit=` | full page (shareable deep link) |
| `GET /main?uf=&area=&unit=` | htmx fragment: `<title>` + `<main id="app">` + out-of-band `<footer id="ftr">` |
| `GET /privacidade` | privacy page |
| `GET /ui.css` | design tokens + non-utility CSS |

Params are optional and validated: unknown `uf` -> `sp`; `area` not in the state -> `tecnologia-da-informacao` or first; `unit` not among the units with courses in that área -> first. Navigation uses `hx-get /main` + `hx-push-url /home?...`; the Atualizar button re-requests `/main` (re-reads the DB only).
Needs from A: `/assets/senai.svg` and `/assets/flags/<uf>.png`.

## Files / functions
- `00_core.surql`: `fn::ui::esc`, `plural`, `url`, `sel` (validated selection + lists), `k`/`c` (UnoCSS class registry), `ico`, `ico_c`, `document` (head, inline UnoCSS theme config, CDN scripts), `html`.
- `05_css.surql`: `fn::ui::css` (tokens + the few non-utility rules).
- `10_components.surql`: `dd_data`, `dd_item`, `dropdown`, `filters`, `theme_toggle`, `site_header`, `site_footer`, `updated`, `stat`, `stats`, `course_url`, `course_row`, `course_section`, `notice`.
- `20_pages.surql`: `main_body`, `main`, `home_page`, `privacy_page`.
- `30_routes.surql`: the `DEFINE API` routes.
- `dev/dev-seed.surql`: sp (3 areas, 17 units, every course state), sc, mg.

SurrealQL gotchas hit: no `+=` on variables (use `array::join((SELECT VALUE ... FROM $arr), '')`; parenthesise the SELECT), `:hidden="q && ..."` must be coerced with `!!q` in Alpine, and the `'...'` strings escape apostrophes as `\'`.
