# UI design contract (workstream B)

## Product direction
A public, utilitarian lookup tool: a student picks **estado, área, unidade** and reads which SENAI courses have open seats. The page is a catalogue/dashboard, not a landing page. Tone: institutional, calm, dense but legible — modelled on SENAI's own web style, not on the old "Frutiger Aero" look (dropped completely: no glass, gradients, glows, bubbles, tilt, custom cursors).

## Sources
- https://www.sp.senai.br/ — thin top utility bar, white header with SVG logo top-left, red accents, tile grids, footer with links. Used for: topbar, header, red accent line, tile stats, footer.
- https://cleissonp.github.io/chatgpt/dentro-de-um-llm.html — uppercase micro-labels, numbered section cards ("01", "02"), mono code labels, light/dark toggle. Used for: `.micro` labels, numbered section headers, mono hour/ID chips, theme toggle.
- Uizze MCP (`find_ui_references`, one query, web): returned Tech Barcelona and Reducto. Both are marketing sites, not catalogue UIs; judged **related, not exact** and not used as layout evidence. No state-specific references were found.
- Image-first step of the anti-ui-slop skill was **not done**: it needs an authorized image-generation tool and the owner said not to spend PicsArt credits. The target was the real SENAI pages above plus the legacy page's feature set.

## Styling method
Markup is styled with **UnoCSS utility classes** (runtime from jsDelivr, default preset, `@unocss/runtime@66.1.0`). Class strings live in one registry, `fn::ui::k(name)` / `fn::ui::c(name)` (00_core.surql). Colours and the two font families are mapped in a small inline config block (`window.__unocss.theme`, in `fn::ui::document`) to the CSS variables below, so utilities like `bg-surf text-muted border-line` follow the theme. `/ui.css` keeps only what utilities cannot express: the token variables (light, dark, and `prefers-color-scheme` default), a minimal reset, `[x-cloak]`/`[un-cloak]`, focus ring, and a few `:has()`/pseudo-element/`htmx-request` rules.

Theme flash: no app JS. The CSS `prefers-color-scheme` default covers first paint; Alpine only applies the stored manual override. `<body>` carries `x-cloak un-cloak` (hidden until both Alpine and UnoCSS have run), so the page is first shown already in the right theme. Tested: system dark + stored light shows light from the first visible frame. Trade-off: if a CDN script fails the body stays hidden.

## Tokens (CSS custom properties in `fn::ui::css()`, served at `/ui.css`)
| token | light | dark |
|---|---|---|
| bg | #ffffff | #212121 |
| fg | #171717 | #f5f5f5 |
| muted | #6b6b6b | #b5b5b5 |
| line | #e5e5e5 | #454545 |
| surface / surface-2 | #f7f7f8 / #eeeeee | #2f2f2f / #3a3a3a |
| red (text, accents) | #e30613 (hover #b8000b) | #ff4b55 (#e63842) |
| button fill | #e30613 in both themes (white text keeps >4.5:1) | |
Radius 12px (10px inputs, 6px chips). Fonts: Inter (body), Montserrat 700-900 (display), system mono for hours/IDs. Status colors (Bolsa green, Esgotado amber) are semantic, used only on small badges.

## Layout
1120px column, 16px gutters (24px from 768px). Order: red 3px top rule, utility bar (disclaimer, privacy, theme toggle), header (the single SENAI logo), title block (micro-label, h1 = unit name, subtitle with unit count, "Atualizado às" + Atualizar), filter panel (3 dropdowns: 1 column below 768px), 4 stat tiles (2x2 on phones), numbered course lists (free "01", paid "02"), footer (source label, privacy link, disclaimer).
Course row: name (whole row is the link to the official page, one tab stop), hours + Bolsa/Esgotado/Sem turmas/Ver no site badges, facts (start dates, schedules, price), right column seat count + turmas + proportional bar (red free, ink paid; scale = max seats in that list).

## Rules
- One logo (`{base}/assets/senai.svg`); all 27 flags live in the state dropdown only.
- Motion: only colour transitions and the refresh icon spinning while an htmx request runs; `prefers-reduced-motion` disables it. Loading = dimmed results + "Carregando…" via `htmx-request` on `#app`.
- Accessibility: labelled controls, visible `:focus-visible` ring, skip link, dropdown = button (`aria-expanded`) + listbox of real links (work without JS), Esc closes and refocuses, ArrowUp/Down move, Enter on the search box opens the first match, focus returns to the trigger after a swap. Contrast checked by token choice (muted #6b6b6b on #f7f7f8 is about 4.9:1).
- Theme: Alpine `$persist` (`senai-theme`, localStorage); unset follows `prefers-color-scheme`.
- Escaping: every DB value goes through `fn::ui::esc`; URL parts are validated in `fn::ui::sel` (state code from table, área slug from table, unit integer).

## Required states (all rendered and checked)
Populated; vagas null ("Ver no site"); 0 vagas with turmas (Esgotado); no turmas; Bolsa; paid with one price / price range / none; long course name; many dates (+N datas) and several schedules; coming-soon state (Em breve + explanation, only the state filter shown); state with no data yet ("Coletando dados"); unit/área with no courses; deep link with invalid params (falls back to defaults); loading (htmx indicator); no JS (links still navigate to full pages).

## Known gaps
- Course links exist only for SP, SC or rows that carry `url`; other states render the name without a link.
- No auto-refresh countdown (legacy had one): the refresh control re-reads the DB; scraping is a background job.
- Inline UnoCSS config block (colours + font families only) is the one inline `<script>` besides CDN includes.
