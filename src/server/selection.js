import { config } from "../../config/config.js";
import { getAdapter, isKnownState, STATES } from "../adapters/registry.js";
import { DEFAULT_AREA_SLUG } from "../shared/constants.js";

/** Reads the (uf, área, unit) triple every route takes, with the old SPA's defaults. */
export function selection(url) {
	const p = url.searchParams;
	const ufParam = p.get("uf") ?? "sp";
	const unit = Number.parseInt(p.get("unit") ?? "", 10);
	return {
		uf: isKnownState(ufParam) ? ufParam : "sp",
		area: p.get("area") || DEFAULT_AREA_SLUG,
		unit: Number.isFinite(unit) ? unit : config.defaultUnitId,
	};
}

export const stateOf = (uf) => STATES.find((s) => s.uf === uf) ?? STATES[0];

export const adapterOf = (uf) => getAdapter(uf);
