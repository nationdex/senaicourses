-- Write API for scrapers. Every scraper step persists ONLY through these.
-- Row shapes use snake_case (the table's own field names) minus the keys the
-- function fills in itself (uf, area, unit_id, is_paid, scraped_at).

-- rows: [{ slug, label }]
DEFINE FUNCTION OVERWRITE fn::db::upsert_areas($uf: string, $rows: array<object>) {
	FOR $r IN $rows {
		UPSERT type::record('area', string::concat($uf, '_', $r.slug))
			CONTENT { uf: $uf, slug: $r.slug, label: $r.label };
	};
};

-- rows: [{ unit_id, name, official_id? }]
DEFINE FUNCTION OVERWRITE fn::db::upsert_units($uf: string, $rows: array<object>) {
	FOR $r IN $rows {
		UPSERT type::record('unit', string::concat($uf, '_', <string> $r.unit_id))
			CONTENT { uf: $uf, unit_id: $r.unit_id, name: $r.name, official_id: $r.official_id };
	};
};

-- rows: [{ course_id, name, slug, hours, vagas (number|null), turmas,
--          start_dates: [string], schedules: [{periodo, horario}], prices: [string],
--          is_bolsa, url? }]
-- Sets scraped_at to now. Does NOT delete courses missing from `rows`
-- (call fn::db::prune_unit for that, only after a COMPLETE, successful scrape).
DEFINE FUNCTION OVERWRITE fn::db::upsert_courses(
	$uf: string, $area: string, $unit_id: number, $is_paid: bool, $rows: array<object>
) {
	LET $now = <string> time::now();
	FOR $r IN $rows {
		UPSERT type::record('course', string::concat(
			$uf, '_', $area, '_', <string> $r.course_id, '_', <string> $unit_id, '_', IF $is_paid { 'p' } ELSE { 'f' }
		)) CONTENT {
			uf: $uf, area: $area, unit_id: $unit_id, course_id: $r.course_id,
			name: $r.name, slug: $r.slug, hours: $r.hours, vagas: $r.vagas, turmas: $r.turmas,
			start_dates: $r.start_dates, schedules: $r.schedules, prices: $r.prices,
			is_paid: $is_paid, is_bolsa: $r.is_bolsa ?? false, url: $r.url, scraped_at: $now
		};
	};
};

-- Removes rows of one (uf, area, unit, free|paid) scope that were not touched
-- since $since (an ISO string taken BEFORE the scrape started).
DEFINE FUNCTION OVERWRITE fn::db::prune_unit(
	$uf: string, $area: string, $unit_id: number, $is_paid: bool, $since: string
) {
	DELETE course WHERE uf = $uf AND area = $area AND unit_id = $unit_id
		AND is_paid = $is_paid AND scraped_at < $since RETURN NONE;
};

-- Housekeeping: rows not re-scraped for a long time are gone from the source.
DEFINE FUNCTION OVERWRITE fn::db::delete_stale($cutoff: string) {
	DELETE course WHERE scraped_at < $cutoff RETURN NONE;
};
