import { DEFAULT_AREA_LABEL } from "../../shared/constants.js";
import { html, raw } from "../html.js";
import { icon } from "../icons.js";
import { contentUrl } from "../urls.js";

// shadcn's <Card> shipped these base classes (after twMerge dropped the ones
// the call sites overrode) — kept verbatim so layout and spacing are unchanged.
const CARD =
	"glass-card border-0 shadow-none bg-transparent text-ink flex flex-col gap-6 rounded-xl py-6";
const CARD_HEADER = "grid auto-rows-min grid-rows-[auto_auto] items-start gap-2 pb-3 pt-5 px-6";
const CARD_TITLE = "leading-none text-sm font-semibold text-ink/80 flex items-center gap-2.5";
const CARD_BODY = "px-6 pb-6 space-y-0.5";

const DATE_DISPLAY_LIMIT = 3;
const BAR_KEYS = ["a", "b", "c", "d", "e", "f"];

// ── Stats ────────────────────────────────────────────────────────────────────

function statCard({ iconName, title, value, sub, highlight = false, delay = 0, valueAttrs = "" }) {
	return html`
	<section x-data="tilt(8)" @mousemove="move($event)" @mouseleave="leave()"
		class="glass-card rounded-2xl p-5 flex items-center gap-4 section-3d cursor-default ${highlight ? "card-highlight ring-1 ring-brand/50" : ""}"
		style="animation-delay:${delay}ms; transition: transform 0.18s ease, box-shadow 0.18s ease">
		<div class="stat-icon-wrap aero-icon-orb h-11 w-11 rounded-full shrink-0 flex items-center justify-center">
			${raw(icon(iconName, "h-5 w-5 text-white drop-shadow-[0_1px_1.5px_rgba(0,0,0,0.4)]"))}
		</div>
		<div class="min-w-0">
			<p class="text-xs text-brand/65 uppercase tracking-wider font-medium truncate">${title}</p>
			<p class="text-2xl font-bold text-ink leading-tight" ${valueAttrs}>${value}</p>
			${sub ? html`<p class="text-xs text-brand-light/62 mt-0.5 truncate">${sub}</p>` : ""}
		</div>
	</section>`;
}

/**
 * While `loading` the values show "…". `refreshUrl` wires the auto-refresh
 * countdown card (its Alpine component re-fetches #content when it reaches 0).
 */
export function statsRow({ courses = [], loading, refreshSeconds, refreshUrl }) {
	const tracked = courses.filter((c) => c.vagas !== null);
	const tracking = tracked.length > 0;
	const total = tracked.reduce((sum, c) => sum + c.vagas, 0);
	const open = tracked.filter((c) => c.vagas > 0).length;
	const dots = "…";
	const fmt = (s) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
	return html`
	<div class="grid grid-cols-2 md:grid-cols-4 gap-3">
		${statCard({ iconName: "book-open", title: "Cursos", value: loading ? dots : courses.length, sub: "presenciais", delay: 80 })}
		${statCard({
			iconName: "users",
			title: "Vagas Abertas",
			value: loading ? dots : tracking ? total : "—",
			sub: tracking ? "total disponível" : "não informado pela fonte",
			highlight: tracking && total > 0,
			delay: 140,
		})}
		${statCard({
			iconName: "circle-check-big",
			title: "Com Vagas",
			value: loading ? dots : tracking ? open : "—",
			sub: loading ? "" : tracking ? `de ${courses.length} cursos` : "ver cada curso",
			highlight: tracking && open > 0,
			delay: 200,
		})}
		${statCard({
			iconName: "trending-up",
			title: "Próx. Refresh",
			value: fmt(refreshSeconds),
			sub: "automático",
			delay: 260,
			valueAttrs: loading
				? ""
				: raw(`x-data="countdown(${refreshSeconds}, '${refreshUrl}')" x-text="label"`),
		})}
	</div>`;
}

// ── Course bars ──────────────────────────────────────────────────────────────

function courseUrl(course, uf) {
	return (
		course.url ??
		(uf === "sc"
			? `https://cursos.sesisenai.org.br/cursos-profissionalizantes/${course.slug}/${course.id}`
			: `https://www.sp.senai.br/curso/${course.slug}/${course.id}`)
	);
}

function plural(n, one, many) {
	return n === 1 ? one : many;
}

