-- SENAI-MA: Vercel micro-app feed (senai-ma-scripts.vercel.app). Catalog page lists the cities;
-- /api/cursos?cidade=<slug> is the full catalog of a city (no category field, so the only área
-- exposed is Tecnologia da Informação, classified by keyword, exactly like the legacy adapter).
-- Steps: 0 = discover cities (queue); 1..N = one city each (paid courses only; no free feed).
DEFINE FUNCTION OVERWRITE fn::scrape::ma::is_it($c: object) -> bool {
	RETURN string::matches(string::concat($c.nome ?? '', ' ', $c.descricao ?? ''),
		/(?i)inform[aá]tic|\bti\b|\bexcel\b|power\s*bi|\bdashboard|desenvolv(imento|edor)\s+(de\s+)?(web|software|sistemas|aplicativos|jogos)|programa[çc][aã]o\s+(de\s+)?(web|software|sistemas)|\bsoftware\b|redes?\s+de\s+computadores?|banco\s+de\s+dados|ci[êe]ncia\s+de\s+dados|intelig[êe]ncia\s+artificial|\bpython\b|\bjava\b|javascript|suporte\s+t[ée]cnico|manuten[çc][ãa]o\s+de\s+(computadores|microcomputadores|micros)\b/);
};

DEFINE FUNCTION OVERWRITE fn::scrape::ma::slug_from_link($link: option<string>, $fallback: string) -> string {
	IF $link = NONE OR $link = NULL OR !string::matches($link, /\/[^\/]+\/p\/?$/) { RETURN $fallback; };
	LET $segs = string::split(string::replace($link, /\/p\/?$/, ''), '/');
	RETURN $segs[array::len($segs) - 1];
};

DEFINE FUNCTION OVERWRITE fn::scrape::ma::step($n: int) -> object {
	LET $host = 'https://senai-ma-scripts.vercel.app';
	IF $n = 0 {
		LET $html = fn::scrape::common::get($host + '/');
		LET $segs = array::slice(string::split(<string> $html, 'data-cidade="'), 1);
		LET $cities = fn::scrape::common::uniq_by(
			array::filter(
				array::map($segs, |$s| {
					slug: string::split($s, '"')[0],
					name: fn::scrape::common::decode(fn::scrape::common::between($s, 'data-nome="', '"'))
				}),
				|$c| string::len($c.slug) > 0 AND string::len($c.name) > 0),
			'slug');
		IF array::len($cities) = 0 { THROW 'ma: no cities found on the catalog page'; };
		fn::db::upsert_areas('ma', [{ slug: 'tecnologia-da-informacao', label: 'Tecnologia da Informação' }]);
		fn::scrape::common::queue_set('ma', $cities);
		RETURN { next: 1, done: false, note: <string> array::len($cities) + ' cities queued' };
	};
	LET $c = fn::scrape::common::queue_get('ma', $n - 1);
	IF $c = NONE { RETURN { next: NONE, done: true, note: 'done' }; };
	LET $raw = http::get($host + '/api/cursos?cidade=' + $c.slug, fn::scrape::common::headers());
	IF type::of($raw) != 'array' { THROW 'ma: unexpected feed for ' + $c.slug; };
	LET $it = array::filter($raw, |$x| fn::scrape::ma::is_it($x));
	LET $uid = fn::scrape::common::fnv_id($c.name);
	LET $since = <string> time::now();
	LET $rows = array::map($it, |$x| {
		LET $date = fn::scrape::common::first_date($x.turma);
		RETURN {
			course_id: fn::scrape::common::to_int($x.id, 0), name: $x.nome,
			slug: fn::scrape::ma::slug_from_link($x.link, 'ma-' + <string> $x.id),
			hours: fn::scrape::common::to_int($x.cargaH, 0), vagas: NULL,
			turmas: IF ($x.turma ?? '') != '' { 1 } ELSE { 0 },
			start_dates: IF $date != NONE { [$date] } ELSE { [] },
			schedules: IF ($x.turno ?? '') != '' { [{ periodo: $x.turno, horario: '' }] } ELSE { [] },
			prices: IF ($x.preco.aVista ?? 0) > 0 { [fn::scrape::common::brl($x.preco.aVista)] } ELSE { [] },
			is_bolsa: false, url: $x.link
		};
	});
	IF array::len($rows) > 0 {
		fn::db::upsert_units('ma', [{ unit_id: $uid, name: $c.name }]);
		fn::db::upsert_courses('ma', 'tecnologia-da-informacao', $uid, true, $rows);
		fn::db::prune_unit('ma', 'tecnologia-da-informacao', $uid, true, $since);
	};
	RETURN { next: $n + 1, done: false, note: $c.slug + ': ' + <string> array::len($raw) + ' courses, ' + <string> array::len($rows) + ' IT' };
};
