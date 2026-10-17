// Background work: persistence, cache warm-up, proactive refresh, stale cleanup.
import { config } from "../../config/config.js";
import { withConcurrency } from "../adapters/http.js";
import { getAdapter, STATES } from "../adapters/registry.js";
import { connectDb, dbDeleteStaleCourses, dbGetAllUnits } from "../db/index.js";
import { DEFAULT_AREA_SLUG } from "../shared/constants.js";

const activeAdapters = () =>
	STATES.filter((s) => s.status === "active").flatMap((s) => {
		const adapter = getAdapter(s.uf);
		return adapter ? [{ uf: s.uf, adapter }] : [];
	});

export function startBackgroundWork() {
	connectDb().then((ok) => ok && console.log("[db] pronto"));

	for (const { uf, adapter } of activeAdapters()) {
		adapter
			.getUnits()
			.then(async (units) => {
				if (units.length === 0) {
					const dbUnits = await dbGetAllUnits(uf);
					console.log(`[${uf}] ${dbUnits.length} unidades pré-carregadas do banco`);
				}
			})
			.catch(console.error);

		// Only the default área (T.I.) is pre-warmed at startup — every other real
		// área a state exposes (see getAreas()) is fetched lazily on first request,
		// which keeps startup cost from scaling with a state's full category count.
		adapter
			.getCatalogUnitIds(DEFAULT_AREA_SLUG)
			.then(async (unitIds) => {
				console.log(`[${uf}] verificando ${unitIds.length} unidades…`);
				let done = 0;
				await withConcurrency(
					unitIds.map((uid) => async () => {
						await Promise.all([
							adapter.getUnitData(uid, DEFAULT_AREA_SLUG),
							adapter.getUnitPaidData(uid, DEFAULT_AREA_SLUG),
						]);
						done++;
						if (done % 10 === 0 || done === unitIds.length) {
							console.log(`[${uf}] ${done}/${unitIds.length} unidades carregadas`);
						}
					}),
					config.warmupConcurrency,
				);
				console.log(`[${uf}] todas as unidades carregadas ✓`);
			})
			.catch(console.error);
	}

	// Start the schedulers after the initial warm-up has had time to complete.
	setTimeout(scheduleProactiveRefresh, 60_000);
	setTimeout(scheduleStaleCleanup, 5 * 60_000);
}

// ── Proactive refresh ────────────────────────────────────────────────────────
// Refreshes cached unit data BEFORE the TTL expires so users never wait for a
// scrape. Runs every half-TTL; for each active state, re-fetches all catalog
// units with low concurrency (3) to avoid upstream spikes.

const REFRESH_INTERVAL_MS = Math.max(config.unitTtlMs / 2, 60_000);
const REFRESH_CONCURRENCY = 3;

function scheduleProactiveRefresh() {
	setInterval(async () => {
		for (const { uf, adapter } of activeAdapters()) {
			try {
				const unitIds = await adapter.getCatalogUnitIds(DEFAULT_AREA_SLUG);
				let done = 0;
				await withConcurrency(
					unitIds.map((uid) => async () => {
						await Promise.allSettled([
							adapter.getUnitData(uid, DEFAULT_AREA_SLUG, true),
							adapter.getUnitPaidData(uid, DEFAULT_AREA_SLUG, true),
						]);
						done++;
						if (done % 20 === 0 || done === unitIds.length) {
							console.log(`[${uf}] refresh proativo ${done}/${unitIds.length}`);
						}
					}),
					REFRESH_CONCURRENCY,
				);
				console.log(`[${uf}] refresh proativo concluído ✓`);
			} catch (err) {
				console.error(`[${uf}] erro no refresh proativo:`, err);
			}
		}
	}, REFRESH_INTERVAL_MS);
	console.log(`[scheduler] refresh proativo a cada ${Math.round(REFRESH_INTERVAL_MS / 1000)}s`);
}

// ── Stale-data cleanup ───────────────────────────────────────────────────────
// A course not re-scraped in 7 days is genuinely gone from its source (every
// adapter re-upserts its full catalog at least every catalogTtlMs, 2h default).

const STALE_COURSE_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;
const CLEANUP_INTERVAL_MS = 24 * 60 * 60 * 1000;

function scheduleStaleCleanup() {
	setInterval(async () => {
		const deleted = await dbDeleteStaleCourses(STALE_COURSE_MAX_AGE_MS);
		if (deleted > 0) console.log(`[db] ${deleted} curso(s) obsoleto(s) removido(s)`);
	}, CLEANUP_INTERVAL_MS);
}
