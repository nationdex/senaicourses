import { DEFAULT_AREA_LABEL } from "../../shared/constants.js";
import { atmosphere } from "../components/atmosphere.js";
import { comingSoonCard, contentLoading } from "../components/content.js";
import { footer } from "../components/footer.js";
import { header } from "../components/header.js";
import { areaLoading, stateSelector, unitLoading } from "../components/selectors.js";
import { html } from "../html.js";
import { layout, shell } from "../layout.js";

/**
 * First paint. Selectors and content render as placeholders that load
 * themselves in a chain (áreas → unidades → cursos), exactly as the old SPA's
 * effects did — so a cold-cache scrape never blocks the page shell.
 * @param {{ states: import("../../shared/types.js").StateInfo[], state: import("../../shared/types.js").StateInfo,
 *   sel: {uf: string, area: string, unit: number}, refreshSeconds: number }} p
 */
export function homePage({ states, state, sel, refreshSeconds }) {
	const comingSoon = state.status === "coming-soon";
	const unitName = `Unidade ${sel.unit}`;
	const inner = html`
		${header({
			state,
			title: comingSoon ? state.name : unitName,
			areaLabel: DEFAULT_AREA_LABEL,
			sel,
			metaMode: comingSoon ? "none" : "loading",
		})}
		<div id="selectors" class="flex items-center gap-3 flex-wrap section-3d section-3d-2">
			${stateSelector({ states, selectedUf: sel.uf, unit: sel.unit })}
			${comingSoon ? "" : [areaLoading(sel), unitLoading(sel)]}
		</div>
		<div id="content" class="space-y-5">
			${comingSoon ? comingSoonCard({ stateName: state.name }) : contentLoading({ unitName, refreshSeconds })}
		</div>
		${footer({ state, comingSoon, unitName, unitDisplayId: sel.unit })}`;
	return layout({
		hue: state.hue,
		uf: sel.uf,
		area: sel.area,
		body: shell({
			atmosphere: atmosphere(),
			inner,
			rootClass: "min-h-screen w-full p-4 md:p-8",
			column: "relative z-10 max-w-4xl mx-auto space-y-5",
		}),
	});
}