export function courseBar({ course, maxVagas, index, paid, uf }) {
	const unknown = course.vagas === null;
	const pct = !unknown && maxVagas > 0 ? (course.vagas / maxVagas) * 100 : 0;
	const hasVagas = !unknown && course.vagas > 0;
	const full = !hasVagas && !unknown && course.turmas > 0;
	const delay = `${index * 55}ms`;

	const dates = course.startDates ?? [];
	const visibleDates = dates.slice(0, DATE_DISPLAY_LIMIT);
	const hidden = dates.length - visibleDates.length;
	const schedules = course.schedules ?? [];
	const prices = course.prices ?? [];
	const priceLabel =
		prices.length === 0
			? null
			: prices.length === 1
				? prices[0]
				: `${prices[0]} – ${prices[prices.length - 1]}`;

	const fill = hasVagas
		? paid
			? "bg-linear-to-r from-accent2-dark via-accent2 to-accent2-light"
			: "bg-linear-to-r from-brand-dark via-brand to-brand-light"
		: full
			? "bg-amber-500/22"
			: unknown
				? "bg-sky-500/12"
				: "bg-ink/6";
	const width = hasVagas ? `${Math.max(pct, 6)}%` : full || unknown ? "100%" : "0%";

	return html`
	<a href="${courseUrl(course, uf)}" target="_blank" rel="noopener noreferrer"
		class="flex items-start gap-3 py-1.5 animate-slide-in rounded-lg px-2 -mx-2 transition-colors duration-150 hover:bg-ink/6 cursor-pointer group ${!hasVagas && !unknown ? "opacity-50 hover:opacity-70" : ""}"
		style="animation-delay:${delay}; contain: layout paint; will-change: transform, opacity">
		<div class="shrink-0 text-right pt-1.5" style="width: clamp(130px, 26%, 200px)">
			<p class="text-sm font-semibold text-ink/95 leading-tight truncate group-hover:text-ink transition-colors" title="${course.name}">${course.name}</p>
			<div class="flex items-center justify-end gap-1.5 mt-0.5">
				${course.hours > 0 ? html`<p class="text-xs text-brand/58">${course.hours}h</p>` : ""}
				${course.isBolsa ? html`<span class="text-[10px] font-bold tracking-wide text-emerald-600/80 uppercase">Bolsa</span>` : ""}
				${full ? html`<span class="text-[10px] font-bold tracking-wide text-amber-600/85 uppercase">Esgotado</span>` : ""}
				${!hasVagas && !full && !unknown ? html`<span class="text-[10px] font-bold tracking-wide text-ink/40 uppercase">Sem turmas</span>` : ""}
				${unknown ? html`<span class="text-[10px] font-bold tracking-wide text-sky-600/70 uppercase">Ver no site</span>` : ""}
			</div>
		</div>

		<div class="flex-1 flex flex-col gap-1.5">
			<div class="relative h-10 rounded-lg overflow-hidden bg-ink/6 border border-ink/10">
				<div class="bar-fill absolute inset-y-0 left-0 rounded-lg ${fill}" style="width:${width}; animation-delay:${delay}">
					${
						hasVagas
							? html`<div class="absolute inset-0 bg-linear-to-b from-white/45 to-transparent rounded-lg"></div>
							<div class="absolute inset-0 bg-linear-to-r from-transparent via-white/25 to-transparent rounded-lg"></div>`
							: ""
					}
				</div>
				<div class="absolute inset-0 flex items-center px-3 gap-2">
					${
						hasVagas
							? html`<span class="text-sm font-bold text-ink drop-shadow-sm">${course.vagas}</span>
							<span class="text-xs text-ink/72">${plural(course.vagas, "vaga", "vagas")}</span>
							${course.turmas > 0 ? html`<span class="ml-auto text-xs text-ink/55 shrink-0">${course.turmas} ${plural(course.turmas, "turma", "turmas")}</span>` : ""}`
							: full
								? html`<span class="text-sm font-bold text-amber-600/85">0</span>
								<span class="text-xs text-amber-600/60">vagas</span>
								${course.turmas > 0 ? html`<span class="ml-auto text-xs text-amber-600/50 shrink-0">${course.turmas} ${plural(course.turmas, "turma", "turmas")} esgotada${course.turmas !== 1 ? "s" : ""}</span>` : ""}`
								: unknown
									? html`<span class="text-xs font-medium text-sky-600/80">Vagas não informadas — ver no site</span>`
									: html`<span class="text-xs font-medium text-ink/40 italic">Sem turmas abertas</span>`
					}
				</div>
			</div>

			${
				visibleDates.length > 0
					? html`<div class="flex flex-wrap items-center gap-x-2.5 gap-y-1" title="${dates.join(" · ")}">
						${raw(icon("calendar-days", "aero-icon-glint h-3 w-3 text-emerald-600/80 shrink-0"))}
						${visibleDates.map((d) => html`<span class="text-xs text-emerald-600/85 font-medium">${d}</span>`)}
						${hidden > 0 ? html`<span class="text-xs text-ink/40">+${hidden} data${hidden !== 1 ? "s" : ""}</span>` : ""}
					</div>`
					: ""
			}

			${
				schedules.length > 0
					? html`<div class="flex flex-wrap items-center gap-x-2.5 gap-y-1">
						${raw(icon("clock", "aero-icon-glint h-3 w-3 text-ink/42 shrink-0"))}
						${schedules.map((s) => html`<span class="text-xs text-ink/48">${s.periodo} · ${s.horario}</span>`)}
					</div>`
					: ""
			}

			${
				paid && priceLabel
					? html`<div class="flex items-center gap-x-2.5">
						${raw(icon("dollar-sign", "h-3 w-3 text-amber-600/75 shrink-0"))}
						<span class="text-xs text-amber-600/80 font-medium">${priceLabel}</span>
					</div>`
					: ""
			}
		</div>
	</a>`;
}

