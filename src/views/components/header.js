import { DEFAULT_AREA_LABEL } from "../../shared/constants.js";
import { html, raw } from "../html.js";
import { icon } from "../icons.js";
import { contentUrl } from "../urls.js";

// SP's and DF's own logos need no contour — SP is a white wordmark on solid red,
// and DF's small flag icon has fine internal strokes that pick up visible
// artifacts even from the soft blur version. Every other mark gets a soft
// blur-based white contour (not hard offset duplicates — those double every fine
// internal stroke of a detailed mark into noisy artifacts) so dark-on-transparent
// marks like Minas Gerais' stay legible against the dark glass, then the
// brand-hue glow on top.
function logoFilter(uf) {
	const contour =
		uf === "sp" || uf === "df"
			? ""
			: "drop-shadow(0 0 0.6px white) drop-shadow(0 0 0.6px white) drop-shadow(0 0 1.2px oklch(1 0 0 / 0.5)) ";
	return `${contour}drop-shadow(0 0 4px oklch(0.58 0.22 var(--brand-hue) / 0.55)) drop-shadow(0 0 10px oklch(0.5 0.2 var(--brand-hue) / 0.3))`;
}

/** Logo link — swapped only when the state changes, so its float animation survives data reloads. */
export function headerLogo(state) {
	return html`
	<a id="hdr-logo" x-data="logoTilt()" @mousemove="move($event)" @mouseleave="leave()"
		href="https://${state.sourceLabel}" target="_blank" rel="noopener noreferrer"
		aria-label="Abrir site oficial do SENAI ${state.name}" class="logo-link shrink-0" @click.stop>
		<img src="${state.logo}" alt="SENAI ${state.name}" class="h-10 w-auto logo-float cursor-wagtail" data-ani="wagtail"
			style="filter:${raw(logoFilter(state.uf))}" />
	</a>`;
}

/** Title + subtitle. `title` is the unit name (or the state name when coming soon). */
export function headerTitle({ title, areaLabel = DEFAULT_AREA_LABEL }) {
	return html`
	<div id="hdr-title">
		<h1 class="text-lg font-bold text-ink tracking-tight leading-tight">SENAI ${title}</h1>
		<p class="text-sm text-brand-light/78">Cursos de ${areaLabel}</p>
	</div>`;
}

const BTN =
	"refresh-btn inline-flex items-center justify-center gap-1.5 whitespace-nowrap rounded-md text-sm font-medium transition-all disabled:pointer-events-none disabled:opacity-50 shrink-0 outline-none focus-visible:border-brand focus-visible:ring-brand/50 focus-visible:ring-[3px] aero-button h-8 px-2.5";

/**
 * Right side of the header: "updated at" / loading hint + refresh button.
 * @param {{ sel: {uf: string, area: string, unit: number}, mode: "idle"|"loading"|"none", updatedAt?: string }} p
 */
export function headerMeta({ sel, mode, updatedAt }) {
	if (mode === "none")
		return html`<div id="hdr-meta" class="flex items-center gap-3 ml-auto flex-wrap"></div>`;
	const loading = mode === "loading";
	return html`
	<div id="hdr-meta" class="flex items-center gap-3 ml-auto flex-wrap">
		${
			updatedAt && !loading
				? html`<span class="flex items-center gap-1.5 text-xs text-brand-light/68">
					${raw(icon("clock", "aero-icon-glint h-3 w-3 shrink-0"))}
					<span>Atualizado às <time datetime="${updatedAt}" x-init="$el.textContent = localTime($el.dateTime)">${serverTime(updatedAt)}</time></span>
				</span>`
				: ""
		}
		${
			loading
				? html`<span x-data="{ slow: false }" x-init="setTimeout(() => (slow = true), 800)"
					class="flex items-center gap-1.5 text-xs text-brand/65">
					${raw(icon("loader-circle", "h-3 w-3 animate-spin shrink-0"))}
					<span x-text="slow ? 'Consultando SENAI…' : 'Buscando cursos…'">Buscando cursos…</span>
				</span>`
				: ""
		}
		<button type="button" class="${BTN}" ${loading ? raw("disabled") : ""}
			hx-get="${contentUrl(sel)}" hx-vals='js:{"_": Date.now()}' hx-target="#content" hx-swap="innerHTML" hx-disabled-elt="this">
			${raw(icon("refresh-cw", `size-4 ${loading ? "animate-spin" : ""}`))}
			<span class="label-idle">Atualizar</span><span class="label-busy">Atualizando…</span>
		</button>
	</div>`;
}

// Fallback text only (the browser overwrites it with the viewer's local time).
function serverTime(iso) {
	return new Date(iso).toLocaleTimeString("pt-BR", {
		hour: "2-digit",
		minute: "2-digit",
		timeZone: "America/Sao_Paulo",
	});
}

/** The full header card (first paint). */
export function header({ state, title, areaLabel, sel, metaMode }) {
	return html`
	<header x-data="tilt(5)" @mousemove="move($event)" @mouseleave="leave()"
		class="glass-card rounded-2xl px-6 py-5 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 section-3d section-3d-1 cursor-default"
		style="transition: transform 0.18s ease, box-shadow 0.18s ease">
		<div class="flex items-center gap-4">
			${headerLogo(state)}
			${headerTitle({ title, areaLabel })}
		</div>
		${headerMeta({ sel, mode: metaMode })}
	</header>`;
}
