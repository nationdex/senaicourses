-- Schema + stored queries for the embedded SurrealDB (SurrealKV engine).
-- Applied on every boot by src/db/index.js; every statement is idempotent
-- (OVERWRITE), so editing this file and restarting is the whole migration.

-- ── course: one row per (uf, área, course, unit, free|paid) ────────────────
DEFINE TABLE OVERWRITE course SCHEMAFULL;
DEFINE FIELD OVERWRITE uf          ON course TYPE string;
DEFINE FIELD OVERWRITE area        ON course TYPE string;
DEFINE FIELD OVERWRITE unit_id     ON course TYPE number;
DEFINE FIELD OVERWRITE course_id   ON course TYPE number;
DEFINE FIELD OVERWRITE name        ON course TYPE string;
DEFINE FIELD OVERWRITE slug        ON course TYPE string;
DEFINE FIELD OVERWRITE hours       ON course TYPE number;
-- null = source has no real seat count (never store a fabricated number).
DEFINE FIELD OVERWRITE vagas       ON course TYPE number | null;
DEFINE FIELD OVERWRITE turmas      ON course TYPE number;
DEFINE FIELD OVERWRITE start_dates ON course TYPE array<string>;
DEFINE FIELD OVERWRITE schedules   ON course TYPE array<object>;
DEFINE FIELD OVERWRITE schedules.*.periodo ON course TYPE string;
DEFINE FIELD OVERWRITE schedules.*.horario ON course TYPE string;
DEFINE FIELD OVERWRITE prices      ON course TYPE array<string>;
DEFINE FIELD OVERWRITE is_paid     ON course TYPE bool;
DEFINE FIELD OVERWRITE is_bolsa    ON course TYPE bool DEFAULT false;
DEFINE FIELD OVERWRITE url         ON course TYPE option<string>;
DEFINE FIELD OVERWRITE scraped_at  ON course TYPE string;

-- Reads filter by (uf, area, unit_id, is_paid) or by scraped_at (stale sweep).
DEFINE INDEX OVERWRITE course_lookup     ON TABLE course FIELDS uf, area, unit_id, is_paid;
DEFINE INDEX OVERWRITE course_scraped_at ON TABLE course FIELDS scraped_at;

-- ── unit: one row per (uf, unit) ───────────────────────────────────────────
DEFINE TABLE OVERWRITE unit SCHEMAFULL;
DEFINE FIELD OVERWRITE uf          ON unit TYPE string;
DEFINE FIELD OVERWRITE unit_id     ON unit TYPE number;
DEFINE FIELD OVERWRITE name        ON unit TYPE string;
DEFINE FIELD OVERWRITE official_id ON unit TYPE option<number>;

DEFINE INDEX OVERWRITE unit_lookup ON TABLE unit FIELDS uf;

-- ── stored queries ─────────────────────────────────────────────────────────

DEFINE FUNCTION OVERWRITE fn::courses($uf: string, $area: string, $unit: number, $paid: bool) {
	RETURN SELECT * FROM course
		WHERE uf = $uf AND area = $area AND unit_id = $unit AND is_paid = $paid
		ORDER BY vagas DESC, name ASC;
};

DEFINE FUNCTION OVERWRITE fn::scraped_at($uf: string, $area: string, $unit: number, $paid: bool) {
	RETURN SELECT scraped_at FROM course
		WHERE uf = $uf AND area = $area AND unit_id = $unit AND is_paid = $paid
		LIMIT 1;
};

DEFINE FUNCTION OVERWRITE fn::units($uf: string) {
	RETURN SELECT unit_id, name, official_id FROM unit WHERE uf = $uf ORDER BY name ASC;
};

-- One statement for the whole batch: atomic per unit, one round-trip.
DEFINE FUNCTION OVERWRITE fn::upsert_courses($rows: array<object>) {
	FOR $row IN $rows {
		UPSERT type::record('course', $row.id) CONTENT $row;
	};
};

DEFINE FUNCTION OVERWRITE fn::upsert_unit($uf: string, $unit_id: number, $name: string, $official_id: option<number>) {
	UPSERT type::record('unit', string::concat($uf, '_', <string> $unit_id)) CONTENT {
		uf: $uf,
		unit_id: $unit_id,
		name: $name,
		official_id: $official_id,
	};
};

-- A course not re-scraped in a long while is gone from its source (every
-- adapter re-upserts its full catalog at least once per catalogTtlMs).
DEFINE FUNCTION OVERWRITE fn::delete_stale_courses($cutoff: string) {
	RETURN DELETE course WHERE scraped_at < $cutoff RETURN BEFORE;
};