function skeletonBar(delay) {
	return html`
	<div class="flex items-center gap-3 py-1.5 opacity-0 animate-slide-in" style="animation-delay:${delay}ms">
		<div class="shrink-0 h-9 rounded-lg bg-ink/8 animate-pulse" style="width: clamp(130px, 26%, 200px)"></div>
		<div class="flex-1 h-10 rounded-lg bg-ink/8 animate-pulse"></div>
	</div>`;
}

// ── Cards ────────────────────────────────────────────────────────────────────

const freeTitleBar =
	"inline-block h-1 w-5 rounded-full bg-linear-to-r from-brand to-brand-light shadow-[0_0_8px_oklch(0.6_0.2_var(--brand-hue)/0.55)]";
const paidTitleBar =
	"inline-block h-1 w-5 rounded-full bg-linear-to-r from-accent2 to-accent2-light shadow-[0_0_8px_oklch(0.6_0.14_200/0.5)]";

function chartCard({ paid, unitName, body }) {
	return html`
	<div class="${CARD} section-3d ${paid ? "section-3d-5 mt-8" : "glass-card-scan section-3d-4"}">
		<div class="${CARD_HEADER}">
			<div class="${CARD_TITLE}">
				<span class="${paid ? paidTitleBar : freeTitleBar}"></span>
				Cursos ${paid ? "Pagos" : "Gratuitos"} — ${unitName}
			</div>
		</div>
		<div class="${CARD_BODY} px-6">${body}</div>
	</div>`;
}

export function freeCard({ courses, unitName, uf }) {
	const tracked = courses.filter((c) => c.vagas !== null);
	const max = Math.max(...tracked.map((c) => c.vagas), 1);
	return chartCard({
		paid: false,
		unitName,
		body: courses.map((course, index) =>
			courseBar({ course, maxVagas: max, index, paid: false, uf }),
		),
	});
}

export function paidCard({ courses, unitName, uf }) {
	const tracked = courses.filter((c) => c.vagas !== null);
	const max = Math.max(...tracked.map((c) => c.vagas), 1);
	return chartCard({
		paid: true,
		unitName,
		body: courses.map((course, index) =>
			courseBar({ course, maxVagas: max, index, paid: true, uf }),
		),
	});
}

/** Skeleton bars, swapped for the "Buscando dados do SENAI…" card after 800 ms. */
function loadingCards(unitName) {
	const skeleton = (paid) =>
		chartCard({ paid, unitName, body: BAR_KEYS.map((_, i) => skeletonBar(i * 55)) });
	return html`
	<div class="contents" x-data="{ slow: false }" x-init="setTimeout(() => (slow = true), 800)">
		<div class="contents" x-show="!slow">${skeleton(false)}</div>
		<div class="contents" x-show="slow" x-cloak>${loadingCard(unitName, false)}</div>
		<div class="contents" x-show="!slow">${skeleton(true)}</div>
		<div class="contents" x-show="slow" x-cloak>${loadingCard(unitName, true)}</div>
	</div>`;
}

