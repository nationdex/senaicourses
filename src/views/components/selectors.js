import { aniCursor } from "../cursor.js";
import { html, jsonAttr, raw } from "../html.js";
import { icon } from "../icons.js";
import { contentUrl, qs } from "../urls.js";

const FLAG = "h-3.5 w-5 object-cover rounded-[3px] ring-1 ring-glass/70 shrink-0";
const PANEL =
	"popover-3d absolute left-0 right-0 top-full mt-1.5 z-50 glass-card rounded-xl border border-ink/12 overflow-hidden shadow-2xl shadow-black/60";
const LIST = "overflow-y-auto divide-y divide-ink/8 aero-scroll";
const stagger = (i) => `animation-delay:${Math.min(i, 10) * 16}ms`;

// Popover panels are mounted by Alpine (x-if) only while open or animating
// closed — a glass panel carries a continuous backdrop-filter blur + shimmer,
// real ongoing GPU/paint cost even at opacity:0. htmx.process() wires the
// hx-* attributes on the freshly mounted list items.
const panel = (cls, body) => html`
	<template x-if="phase">
		<div x-init="htmx.process($el)" :data-state="phase" class="${PANEL}">
			<ul class="${cls} ${LIST}">${body}</ul>
		</div>
	</template>`;

/** @param {{ states: import("../../shared/types.js").StateInfo[], selectedUf: string, unit: number }} p */
export function stateSelector({ states, selectedUf, unit }) {
	const selected = states.find((s) => s.uf === selectedUf) ?? states[0];
	const trigger = aniCursor("busy", selected.hue);
	return html`
	<div x-data="popover()" @mousedown.window="outside($event)" class="relative w-full sm:w-56">
		<button type="button" data-state="closed" :data-state="open ? 'open' : 'closed'"
			class="popover-trigger glass-card rounded-xl flex items-center gap-2 px-3 py-2 w-full border border-ink/12 transition-colors duration-200 ${trigger.cls}"
			data-ani="${trigger.data}" :class="open && 'border-ink/20'" @click="toggle()">
			<img src="${selected.flag}" alt="" class="${FLAG}" />
			<span class="flex-1 text-sm text-ink/80 truncate text-left">${selected.name}</span>
			${raw(icon("globe", "aero-icon-glint popover-trigger-icon h-3.5 w-3.5 text-ink/45 shrink-0"))}
		</button>
		${panel(
			"max-h-72",
			states.map((s, i) => {
				const c = aniCursor(s.status === "coming-soon" ? "unavailable" : "busy", s.hue);
				return html`
				<li class="popover-item" style="${stagger(i)}">
					<button type="button"
						class="w-full text-left px-4 py-2.5 flex items-center gap-3 text-sm transition-colors duration-100 hover:bg-ink/8 hover:text-ink ${c.cls} ${s.uf === selectedUf ? "text-ink bg-ink/8" : "text-ink/72"}"
						data-ani="${c.data}"
						hx-get="/ui/state?${qs({ uf: s.uf, unit })}" hx-target="#selectors" hx-swap="innerHTML"
						@click="set(false)"
						${s.status === "active" ? raw(`@mouseenter="fetch('/api/units?uf=${s.uf}').catch(() => {})"`) : ""}>
						<img src="${s.flag}" alt="" class="${FLAG}" />
						<span class="truncate font-medium flex-1">${s.name}</span>
						${s.status === "coming-soon" ? html`<span class="text-[10px] font-bold tracking-wide text-ink/40 uppercase shrink-0">Em breve</span>` : ""}
					</button>
				</li>`;
			}),
		)}
	</div>`;
}

/** Placeholder shown while the area list loads; swaps itself for areaSelector(). */
export function areaLoading(sel) {
	return html`
	<div class="glass-card rounded-xl flex items-center gap-2 px-3 py-2 w-full sm:w-64 border border-ink/12"
		hx-get="/ui/areas?${qs(sel)}" hx-trigger="load" hx-target="this" hx-swap="outerHTML">
		${raw(icon("loader-circle", "h-3.5 w-3.5 text-brand/68 animate-spin shrink-0"))}
		<span class="text-sm text-ink/40 animate-pulse">Carregando áreas…</span>
	</div>`;
}

/** @param {{ areas: import("../../shared/types.js").Area[], selectedSlug: string, uf: string, unit: number }} p */
export function areaSelector({ areas, selectedSlug, uf, unit }) {
	const selected = areas.find((a) => a.slug === selectedSlug) ?? areas[0];
	return html`
	<div x-data="popover(${jsonAttr({ selected: selected?.slug ?? "", label: selected?.label ?? "Selecionar área…" })})"
		@mousedown.window="outside($event)" class="relative w-full sm:w-64">
		<button type="button" data-state="closed" :data-state="open ? 'open' : 'closed'"
			class="popover-trigger glass-card rounded-xl flex items-center gap-2 px-3 py-2 cursor-pointer w-full border border-ink/12 transition-colors duration-200"
			:class="open && 'border-ink/20'" @click="toggle()">
			${raw(icon("book-open", "aero-icon-glint h-3.5 w-3.5 text-brand/75 shrink-0"))}
			<span class="flex-1 text-sm text-ink/80 truncate text-left" x-text="label"></span>
			${raw(icon("globe", "aero-icon-glint popover-trigger-icon h-3.5 w-3.5 text-ink/45 shrink-0"))}
		</button>
		${panel(
			"max-h-72",
			areas.map(
				(a, i) => html`
				<li class="popover-item" style="${stagger(i)}">
					<button type="button" data-slug="${a.slug}" data-label="${a.label}"
						class="w-full text-left px-4 py-2.5 flex items-center gap-3 text-sm transition-colors duration-100 hover:bg-ink/8 hover:text-ink"
						:class="selected === $el.dataset.slug ? 'text-ink bg-ink/8' : 'text-ink/72'"
						hx-get="/ui/area?${qs({ uf, area: a.slug, unit })}" hx-target="#unit-slot" hx-swap="outerHTML"
						@click="selected = $el.dataset.slug; label = $el.dataset.label; set(false)">
						<span class="truncate font-medium flex-1">${a.label}</span>
					</button>
				</li>`,
			),
		)}
	</div>`;
}

