// JSON API — the same data the pages render, for scripts and for verifying
// adapters by hand (e.g. GET /api/units?uf=sp&area=tecnologia-da-informacao).
import { config } from "../../../config/config.js";
import { STATES } from "../../adapters/registry.js";
import { l1 } from "../l1.js";
import { adapterOf, selection } from "../selection.js";

const json = (data, cacheControl, status = 200) =>
	Response.json(data, { status, headers: cacheControl ? { "Cache-Control": cacheControl } : {} });

const SHORT = "public, max-age=60, stale-while-revalidate=300";

/** Wraps a handler that needs the adapter; maps failures to the JSON errors the API always had. */
function withAdapter(failure, run) {
	return async (req) => {
		const sel = selection(new URL(req.url));
		const adapter = adapterOf(sel.uf);
		if (!adapter) return json({ error: "Estado indisponível" }, null, 404);
		try {
			return await run(adapter, sel);
		} catch {
			return json({ error: failure }, null, 500);
		}
	};
}

export const apiRoutes = {
	"/api/states": {
		GET: l1(() =>
			json(
				STATES.map(({ uf, name, sourceLabel, status }) => ({ uf, name, sourceLabel, status })),
				"public, max-age=3600",
			),
		),
	},

	"/api/units": {
		GET: l1(
			withAdapter("Falha ao buscar unidades", async (adapter, sel) => {
				const [units, catalogUnitIds] = await Promise.all([
					adapter.getUnits(),
					adapter.getCatalogUnitIds(sel.area),
				]);
				const catalog = new Set(catalogUnitIds);
				return json(
					units.filter((u) => catalog.has(u.id)),
					SHORT,
				);
			}),
		),
	},

	"/api/areas": {
		GET: l1(
			withAdapter("Falha ao buscar áreas", async (adapter) =>
				json(await adapter.getAreas(), "public, max-age=300, stale-while-revalidate=600"),
			),
		),
	},

	"/api/config": {
		GET: () =>
			json(
				{
					defaultUnitId: config.defaultUnitId,
					refreshIntervalSeconds: config.refreshIntervalSeconds,
				},
				"public, max-age=3600",
			),
	},

	"/api/courses": {
		GET: l1(
			withAdapter("Falha ao buscar cursos", async (adapter, sel) =>
				json(await adapter.getUnitData(sel.unit, sel.area), SHORT),
			),
		),
	},

	"/api/paid-courses": {
		GET: l1(
			withAdapter("Falha ao buscar cursos pagos", async (adapter, sel) =>
				json(await adapter.getUnitPaidData(sel.unit, sel.area), SHORT),
			),
		),
	},

	"/api/courses/all": {
		GET: l1(
			withAdapter("Falha ao buscar cursos", async (adapter, sel) => {
				const [free, paid] = await Promise.all([
					adapter.getUnitData(sel.unit, sel.area),
					adapter.getUnitPaidData(sel.unit, sel.area),
				]);
				return json({ free, paid }, SHORT);
			}),
		),
	},

	"/api/refresh": {
		POST: withAdapter("Falha ao atualizar cursos", async (adapter, sel) =>
			json(await adapter.getUnitData(sel.unit, sel.area, true)),
		),
	},

	"/api/paid-refresh": {
		POST: withAdapter("Falha ao atualizar cursos pagos", async (adapter, sel) =>
			json(await adapter.getUnitPaidData(sel.unit, sel.area, true)),
		),
	},
};