function loadingCard(unitName, paid) {
	const ring = paid ? "border-accent2/22" : "border-brand/25";
	const ring2 = paid ? "border-accent2/32" : "border-brand/35";
	return html`
	<div class="${CARD} section-3d section-3d-4 glass-card-scan">
		<div class="px-6 py-16 flex flex-col items-center gap-5">
			<div class="relative flex items-center justify-center">
				<div class="absolute h-20 w-20 rounded-full border animate-ping ${ring}" style="animation-duration: 2s"></div>
				<div class="absolute h-14 w-14 rounded-full border animate-ping ${ring2}" style="animation-duration: 1.5s; animation-delay: 0.3s"></div>
				<div class="h-10 w-10 rounded-full ring-1 flex items-center justify-center ${paid ? "bg-accent2/10 ring-accent2/32" : "bg-brand/10 ring-brand/32"}">
					${raw(icon("loader-circle", `h-5 w-5 animate-spin ${paid ? "text-accent2" : "text-brand"}`))}
				</div>
			</div>
			<div class="text-center space-y-1.5">
				<p class="text-sm font-semibold text-ink/72">Buscando dados do SENAI…</p>
				<p class="text-xs ${paid ? "text-accent2/58" : "text-brand/58"}">
					Consultando turmas disponíveis em <span class="${paid ? "text-accent2/78" : "text-brand/72"}">${unitName}</span>
				</p>
				<p class="text-xs text-ink/38 mt-2">Esta unidade não estava pré-carregada — pode levar alguns instantes.</p>
			</div>
			<div class="w-48 h-0.5 rounded-full bg-ink/8 overflow-hidden">
				<div class="h-full w-1/3 rounded-full bg-linear-to-r animate-[shimmer-sweep_1.8s_ease-in-out_infinite] ${paid ? "from-accent2-dark to-accent2-light" : "from-brand-dark to-brand-light"}"></div>
			</div>
		</div>
	</div>`;
}

export function noCoursesCard({ unitName, stateName, areaLabel }) {
	return html`
	<div class="${CARD} section-3d section-3d-4 border border-brand-dark/30">
		<div class="px-6 py-14 flex flex-col items-center gap-4">
			<div class="h-10 w-10 rounded-full bg-brand/10 ring-1 ring-brand/28 flex items-center justify-center">
				${raw(icon("circle-x", "h-5 w-5 text-brand/75"))}
			</div>
			<div class="text-center space-y-1.5">
				<p class="text-sm font-semibold text-brand/72">Nenhum curso qualificado encontrado</p>
				<p class="text-xs text-ink/42 leading-relaxed max-w-sm">
					A unidade <span class="text-ink/55">${unitName}</span> não possui cursos presenciais de ${areaLabel} cadastrados no SENAI ${stateName} no momento.
				</p>
			</div>
		</div>
	</div>`;
}

export function comingSoonCard({ stateName }) {
	return html`
	<div class="${CARD} section-3d section-3d-4">
		<div class="px-6 py-16 flex flex-col items-center gap-4">
			<div class="h-10 w-10 rounded-full bg-ink/10 ring-1 ring-glass/70 flex items-center justify-center">
				${raw(icon("clock", "h-5 w-5 text-ink/62"))}
			</div>
			<div class="text-center space-y-1.5">
				<p class="text-sm font-semibold text-ink/80">Em breve</p>
				<p class="text-xs text-ink/45 leading-relaxed max-w-sm">
					Ainda estamos verificando como o SENAI de <span class="text-ink/62">${stateName}</span> publica vagas de cursos — assim que houver uma fonte de dados confiável, este estado passa a mostrar cursos reais.
				</p>
			</div>
		</div>
	</div>`;
}

export function errorBanner(message) {
	return html`
	<div class="glass-card rounded-xl px-4 py-3 flex items-center gap-3 border border-destructive/35 section-3d">
		${raw(icon("circle-alert", "h-4 w-4 text-destructive shrink-0"))}
		<p class="text-sm text-destructive">${message}</p>
	</div>`;
}

// ── Whole content region ─────────────────────────────────────────────────────

/** Skeleton state. `loaderUrl` (optional) kicks off the real fetch as soon as it is mounted. */
export function contentLoading({ unitName, refreshSeconds, loaderUrl }) {
	return html`
	${loaderUrl ? html`<div hidden hx-get="${loaderUrl}" hx-trigger="load" hx-target="#content" hx-swap="innerHTML"></div>` : ""}
	${statsRow({ loading: true, refreshSeconds })}
	${loadingCards(unitName)}`;
}

export function contentLoaded({ free, paid, sel, state, unitName, areaLabel, refreshSeconds }) {
	const noFree = free.courses.length === 0;
	const noPaid = paid.courses.length === 0;
	return html`
	${statsRow({ courses: free.courses, loading: false, refreshSeconds, refreshUrl: contentUrl(sel) })}
	${noFree && noPaid ? noCoursesCard({ unitName, stateName: state.name, areaLabel: areaLabel ?? DEFAULT_AREA_LABEL }) : ""}
	${noFree ? "" : freeCard({ courses: free.courses, unitName, uf: sel.uf })}
	${noPaid ? "" : paidCard({ courses: paid.courses, unitName, uf: sel.uf })}`;
}
