import { config } from "../../../config/config.js";
import { STATES } from "../../adapters/registry.js";
import { homePage } from "../../views/pages/home.js";
import { privacyPage } from "../../views/pages/privacy.js";
import { selection, stateOf } from "../selection.js";

const htmlResponse = (markup) =>
	new Response(markup.toString(), {
		headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-cache" },
	});

export const pageRoutes = {
	"/": {
		GET(req) {
			const sel = selection(new URL(req.url));
			return htmlResponse(
				homePage({
					states: STATES,
					state: stateOf(sel.uf),
					sel,
					refreshSeconds: config.refreshIntervalSeconds,
				}),
			);
		},
	},
	"/privacidade": { GET: () => htmlResponse(privacyPage()) },
};