/**
 * Unit slot while units load. `load` wires the fetch that swaps this slot for
 * unitSearch(); without it the slot is a passive "waiting for áreas" spinner.
 */
export function unitLoading(sel, load = false) {
	const trigger = load
		? raw(`hx-get="/ui/units?${qs(sel)}" hx-trigger="load" hx-target="this" hx-swap="outerHTML"`)
		: "";
	return html`
	<div id="unit-slot" class="contents" ${trigger}>
		<div class="glass-card rounded-xl flex items-center gap-2 px-3 py-2 w-full sm:w-72 border border-ink/12">
			${raw(icon("loader-circle", "h-3.5 w-3.5 text-brand/68 animate-spin shrink-0"))}
			<span class="text-sm text-ink/40 animate-pulse">Carregando unidades…</span>
		</div>
	</div>`;
}

/**
 * @param {{ units: import("../../shared/types.js").UnitInfo[], selectedId: number, uf: string, area: string, areaLabel: string, loaderUrl?: string }} p
 */
export function unitSearch({ units, selectedId, uf, area, areaLabel, loaderUrl }) {
	const selected = units.find((u) => u.id === selectedId);
	const sel = (unit) => ({ uf, area, unit });
	return html`
	<div id="unit-slot" class="contents">
		<div x-data="unitSearch(${jsonAttr({ selected: selectedId, label: selected?.name ?? "Selecionar unidade…" })})"
			@mousedown.window="outside($event)" class="relative w-full sm:w-72">
			<div role="button" tabindex="0" data-state="closed" :data-state="open ? 'open' : 'closed'"
				class="popover-trigger glass-card rounded-xl flex items-center gap-2 px-3 py-2 cursor-text border border-ink/12 transition-colors duration-200"
				:class="open && 'border-brand/45 shadow-[0_0_16px_oklch(0.6_0.2_var(--brand-hue)/0.18)]'"
				@click="openAndFocus()" @keydown.enter.prevent="open || openAndFocus()">
				${raw(icon("search", "aero-icon-glint h-3.5 w-3.5 text-brand/75 shrink-0"))}
				<input x-ref="input" x-show="open" x-cloak x-model="query" type="text" autocomplete="off"
					class="flex-1 bg-transparent text-sm text-ink placeholder:text-ink/40 outline-none min-w-0"
					placeholder="Cidade ou ID da unidade…"
					@keydown.escape="set(false)" @keydown.enter.prevent.stop="pickFirst()" />
				<span x-show="!open" class="flex-1 text-sm text-ink/80 truncate" x-text="label"></span>
				${raw(icon("map-pin", "aero-icon-glint h-3 w-3 text-brand/70 shrink-0"))}
			</div>
			<template x-if="phase">
				<div x-init="htmx.process($el)" :data-state="phase" class="${PANEL}">
					<p x-show="none" class="px-4 py-3 text-sm text-ink/45 text-center">Nenhuma unidade encontrada</p>
					<ul x-ref="list" class="max-h-64 ${LIST}">
						${units.map(
							(u, i) => html`
						<li class="popover-item" style="${stagger(i)}" data-search="${`${u.name} ${u.officialId ?? u.id} ${u.id}`.toLowerCase()}" x-show="matches($el)">
							<button type="button" data-id="${u.id}" data-name="${u.name}"
								class="w-full text-left px-4 py-2.5 flex items-center justify-between gap-3 text-sm transition-colors duration-100 hover:bg-brand/10 hover:text-ink"
								:class="selected === Number($el.dataset.id) ? 'text-brand bg-brand/8' : 'text-ink/72'"
								hx-get="/ui/loading?${qs(sel(u.id))}" hx-target="#content" hx-swap="innerHTML"
								@click="pick($el)"
								@mouseenter="prefetch('${contentUrl(sel(u.id))}')">
								<span class="truncate font-medium">${u.name}</span>
								<span class="text-xs text-ink/40 shrink-0">#${u.officialId ?? u.id}</span>
							</button>
						</li>`,
						)}
					</ul>
				</div>
			</template>
		</div>
		${
			units.length > 0
				? html`<p class="text-xs text-ink/38">${units.length} unidade${units.length !== 1 ? "s" : ""} com cursos de ${areaLabel}</p>`
				: ""
		}
		${loaderUrl ? html`<div hidden hx-get="${loaderUrl}" hx-trigger="load" hx-target="#content" hx-swap="innerHTML"></div>` : ""}
	</div>`;
}
