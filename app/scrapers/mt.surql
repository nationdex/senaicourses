-- SENAI-MT: server-rendered PHP catalog (senaimt.ind.br). /para-voce/cursos?page=N lists the course
-- detail URLs; each detail page carries ÁREA, CARGA HORÁRIA and one <li class="turma-card"> per unit.
-- No price anywhere ("* Consulte Valores") and no free/paid signal: everything is stored as paid
-- with an empty prices array (as the legacy adapter). Tasks: list(page) -> detail(url).
DEFINE FUNCTION OVERWRITE fn::scrape::mt::title_case($s: string) -> string {
	LET $small = ['de', 'da', 'do', 'das', 'dos', 'e'];
	LET $w = string::split(string::lowercase($s), ' ');
	RETURN array::join(array::map(<array> 0..array::len($w), |$i| {
		LET $x = $w[$i];
		RETURN IF $i > 0 AND ($x IN $small) { $x } ELSE { string::uppercase(string::slice($x, 0, 1)) + string::slice($x, 1) };
	}), ' ');
};

DEFINE FUNCTION OVERWRITE fn::scrape::mt::periodo($h: string) -> string {
	LET $hour = fn::scrape::common::to_int(string::split($h, ':')[0], -1);
	IF $hour < 0 { RETURN ''; };
	RETURN IF $hour < 12 { 'Manhã' } ELSE IF $hour < 18 { 'Tarde' } ELSE { 'Noite' };
};

DEFINE FUNCTION OVERWRITE fn::scrape::mt::turma($block: string, $url: string, $name: string, $area: string, $hours: int) -> object {
	LET $id = fn::scrape::common::before($block, '"');
	LET $unit_raw = fn::scrape::common::squish(fn::scrape::common::decode(fn::scrape::common::between($block, '<p class="unidade m-0">', '</p>')));
	LET $unit = fn::scrape::mt::title_case(string::trim(string::replace($unit_raw, /(?i)^senai\s+/, '')));
	LET $date = fn::scrape::common::first_date(string::slice(fn::scrape::common::after($block, 'Data de realiza'), 0, 90));
	LET $hrs = array::filter(string::split(string::replace(string::replace(string::slice(fn::scrape::common::after(fn::scrape::common::after($block, 'Hor'), '</b>'), 0, 80), /<[^>]+>/, ' '), /\s+/, ' '), ' '),
		|$t| string::matches($t, /^\d{1,2}:\d{2}$/));
	LET $per = IF array::len($hrs) > 0 { fn::scrape::mt::periodo($hrs[0]) } ELSE { '' };
	RETURN {
		ok: string::len($unit) > 0 AND string::contains(fn::scrape::common::before($block, '>'), 'turma-card'),
		unit_id: fn::scrape::common::fnv_id($unit), unit_name: $unit,
		area: fn::scrape::common::slugify($area), area_label: fn::scrape::mt::title_case($area), is_paid: true,
		course: {
			course_id: fn::scrape::common::fnv_id($id), name: fn::scrape::mt::title_case($name), slug: fn::scrape::common::slugify($name),
			hours: $hours, vagas: NULL, turmas: 1,
			start_dates: IF $date != NONE { [$date] } ELSE { [] },
			schedules: IF $per != '' { [{ periodo: $per, horario: IF array::len($hrs) > 1 { $hrs[0] + ' às ' + $hrs[1] } ELSE { '' } }] } ELSE { [] },
			prices: [], is_bolsa: false, url: $url
		}
	};
};

DEFINE FUNCTION OVERWRITE fn::scrape::mt::step($n: int) -> object {
	LET $base = 'https://senaimt.ind.br';
	IF $n = 0 {
		fn::scrape::common::queue_set('mt', [{ t: 'list', p: 1 }]);
		fn::scrape::common::queue_set('mt_seen', []);
		fn::scrape::common::cycle_start('mt');
		RETURN fn::scrape::common::advance(0, 'queue started');
	};
	LET $task = fn::scrape::common::queue_get('mt', $n - 1);
	IF $task = NONE { RETURN fn::scrape::common::finalize('mt'); };
	IF $task.t = 'skipped' { RETURN fn::scrape::common::advance($n, 'task skipped'); };
	IF $task.t = 'list' {
		LET $html = <string> fn::scrape::common::get(IF $task.p = 1 { $base + '/para-voce/cursos' } ELSE { $base + '/para-voce/cursos?page=' + <string> $task.p });
		LET $urls = array::distinct(array::filter(array::map(array::slice(string::split($html, 'href="'), 1), |$s| fn::scrape::common::before($s, '"')),
			|$u| string::starts_with($u, 'cursos/detalhes/') OR string::starts_with($u, '/cursos/detalhes/')));
		LET $seen = array::map((SELECT VALUE data FROM scrape_queue WHERE uf = 'mt_seen'), |$d| $d.u);
		LET $new = array::filter($urls, |$u| !($u IN $seen));
		IF array::len($new) > 0 {
			fn::scrape::common::queue_push_all('mt_seen', array::map($new, |$u| { u: $u }));
			LET $tasks = array::map($new, |$u| { t: 'detail', u: $base + '/' + string::replace($u, /^\//, '') });
			fn::scrape::common::queue_push_all('mt', IF $task.p < 10 { array::push($tasks, { t: 'list', p: $task.p + 1 }) } ELSE { $tasks });
		};
		RETURN fn::scrape::common::advance($n, 'page ' + <string> $task.p + ': ' + <string> array::len($new) + ' new courses');
	};
	LET $html = <string> fn::scrape::common::get($task.u);
	LET $h3 = array::filter(array::slice(string::split($html, '<h3>'), 1), |$s| string::matches($s, /^\s*<b>\s*[^<]+<\/b>\s*<\/h3>/));
	LET $name = IF array::len($h3) > 0 { fn::scrape::common::decode(fn::scrape::common::between($h3[0], '<b>', '</b>')) } ELSE { '' };
	LET $area = fn::scrape::common::decode(fn::scrape::common::before(fn::scrape::common::after(fn::scrape::common::after($html, 'ÁREA:'), '</strong>'), '</div>'));
	LET $hours = fn::scrape::common::to_int(fn::scrape::common::after(fn::scrape::common::after($html, 'CARGA HOR'), '</strong>'), 0);
	IF string::len($name) = 0 OR string::len($area) = 0 { RETURN fn::scrape::common::advance($n, 'unparsable page ' + $task.u); };
	LET $blocks = array::slice(string::split($html, '<li data-value="'), 1);
	LET $entries = array::filter(array::map($blocks, |$b| fn::scrape::mt::turma(fn::scrape::common::before($b, '</li>'), $task.u, $name, $area, $hours)), |$e| $e.ok);
	IF array::len($entries) > 0 { fn::scrape::common::write_entries('mt', $entries); };
	RETURN fn::scrape::common::advance($n, $name + ': ' + <string> array::len($entries) + ' turmas');
};
