import { html, raw } from "./html.js";

const HTMX = "https://cdn.jsdelivr.net/npm/htmx.org@2.0.4/dist/htmx.min.js";
const ALPINE = "https://cdn.jsdelivr.net/npm/alpinejs@3.14.9/dist/cdn.min.js";
const FONTS =
	"https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,400;0,600;0,700;0,800;1,400&display=swap";

const FAVICON =
	"data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🎓</text></svg>";

/**
 * Document shell shared by every page.
 * @param {{ title?: string, hue?: number, uf?: string, area?: string, body: unknown }} p
 */
export function layout({ title = "SENAI SP – Vagas TI", hue = 20, uf = "sp", area = "", body }) {
	return html`<!doctype html>
<html lang="pt-BR" data-uf="${uf}" data-area="${area}" data-hue="${hue}" style="--brand-hue:${hue}">
	<head>
		<meta charset="UTF-8" />
		<meta name="viewport" content="width=device-width, initial-scale=1.0" />
		<link rel="icon" type="image/svg+xml" href="${FAVICON}" />
		<link rel="preconnect" href="https://fonts.googleapis.com" />
		<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
		<link rel="stylesheet" href="${FONTS}" />
		<title>${title}</title>
		<style>[un-cloak]{display:none}</style>
		<link rel="stylesheet" href="/css/aero.css" />
		<script type="module" src="/js/uno.js"></script>
		<script defer src="${HTMX}"></script>
		<script type="module" src="/js/app.js"></script>
		<script defer src="${ALPINE}"></script>
		<script>
			// If the UnoCSS runtime (CDN) never loads, show the page unstyled instead of blank.
			setTimeout(function () {
				document.querySelectorAll("[un-cloak]").forEach(function (e) { e.removeAttribute("un-cloak"); });
			}, 5000);
		</script>
	</head>
	<body un-cloak>
		${body}
	</body>
</html>`;
}

/** Wrapper used by both pages: the sky, the aero-root element, the content column. */
export function shell({ atmosphere, inner, rootClass, column }) {
	return html`
	<div class="aero-root ${rootClass}" style="${raw("cursor: url(/assets/cursors/Arrow.cur), auto")}">
		${atmosphere}
		<div class="${column}">${inner}</div>
	</div>`;
}
