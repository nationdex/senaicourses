// Entry point: one Bun.serve process renders pages, serves htmx fragments, the
// JSON API and static files. Run with `bun src/server/index.js` (see Makefile).
import { config } from "../../config/config.js";
import { apiRoutes } from "./routes/api.js";
import { pageRoutes } from "./routes/pages.js";
import { uiRoutes } from "./routes/ui.js";
import { startBackgroundWork } from "./startup.js";
import { serveStatic } from "./static.js";

const server = Bun.serve({
	port: config.port,
	hostname: config.host,
	// Bun.serve's default idleTimeout is 10s — too short for a cold-cache request
	// that has to build a whole state's catalog from scratch (TO's ~32-área build
	// alone can take well over a minute). Only the FIRST request per (uf, área)
	// after a catalogTtl expiry pays this cost.
	idleTimeout: 180,
	routes: { ...pageRoutes, ...uiRoutes, ...apiRoutes },
	async fetch(req) {
		if (req.method === "GET" || req.method === "HEAD") {
			const file = await serveStatic(req);
			if (file) return file;
		}
		return new Response("Não encontrado", { status: 404 });
	},
	error(err) {
		console.error(err);
		return new Response("Erro interno", { status: 500 });
	},
});

console.log(`🚀 Servidor operando em ${server.url}`);
startBackgroundWork();
