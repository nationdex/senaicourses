import { KNOWN_ACTIVE, STATE_META, STATE_ORDER } from "../shared/state-meta.js";
import { alAdapter } from "./al.js";
import { ceAdapter } from "./ce.js";
import { dfAdapter } from "./df.js";
import { esAdapter } from "./es.js";
import { goAdapter } from "./go.js";
import { maAdapter } from "./ma.js";
import { mgAdapter } from "./mg.js";
import { msAdapter } from "./ms.js";
import { mtAdapter } from "./mt.js";
import { paAdapter } from "./pa.js";
import { peAdapter } from "./pe.js";
import { piAdapter } from "./pi.js";
import { prAdapter } from "./pr.js";
import { rnAdapter } from "./rn.js";
import { roAdapter } from "./ro.js";
import { rsAdapter } from "./rs.js";
import { scAdapter } from "./sc.js";
import { spAdapter } from "./sp.js";
import { toAdapter } from "./to.js";

/** uf → adapter, for states with a real, live-verified scraping/API integration.
 * Every other Brazilian SENAI runs on its own domain/CMS (different federação —
 * FIERGS, Sistema FIEP, FIEMG, Firjan…), so there is no shared national scheme to
 * generalize from SP; each additional state needs its own adapter, built the same
 * way SP's, SC's and MA's were: by inspecting that state's real site traffic
 * (see scripts/platform-manifest.json for the platform family each one runs on).
 *
 * This is the actual source of truth for "active vs coming-soon" — keep
 * KNOWN_ACTIVE in ../shared/state-meta.js (the frontend's first-paint hint) in sync
 * with these keys when adding a state. */
const ADAPTERS = {
	sp: spAdapter,
	sc: scAdapter,
	al: alAdapter,
	rs: rsAdapter,
	ma: maAdapter,
	mg: mgAdapter,
	ms: msAdapter,
	go: goAdapter,
	to: toAdapter,
	pi: piAdapter,
	ro: roAdapter,
	ce: ceAdapter,
	mt: mtAdapter,
	df: dfAdapter,
	pr: prAdapter,
	es: esAdapter,
	pa: paAdapter,
	pe: peAdapter,
	rn: rnAdapter,
};
if (process.env.NODE_ENV !== "production") {
	const known = new Set(KNOWN_ACTIVE);
	const real = new Set(Object.keys(ADAPTERS));
	if (known.size !== real.size || [...known].some((uf) => !real.has(uf))) {
		console.warn(
			`[registry] state-meta.js KNOWN_ACTIVE (${[...known]}) is out of sync with ADAPTERS (${[...real]})`,
		);
	}
}
export const STATES = STATE_ORDER.map((uf) => {
	const meta = STATE_META[uf];
	const adapter = ADAPTERS[uf];
	return {
		uf,
		name: meta.name,
		logo: meta.logo,
		flag: meta.flag,
		hue: meta.hue,
		sourceLabel: adapter?.sourceLabel ?? meta.sourceLabel,
		status: adapter ? "active" : "coming-soon",
	};
});
export function getAdapter(uf) {
	return ADAPTERS[uf];
}
export function isKnownState(uf) {
	return uf in STATE_META;
}
