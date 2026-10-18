-- SENAI-RS: WordPress REST (cursos.senairs.org.br/wp-json/wp/v2/cursos), only open turmas
-- (acf.turmasabertas = "S") that carry an acf.segmentoindustrial área; unit = "cidade" taxonomy.
-- Steps: 0 = cities; 1..N = one REST page (50 courses) each, staged; 100 = write + prune.
DEFINE FUNCTION OVERWRITE fn::scrape::rs::step($n: int) -> object {
	LET $rest = 'https://cursos.senairs.org.br/wp-json/wp/v2';
	IF $n = 0 {
		LET $c = fn::scrape::common::get($rest + '/cidade?per_page=100');
		IF type::of($c) != 'array' OR array::len($c) = 0 { THROW 'rs: unexpected city list'; };
		fn::scrape::common::queue_set('rs_cidade', array::map($c, |$x| { id: $x.id, name: fn::scrape::common::decode($x.name) }));
		fn::scrape::common::stage_clear('rs');
		fn::scrape::common::cycle_start('rs');
		RETURN { next: 1, done: false, note: <string> array::len($c) + ' cities' };
	};
	IF $n >= 100 {
		LET $all = fn::scrape::common::stage_all('rs');
		fn::scrape::common::write_entries('rs', $all);
		LET $f = fn::scrape::common::finalize('rs');
		RETURN { next: NONE, done: true, note: <string> array::len($all) + ' offers written; ' + $f.note };
	};
	LET $page = $n;
	LET $b = fn::scrape::common::get(string::concat($rest, '/cursos?per_page=50&page=', <string> $page, '&_fields=id,slug,title,link,cidade,acf'));
	IF type::of($b) != 'array' { THROW 'rs: unexpected courses page ' + <string> $page; };
	LET $cities = (SELECT data.id AS id, data.name AS name FROM scrape_queue WHERE uf = 'rs_cidade');
	LET $open = array::filter($b, |$c| $c.acf.turmasabertas = 'S' AND ($c.acf.segmentoindustrial ?? '') != '' AND $c.cidade[0] != NONE
		AND array::any($cities, |$k| $k.id = $c.cidade[0]));
	LET $entries = array::map($open, |$c| {
		LET $price = fn::scrape::common::to_float($c.acf.valortotal, 0);
		LET $city = array::filter($cities, |$k| $k.id = $c.cidade[0])[0];
		LET $label = fn::scrape::common::decode($c.acf.segmentoindustrial);
		RETURN {
			unit_id: $c.cidade[0], unit_name: $city.name,
			area: fn::scrape::common::slugify($label), area_label: $label, is_paid: $price > 0,
			course: {
				course_id: $c.id, name: fn::scrape::common::decode($c.acf.nomecurso ?? $c.title.rendered), slug: $c.slug,
				hours: fn::scrape::common::to_int($c.acf.cargahoraria, 0), vagas: NULL, turmas: 1,
				start_dates: [], schedules: IF ($c.acf.modalidade ?? '') != '' { [{ periodo: $c.acf.modalidade, horario: '' }] } ELSE { [] },
				prices: IF $price > 0 { [fn::scrape::common::brl($price)] } ELSE { [] },
				is_bolsa: false, url: $c.link
			}
		};
	});
	fn::scrape::common::stage_put('rs', <string> $page, $entries);
	RETURN { next: IF array::len($b) < 50 { 100 } ELSE { $n + 1 }, done: false, note: 'page ' + <string> $page + ': ' + <string> array::len($b) + ' courses, ' + <string> array::len($entries) + ' open' };
};
