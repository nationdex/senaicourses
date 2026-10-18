-- SENAI-TO: ASP.NET MVC app (cursos.senai-to.com.br). Áreas = <select id="Area_Id"> options;
-- list = POST /Inicio/GetCatalogoCursos (Area, Modalidade=Outros, page), detail = GET /Inicio/Curso?cursoId=.
-- Queue tasks: list(area, page) -> detail(area, up to 4 course ids). Rows are free/paid by the
-- "investimento" text, unit = city part of "_unidade".
DEFINE FUNCTION OVERWRITE fn::scrape::to::field($html: string, $id: string) -> string {
	LET $a = fn::scrape::common::after($html, 'id="' + $id + '"');
	IF string::len($a) = 0 { RETURN ''; };
	RETURN fn::scrape::common::decode(fn::scrape::common::before(fn::scrape::common::after(fn::scrape::common::before($a, '<'), '>'), '<'));
};

DEFINE FUNCTION OVERWRITE fn::scrape::to::step($n: int) -> object {
	LET $base = 'http://cursos.senai-to.com.br';
	IF $n = 0 {
		LET $html = <string> fn::scrape::common::get($base + '/Inicio/CatalogoCursos?modalidade=Outros');
		LET $sel = fn::scrape::common::between($html, 'id="Area_Id"', '</select>');
		LET $opts = array::slice(string::split($sel, '<option value="'), 1);
		LET $areas = array::filter(array::map($opts, |$o| {
			id: fn::scrape::common::before($o, '"'),
			label: fn::scrape::common::decode(fn::scrape::common::between($o, '>', '</option>'))
		}), |$a| string::matches($a.id, /^\d+$/) AND string::len($a.label) > 0);
		IF array::len($areas) = 0 { THROW 'to: no área options'; };
		LET $areas2 = array::map($areas, |$a| { id: $a.id, label: $a.label, slug: fn::scrape::common::slugify($a.label) });
		fn::db::upsert_areas('to', array::map($areas2, |$a| { slug: $a.slug, label: $a.label }));
		fn::scrape::common::queue_set('to_areas', $areas2);
		fn::scrape::common::queue_set('to', array::map(<array> 0..array::len($areas2), |$i| { t: 'list', a: $i, p: 1 }));
		fn::scrape::common::cycle_start('to');
		RETURN fn::scrape::common::advance(0, <string> array::len($areas2) + ' areas');
	};
	LET $task = fn::scrape::common::queue_get('to', $n - 1);
	IF $task = NONE { RETURN fn::scrape::common::finalize('to'); };
	IF $task.t = 'skipped' { RETURN fn::scrape::common::advance($n, 'task skipped'); };
	LET $area = fn::scrape::common::queue_get('to_areas', $task.a);
	IF $task.t = 'list' {
		LET $html = fn::scrape::common::post_form($base + '/Inicio/GetCatalogoCursos',
			string::concat('Area=', $area.id, '&Modalidade=Outros&Filtro=&page=', <string> $task.p));
		LET $ids = array::distinct(array::map(array::slice(string::split(<string> $html, 'cursoId='), 1),
			|$s| string::replace($s, /\D[\s\S]*$/, '')));
		LET $ids2 = array::filter($ids, |$i| string::len($i) > 0);
		LET $chunks = array::map(<array> 0..math::floor((array::len($ids2) + 1) / 2), |$k| { t: 'detail', a: $task.a, ids: array::slice($ids2, $k * 2, $k * 2 + 2) });
		LET $more = IF array::len($ids2) >= 10 AND $task.p < 30 { [{ t: 'list', a: $task.a, p: $task.p + 1 }] } ELSE { [] };
		IF array::len($chunks) + array::len($more) > 0 { fn::scrape::common::queue_push_all('to', array::concat($chunks, $more)); };
		RETURN fn::scrape::common::advance($n, $area.slug + ' p' + <string> $task.p + ': ' + <string> array::len($ids2) + ' courses');
	};
	-- detail task
	LET $entries = array::flatten(array::map($task.ids, |$id| {
		LET $url = string::concat($base, '/Inicio/Curso?cursoId=', $id, '&modalidade=Outros');
		LET $html = <string> fn::scrape::common::get($url);
		LET $unidade = fn::scrape::to::field($html, '_unidade');
		LET $city = string::trim(string::split($unidade, ' - ')[0]);
		RETURN IF string::contains($html, 'Nenhuma turma encontrada') OR string::len($city) = 0 { [] } ELSE {
			LET $title = fn::scrape::common::decode(fn::scrape::common::before(fn::scrape::common::after(fn::scrape::common::after($html, '<h1'), '>'), '</h1>'));
			LET $inv = fn::scrape::to::field($html, '_investimento');
			LET $free = string::matches($inv, /(?i)gratuidade|gratuito/);
			LET $turno = fn::scrape::to::field($html, '_turno');
			LET $date = fn::scrape::common::first_date(fn::scrape::to::field($html, '_periodoTurma'));
			[{
				unit_id: fn::scrape::common::fnv_id($city), unit_name: $city,
				area: $area.slug, area_label: $area.label, is_paid: !$free,
				course: {
					course_id: fn::scrape::common::to_int($id, 0),
					name: IF string::len($title) > 0 { $title } ELSE { 'Curso ' + $id }, slug: 'to-' + $id,
					hours: fn::scrape::common::to_int(fn::scrape::to::field($html, '_cargaHoraria'), 0), vagas: NULL, turmas: 1,
					start_dates: IF $date != NONE { [$date] } ELSE { [] },
					schedules: IF string::len($turno) > 0 { [{ periodo: $turno, horario: '' }] } ELSE { [] },
					prices: IF !$free AND string::contains($inv, 'R$') { [$inv] } ELSE { [] },
					is_bolsa: false, url: $url
				}
			}]
		};
	}));
	IF array::len($entries) > 0 { fn::scrape::common::write_entries('to', $entries); };
	RETURN fn::scrape::common::advance($n, $area.slug + ': ' + <string> array::len($task.ids) + ' details, ' + <string> array::len($entries) + ' with turmas');
};
