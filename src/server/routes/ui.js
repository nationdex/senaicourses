// HTML fragments for htmx. Each endpoint returns the markup for the element the
// request targets, plus out-of-band (hx-swap-oob) updates for the other parts of
// the page that depend on the same selection (header, footer, content region).
import { config } from "../../../config/config.js";
import { STATES } from "../../adapters/registry.js";
import { DEFAULT_AREA_LABEL, DEFAULT_AREA_SLUG } from "../../shared/constants.js";
import {
	comingSoonCard,
	contentLoaded,
	contentLoading,
	errorBanner,
} from "../../views/components/content.js";
import { footerInner } from "../../views/components/footer.js";
import { headerLogo, headerMeta, headerTitle } from "../../views/components/header.js";
import {
	areaLoading,
	areaSelector,
	stateSelector,
	unitLoading,
	unitSearch,
} from "../../views/components/selectors.js";
import { html } from "../../views/html.js";
import { contentUrl, pageUrl } from "../../views/urls.js";
import { l1 } from "../l1.js";
import { adapterOf, selection, stateOf } from "../selection.js";

const REFRESH = config.refreshIntervalSeconds;

/** Adds hx-swap-oob to the root element of a fragment (already-safe markup). */
function oobRaw(markup, mode = "true") {
	return html([String(markup).replace(/^\s*<(\w+)/, `<$1 hx-swap-oob="${mode}"`)]);
}

/** Replace a persistent container's children without re-creating it (keeps its entrance animation). */
const oobInner = (selector, children) =>
	html`<div hx-swap-oob="innerHTML:${selector}">${children}</div>`;

function respond(parts, { ctx, push, cache = "no-store" } = {}) {
	const headers = { "Content-Type": "text/html; charset=utf-8", "Cache-Control": cache };
	if (ctx) headers["HX-Trigger"] = JSON.stringify({ ctx });
	if (push) headers["HX-Push-Url"] = push;
	return new Response(html`${parts}`.toString(), { headers });
}

async function areaLabelOf(adapter, slug) {
	try {
		return (await adapter.getAreas()).find((a) => a.slug === slug)?.label ?? DEFAULT_AREA_LABEL;
	} catch {
		return DEFAULT_AREA_LABEL;
	}
}

async function unitOf(adapter, unit) {
	try {
		const found = (await adapter.getUnits()).find((u) => u.id === unit);
		return {
			name: found?.name ?? `Unidade ${unit}`,
			displayId: found?.officialId ?? unit,
		};
	} catch {
		return { name: `Unidade ${unit}`, displayId: unit };
	}
}

const footerOob = (state, unit) =>
	oobInner(
		"#footer",
		footerInner({ state, comingSoon: false, unitName: unit.name, unitDisplayId: unit.displayId }),
	);

