-- SENAI-DF: one legacy PHP page (sistemafibra.org.br/senai/cursos_gratuidade) with every free course as
-- an accordion card + a table of turmas (Escola / Turno / Carga Horária). No área field: only the
-- Tecnologia da Informação área, picked by keyword on the course name (as the legacy adapter).
-- Single step: fetch + parse + write + prune. course_id = site course id * 100 + turma row index.
DEFINE FUNCTION OVERWRITE fn::scrape::df::step($n: int) -> object {
	IF $n != 0 { RETURN { next: NONE, done: true, note: 'single-step scraper' }; };
	LET $url = 'https://sistemafibra.org.br/senai/cursos_gratuidade/indexCursos.php?categoria=PSGR%20%E2%80%93%20Cursos%20Gratuitos&exibeFiltro=no';
	LET $html = fn::scrape::common::get($url);
	IF type::of($html) != 'string' OR !string::contains($html, '<div class="card">') { THROW 'df: catalog page not recognised'; };
	LET $cards = array::slice(string::split($html, '<div class="card">'), 1);
	LET $courses = array::filter(array::map($cards, |$c| {
		id: fn::scrape::common::to_int(fn::scrape::common::between($c, 'data-target="#Curso', '"'), 0),
		name: fn::scrape::common::decode(fn::scrape::common::between($c, '▼</span>', '</button>')),
		rows: array::slice(string::split($c, '<tr class="Desktop">'), 1)
	}), |$c| $c.id > 0 AND string::len($c.name) > 0 AND array::len($c.rows) > 0
		AND string::matches($c.name, /(?i)desenvolved|programador|inform[aá]tic|rede[s]?\s+de\s+computador|reparador\s+de\s+computador|front-?end|back-?end|full-?stack|low-?code|banco\s+de\s+dados|ci[êe]ncia\s+de\s+dados|python|java\b|javascript/));
	LET $entries = array::flatten(array::map($courses, |$c| {
		RETURN array::filter(array::map(<array> 0..array::len($c.rows), |$i| {
			LET $tds = array::slice(string::split($c.rows[$i], '<td>'), 1, 4);
			LET $school = string::trim(string::replace(fn::scrape::common::decode(string::split($tds[0] ?? '', '</td>')[0]), /(?i)^senai\s+/, ''));
			RETURN {
				unit_id: fn::scrape::common::fnv_id($school), unit_name: $school,
				area: 'tecnologia-da-informacao', area_label: 'Tecnologia da Informação', is_paid: false,
				ok: string::len($school) > 0,
				course: {
					course_id: $c.id * 100 + $i, name: $c.name, slug: 'df-' + <string> $c.id,
					hours: fn::scrape::common::to_int(string::split($tds[2] ?? '', '</td>')[0], 0), vagas: NULL, turmas: 1,
					start_dates: [],
					schedules: IF string::len(fn::scrape::common::decode(string::split($tds[1] ?? '', '</td>')[0])) > 0
						{ [{ periodo: fn::scrape::common::decode(string::split($tds[1] ?? '', '</td>')[0]), horario: '' }] } ELSE { [] },
					prices: [], is_bolsa: false, url: $url
				}
			};
		}), |$e| $e.ok);
	}));
	IF array::len($entries) = 0 { THROW 'df: no IT turmas found'; };
	fn::scrape::common::cycle_start('df');
	fn::scrape::common::write_entries('df', $entries);
	LET $f = fn::scrape::common::finalize('df');
	RETURN { next: NONE, done: true, note: <string> array::len($entries) + ' turmas; ' + $f.note };
};
