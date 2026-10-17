import { config } from "../../config/config.js";
import { query, startSurreal } from "./surreal.js";

let _connected = false;

// Under concurrent warmup (many units/areas writing at once — at 27-state scale,
// potentially dozens simultaneously), SurrealKV's MVCC layer
// legitimately rejects some writes with "Transaction conflict: Resource busy" —
// the error message itself says the transaction can just be retried. Without
// this, a write lost to a conflict was silently dropped (only logged), so
// persistence could randomly miss units/courses under load with no functional
// symptom to notice by.
async function withWriteRetry(fn, retries = 4) {
	let lastErr;
	for (let attempt = 0; attempt <= retries; attempt++) {
		try {
			return await fn();
		} catch (err) {
			lastErr = err;
			const isConflict =
				err instanceof Error && /resource busy|transaction conflict/i.test(err.message);
			if (!isConflict || attempt === retries) throw err;
			await Bun.sleep(20 * 2 ** attempt + Math.random() * 20);
		}
	}
	throw lastErr;
}

/** @returns {Promise<boolean>} whether persistence is available */
export async function connectDb() {
	try {
		await startSurreal();
		_connected = true;
		console.log(`[db] conectado → ${config.surrealStorage}`);
		await defineSchema();
		return true;
	} catch (err) {
		console.error(`[db] sem persistência (só cache em memória): ${err.message}`);
		return false;
	}
}

// schema.surql holds every table, index and stored query (fn::*) — all
// idempotent (OVERWRITE), so it is safe to run on every boot.
async function defineSchema() {
	try {
		const schema = await Bun.file(new URL("./schema.surql", import.meta.url)).text();
		await query(schema);
	} catch (err) {
		console.error("[db] falha ao aplicar schema.surql:", err);
	}
}

// ── Mapeamento ────────────────────────────────────────────────────────────────

/** @param {import("../shared/types.js").DbCourse} row @returns {import("../shared/types.js").Course} */
function rowToCourse(row) {
	return {
		name: row.name,
		slug: row.slug,
		id: row.course_id,
		hours: row.hours,
		vagas: row.vagas,
		turmas: row.turmas,
		startDates: row.start_dates,
		schedules: row.schedules,
		prices: row.prices,
		isBolsa: row.is_bolsa ?? false,
		url: row.url,
	};
}

// ── Leitura ───────────────────────────────────────────────────────────────────

export async function dbGetCourses(uf, area, unitId, isPaid) {
	if (!_connected) return null;
	try {
		const [rows] = await query("RETURN fn::courses($uf, $area, $unit, $paid)", {
			uf,
			area,
			unit: unitId,
			paid: isPaid,
		});
		if (!rows?.length) return null;
		const lastUpdated = rows.reduce(
			(latest, r) => (r.scraped_at > latest ? r.scraped_at : latest),
			rows[0]?.scraped_at ?? new Date(0).toISOString(),
		);
		return { courses: rows.map(rowToCourse), lastUpdated };
	} catch {
		return null;
	}
}

export async function dbGetScrapedAt(uf, area, unitId, isPaid) {
	if (!_connected) return null;
	try {
		const [rows] = await query("RETURN fn::scraped_at($uf, $area, $unit, $paid)", {
			uf,
			area,
			unit: unitId,
			paid: isPaid,
		});
		const row = rows?.[0];
		return row ? new Date(row.scraped_at).getTime() : null;
	} catch {
		return null;
	}
}

export async function dbGetAllUnits(uf) {
	if (!_connected) return [];
	try {
		const [rows] = await query("RETURN fn::units($uf)", { uf });
		return (rows ?? []).map((r) => ({
			id: r.unit_id,
			name: r.name,
			officialId: r.official_id,
		}));
	} catch {
		return [];
	}
}

// ── Escrita ───────────────────────────────────────────────────────────────────

export async function dbUpsertCourses(uf, area, unitId, courses, isPaid) {
	if (!_connected || courses.length === 0) return;
	const scrapedAt = new Date().toISOString();
	const rows = courses.map((c) => ({
		id: `${uf}_${area}_${c.id}_${unitId}_${isPaid ? "p" : "f"}`,
		uf,
		area,
		unit_id: unitId,
		course_id: c.id,
		name: c.name,
		slug: c.slug,
		hours: c.hours,
		vagas: c.vagas,
		turmas: c.turmas,
		start_dates: c.startDates,
		schedules: c.schedules,
		prices: c.prices,
		is_paid: isPaid,
		is_bolsa: c.isBolsa,
		url: c.url,
		scraped_at: scrapedAt,
	}));
	try {
		await withWriteRetry(() => query("fn::upsert_courses($rows)", { rows }));
	} catch (err) {
		console.error(`[db] upsert cursos ${uf}/unidade ${unitId}:`, err);
	}
}

// Courses that vanish from a source (discontinued, renamed, category removed)
// are never deleted by dbUpsertCourses — it only ever upserts what the latest
// scrape found. Without this, the table grows without bound as courses rotate
// over the lifetime of 27 states' worth of adapters. Anything not touched by a
// scrape in `maxAgeMs` is safe to drop.
export async function dbDeleteStaleCourses(maxAgeMs) {
	if (!_connected) return 0;
	try {
		const cutoff = new Date(Date.now() - maxAgeMs).toISOString();
		const [rows] = await query("RETURN fn::delete_stale_courses($cutoff)", { cutoff });
		return rows?.length ?? 0;
	} catch (err) {
		console.error("[db] falha ao limpar cursos obsoletos:", err);
		return 0;
	}
}

export async function dbUpsertUnit(uf, unit) {
	if (!_connected) return;
	try {
		await withWriteRetry(() =>
			query("fn::upsert_unit($uf, $unit_id, $name, $official_id)", {
				uf,
				unit_id: unit.id,
				name: unit.name,
				official_id: unit.officialId,
			}),
		);
	} catch (err) {
		console.error(`[db] upsert unidade ${uf}/${unit.id}:`, err);
	}
}