export const uiRoutes = {
	// State picked: rebuild the selector bar, logo, title and content region.
	"/ui/state": {
		GET(req) {
			const picked = selection(new URL(req.url));
			const state = stateOf(picked.uf);
			const comingSoon = state.status === "coming-soon";
			const sel = { uf: state.uf, area: DEFAULT_AREA_SLUG, unit: picked.unit };
			const unitName = `Unidade ${sel.unit}`;
			return respond(
				[
					stateSelector({ states: STATES, selectedUf: state.uf, unit: sel.unit }),
					comingSoon ? "" : [areaLoading(sel), unitLoading(sel)],
					oobRaw(headerLogo(state)),
					oobRaw(headerTitle({ title: comingSoon ? state.name : unitName })),
					oobRaw(headerMeta({ sel, mode: comingSoon ? "none" : "loading" })),
					oobInner(
						"#content",
						comingSoon
							? comingSoonCard({ stateName: state.name })
							: contentLoading({ unitName, refreshSeconds: REFRESH }),
					),
					oobInner(
						"#footer",
						footerInner({ state, comingSoon, unitName, unitDisplayId: sel.unit }),
					),
				],
				{ ctx: { uf: state.uf, area: sel.area, hue: state.hue }, push: pageUrl(sel) },
			);
		},
	},

	// Área list loaded (or fell back): swaps the placeholder, then starts the unit load.
	"/ui/areas": {
		GET: l1(async (req) => {
			const picked = selection(new URL(req.url));
			const adapter = adapterOf(picked.uf);
			let areas = [];
			try {
				areas = await adapter.getAreas();
			} catch {}
			if (areas.length === 0) areas = [{ slug: DEFAULT_AREA_SLUG, label: DEFAULT_AREA_LABEL }];
			// Not every state has the default área (e.g. MT) — fall back to its first.
			const chosen = areas.some((a) => a.slug === picked.area) ? picked.area : areas[0].slug;
			const sel = { ...picked, area: chosen };
			const label = areas.find((a) => a.slug === chosen)?.label ?? DEFAULT_AREA_LABEL;
			return respond(
				[
					areaSelector({ areas, selectedSlug: chosen, uf: sel.uf, unit: sel.unit }),
					oobRaw(unitLoading(sel, true)),
					oobRaw(headerTitle({ title: `Unidade ${sel.unit}`, areaLabel: label })),
				],
				{ ctx: { area: chosen } },
			);
		}),
	},

	// Área picked by the user: reset the unit list and the content region.
	"/ui/area": {
		async GET(req) {
			const sel = selection(new URL(req.url));
			const adapter = adapterOf(sel.uf);
			const label = await areaLabelOf(adapter, sel.area);
			const unitName = `Unidade ${sel.unit}`;
			return respond(
				[
					unitLoading(sel, true),
					oobRaw(headerTitle({ title: unitName, areaLabel: label })),
					oobRaw(headerMeta({ sel, mode: "loading" })),
					oobInner("#content", contentLoading({ unitName, refreshSeconds: REFRESH })),
				],
				{ ctx: { area: sel.area }, push: pageUrl(sel) },
			);
		},
	},

	// Unit list loaded: swaps the placeholder, then starts the course load.
	"/ui/units": {
		GET: l1(async (req) => {
			const picked = selection(new URL(req.url));
			const adapter = adapterOf(picked.uf);
			let units = [];
			try {
				const [all, catalogIds] = await Promise.all([
					adapter.getUnits(),
					adapter.getCatalogUnitIds(picked.area),
				]);
				const catalog = new Set(catalogIds);
				units = all.filter((u) => catalog.has(u.id));
			} catch {}
			// Keep the current unit when this list has it, else the first one.
			const unit = units.some((u) => u.id === picked.unit)
				? picked.unit
				: (units[0]?.id ?? picked.unit);
			const sel = { ...picked, unit };
			const label = await areaLabelOf(adapter, sel.area);
			const info = await unitOf(adapter, unit);
			return respond([
				unitSearch({
					units,
					selectedId: unit,
					uf: sel.uf,
					area: sel.area,
					areaLabel: label,
					loaderUrl: contentUrl(sel),
				}),
				oobRaw(headerTitle({ title: info.name, areaLabel: label })),
				footerOob(stateOf(sel.uf), info),
			]);
		}),
	},

	// Unit picked by the user: show skeletons immediately, then fetch.
	"/ui/loading": {
		async GET(req) {
			const sel = selection(new URL(req.url));
			const adapter = adapterOf(sel.uf);
			const [label, info] = await Promise.all([
				areaLabelOf(adapter, sel.area),
				unitOf(adapter, sel.unit),
			]);
			return respond([
				contentLoading({
					unitName: info.name,
					refreshSeconds: REFRESH,
					loaderUrl: contentUrl(sel),
				}),
				oobRaw(headerMeta({ sel, mode: "loading" })),
				oobRaw(headerTitle({ title: info.name, areaLabel: label })),
				footerOob(stateOf(sel.uf), info),
			]);
		},
	},

	// Courses for the current selection: the content region plus header/footer updates.
	"/ui/content": {
		async GET(req) {
			const sel = selection(new URL(req.url));
			const adapter = adapterOf(sel.uf);
			const state = stateOf(sel.uf);
			const [label, info] = await Promise.all([
				areaLabelOf(adapter, sel.area),
				unitOf(adapter, sel.unit),
			]);
			const common = [
				oobRaw(headerTitle({ title: info.name, areaLabel: label })),
				footerOob(state, info),
			];
			try {
				const [free, paid] = await Promise.all([
					adapter.getUnitData(sel.unit, sel.area),
					adapter.getUnitPaidData(sel.unit, sel.area),
				]);
				return respond(
					[
						contentLoaded({
							free,
							paid,
							sel,
							state,
							unitName: info.name,
							areaLabel: label,
							refreshSeconds: REFRESH,
						}),
						oobRaw(headerMeta({ sel, mode: "idle", updatedAt: free.lastUpdated })),
						...common,
					],
					{ push: pageUrl(sel), cache: "private, max-age=30" },
				);
			} catch (err) {
				return respond(
					[
						errorBanner(err instanceof Error ? err.message : "Falha ao buscar cursos"),
						oobRaw(headerMeta({ sel, mode: "idle" })),
						...common,
					],
					{ push: pageUrl(sel) },
				);
			}
		},
	},
};
