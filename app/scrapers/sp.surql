-- SENAI-SP: server-rendered "cursos livres" listing pages (14 categories, ?pag=N) + the
-- /cursosturmas/ AJAX endpoint for turmas (vagas, datas, horários, preço) per (course, unit).
-- Queue-driven, sequential across áreas (default área first):
--   list(area, page)  -> parses the page, queues turmas tasks (3 course/unit pairs each) and the next list
--   turmas(area, 3 pairs) -> 1 POST (free: bolsa=1,gratuito=1) + 1 POST (paid: bolsa=0,gratuito=0, non-bolsa only) per pair
--   last step -> unit rows (names + officialId from /unidades) + prune.
-- Unit names are read from the unit's OWN list item (the legacy adapter could name a card's 2nd+ units
-- after its 1st unit). `vagas` is the sum of open turmas (EAD sentinel counts >= 9999 are not summed).
DEFINE FUNCTION OVERWRITE fn::scrape::sp::areas() -> array<string> {
	RETURN [
		'tecnologia-da-informacao-e-informatica', 'administracao-e-gestao', 'alimentos-e-bebidas', 'automotiva',
		'construcao-civil-e-design-de-mobiliario', 'design-de-moda-textil-vestuario-calcados-e-joalheria',
		'design-grafico-papel-celulose-grafica-e-editorial', 'fabricacao-mecanica-e-mecanica-industrial',
		'logistica-e-transporte', 'mecatronica-sistemas-de-automacao-energia-e-eletronica',
		'meio-ambiente-saude-e-seguranca-do-trabalho', 'metalurgia-e-soldagem', 'quimica-ceramica-e-plasticos',
		'refrigeracao-e-climatizacao'
	];
};

-- Unit "City - Neighborhood" from the text of one unit's <li>.
DEFINE FUNCTION OVERWRITE fn::scrape::sp::unit_name($li: string) -> string {
	LET $cands = array::filter(array::slice(string::split($li, '<strong>'), 1), |$p|
		string::matches($p, /^[^\d<][^<]*<\/strong>\s*-\s*[^<\n\r(]+/));
	IF array::len($cands) = 0 { RETURN ''; };
	LET $p = $cands[0];
	LET $city = string::trim(fn::scrape::common::decode(fn::scrape::common::before($p, '</strong>')));
	LET $rest = string::replace(fn::scrape::common::after($p, '</strong>'), /^\s*-\s*/, '');
	LET $nb = string::trim(fn::scrape::common::decode(string::replace($rest, /[<\n\r(][\s\S]*$/, '')));
	LET $name = IF string::len($nb) > 0 { $city + ' - ' + $nb } ELSE { $city };
	RETURN IF string::len($name) >= 3 { $name } ELSE { '' };
};

-- All (course, unit) pairs of one listing page.
-- pair = { k: "courseId-unitId", cid, uid, slug, name, hours, bolsa, unit_name }
DEFINE FUNCTION OVERWRITE fn::scrape::sp::parse_list($html: string) -> array<object> {
	LET $cards = array::slice(string::split($html, 'class="card-title"'), 1);
	RETURN array::flatten(array::map($cards, |$c| {
		LET $parts = string::split($c, "openModalTurmas('");
		LET $hdigits = IF string::contains($c, ' horas</strong>') { string::replace(fn::scrape::common::before($c, ' horas</strong>'), /^[\s\S]*<strong>/, '') } ELSE { '' };
		LET $hours = IF string::matches($hdigits, /^\d+$/) { <int> $hdigits } ELSE { 0 };
		RETURN array::filter(array::map(<array> 1..array::len($parts), |$j| {
			LET $call = $parts[$j];
			LET $prev = $parts[$j - 1];
			LET $afterName = fn::scrape::common::after($call, "',");
			LET $nums = string::split(fn::scrape::common::after($afterName, "',"), ',');
			LET $name = fn::scrape::common::decode(fn::scrape::common::before($call, "'"));
			LET $segs = string::split($prev, '<li class="list-group-item">');
			LET $modal = string::trim(fn::scrape::common::decode(fn::scrape::common::between($nums[2] ?? '', "'", "'")));
			RETURN {
				ok: string::matches($call, /^[^']+',\s*'[^']+',\s*\d+,\s*\d+,/),
				cid: fn::scrape::common::to_int($nums[0], 0), uid: fn::scrape::common::to_int($nums[1], 0),
				slug: fn::scrape::common::between($afterName, "'", "'"), name: $name, hours: $hours,
				bolsa: string::matches($name, /(?i)bolsa/),
				unit_name: IF array::len($segs) > 1 AND string::len(fn::scrape::sp::unit_name($segs[array::len($segs) - 1])) > 0 { fn::scrape::sp::unit_name($segs[array::len($segs) - 1]) }
					ELSE IF $modal != 'Presencial' AND string::len($modal) > 0 { $modal } ELSE { '' }
			};
		}), |$e| $e.ok AND $e.cid > 0 AND $e.uid > 0);
	}));
};

-- Sums "Vagas: N" (skipping the >= 9999 EAD sentinel), counts turmas, collects datas/horários/preços.
DEFINE FUNCTION OVERWRITE fn::scrape::sp::parse_turmas($html: string) -> object {
	LET $vagas_raw = array::filter(array::map(array::slice(string::split($html, 'Vagas:'), 1),
		|$p| string::replace(string::replace($p, /^\s*(?:<\/span>\s*)?/, ''), /\D[\s\S]*$/, '')), |$d| string::len($d) > 0 AND string::len($d) < 9);
	LET $nums = array::map($vagas_raw, |$d| <int> $d);
	LET $dates = array::map(array::filter(array::map(array::slice(string::split($html, 'Início'), 1), |$p| string::slice($p, 0, 90)),
		|$p| string::matches($p, /^\s*<br\s*\/?>\s*<strong>\s*\d{2}\/\d{2}\/\d{4}\s*<\/strong>/)),
		|$p| fn::scrape::common::first_date(string::replace(string::replace($p, /<[^>]+>/, ' '), /\s+/, ' ')));
	LET $dsorted = array::sort(array::distinct(array::map($dates, |$d| string::concat(string::slice($d, 6, 10), '/', string::slice($d, 3, 5), '/', string::slice($d, 0, 2)))));
	LET $sched = array::distinct(array::filter(array::map(array::slice(string::split($html, 'Horário</strong>'), 1), |$p| {
		LET $t = string::replace($p, /^(?:<\/div>\s*)+/, '');
		LET $parts = string::split($t, '</div>');
		RETURN {
			ok: string::starts_with($t, '<div'),
			periodo: string::trim(fn::scrape::common::decode(string::replace($parts[0] ?? '', /^[\s\S]*>/, ''))),
			horario: string::trim(fn::scrape::common::decode(string::replace($parts[1] ?? '', /^[\s\S]*>/, '')))
		};
	}), |$s| $s.ok AND string::len($s.periodo) > 0 AND string::len($s.horario) > 0));
	LET $prices = array::map(array::sort(array::distinct(array::filter(array::map(array::slice(string::split($html, 'Investimento'), 1), |$p| {
		LET $w = string::slice($p, 0, 170);
		LET $strongs = array::map(array::slice(string::split($w, '<strong>'), 1), |$s| string::trim(string::replace(fn::scrape::common::before($s, '</strong>'), /\s+/, ' ')));
		LET $hit = array::filter($strongs, |$s| string::matches($s, /^R\$\s*[\d.,]+$/))[0];
		RETURN IF $hit = NONE { [] } ELSE {
			[fn::scrape::common::to_float(string::replace(string::replace($hit, /[^\d,]/, ''), ',', '.'), 0), $hit]
		};
	}), |$x| array::len($x) = 2))), |$x| $x[1]);
	RETURN {
		vagas: math::sum(array::filter($nums, |$v| $v < 9999)),
		turmas: array::len($nums),
		start_dates: array::map($dsorted, |$d| string::concat(string::slice($d, 8, 10), '/', string::slice($d, 5, 7), '/', string::slice($d, 0, 4))),
		schedules: array::map($sched, |$s| { periodo: $s.periodo, horario: $s.horario }),
		prices: $prices
	};
};

DEFINE FUNCTION OVERWRITE fn::scrape::sp::post_turmas($slug: string, $cid: int, $uid: int, $free: bool) -> string {
	LET $b = IF $free { '1' } ELSE { '0' };
	LET $r = http::post('https://www.sp.senai.br/cursosturmas/',
		string::concat('nomeCurso=', $slug, '&cursoId=', <string> $cid, '&escolaId=', <string> $uid, '&estrategia=Presencial&bolsa=', $b, '&gratuito=', $b, '&turno=0&pos=0'),
		{ 'User-Agent': 'Mozilla/5.0', 'X-Requested-With': 'XMLHttpRequest', 'Content-Type': 'application/x-www-form-urlencoded' });
	RETURN <string> $r;
};

DEFINE FUNCTION OVERWRITE fn::scrape::sp::norm($s: string) -> string {
	RETURN fn::scrape::common::squish(string::replace(string::replace(string::slug($s), '-', ' '), /\bsenai\b/, ''));
};

-- Official unit ids from /unidades: [{ id, norm }].
DEFINE FUNCTION OVERWRITE fn::scrape::sp::officials() -> array<object> {
	LET $html = <string> fn::scrape::common::get('https://www.sp.senai.br/unidades');
	LET $segs = string::split($html, '@sp.senai.br');
	LET $n = array::len($segs) - 1;
	RETURN array::filter(array::map(<array> 0..$n, |$i| {
		LET $s = $segs[$i];
		LET $tail = string::slice($s, string::len($s) - 30);
		LET $id = fn::scrape::common::to_int(string::replace($tail, /^[\s\S]*[^0-9]/, ''), 0);
		LET $isSec = string::matches($tail, /(?i)secretaria\d+$/);
		LET $win = string::slice($s, string::len($s) - 4000);
		LET $hs = array::filter(string::split($win, '</h'), |$p| string::matches($p, /<h[1-4][^>]*>\s*[^<]{3,100}?\s*$/));
		LET $nxt = string::slice($segs[$i + 1] ?? '', 0, 1000);
		LET $hn = array::filter(string::split($nxt, '</h'), |$p| string::matches($p, /<h[1-4][^>]*>\s*[^<]{3,100}?\s*$/));
		LET $raw = IF array::len($hs) > 0 { $hs[array::len($hs) - 1] } ELSE IF array::len($hn) > 0 { $hn[0] } ELSE { '' };
		RETURN { id: $id, ok: $isSec AND $id > 0, norm: fn::scrape::sp::norm(fn::scrape::common::decode(string::replace($raw, /^[\s\S]*>/, ''))) };
	}), |$o| $o.ok AND string::len($o.norm) > 0);
};

-- Final step: unit rows from every staged unit name + official ids, then prune.
DEFINE FUNCTION OVERWRITE fn::scrape::sp::finish() -> object {
	LET $all = fn::scrape::common::stage_all('sp_units');
	LET $staged = fn::scrape::common::uniq_by(array::concat(array::filter($all, |$u| string::len($u.name) > 0), $all), 'unit_id');
	LET $off = fn::scrape::sp::officials();
	LET $units0 = array::map($staged, |$u| {
		LET $name = IF string::len($u.name) > 0 { $u.name } ELSE { 'Unidade ' + <string> $u.unit_id };
		LET $nm = fn::scrape::sp::norm($name);
		LET $hits = array::filter($off, |$o| $o.norm = $nm OR string::starts_with($nm, $o.norm + ' '));
		LET $best = array::sort(array::map($hits, |$o| [string::len($o.norm), $o.id]));
		RETURN { unit_id: $u.unit_id, name: $name, official_id: IF array::len($best) > 0 { $best[array::len($best) - 1][1] } ELSE { NONE } };
	});
	LET $units = array::map($units0, |$u| {
		LET $dup = array::len(array::filter($units0, |$o| $o.name = $u.name)) > 1;
		RETURN { unit_id: $u.unit_id, official_id: $u.official_id, name: IF $dup { string::concat($u.name, ' · #', <string> ($u.official_id ?? $u.unit_id)) } ELSE { $u.name } };
	});
	IF array::len($units) > 0 { fn::db::upsert_units('sp', $units); };
	LET $f = fn::scrape::common::finalize('sp');
	RETURN { next: NONE, done: true, note: <string> array::len($units) + ' units; ' + $f.note };
};

DEFINE FUNCTION OVERWRITE fn::scrape::sp::step($n: int) -> object {
	LET $base = 'https://www.sp.senai.br/cursos/cursos-livres/';
	LET $areas = fn::scrape::sp::areas();
	IF $n = 0 {
		fn::scrape::common::stage_clear('sp_pairs');
		fn::scrape::common::stage_clear('sp_units');
		fn::scrape::common::queue_set('sp', [{ t: 'list', a: 0, p: 1 }]);
		fn::scrape::common::cycle_start('sp');
		RETURN fn::scrape::common::advance(0, 'queue started');
	};
	LET $task = fn::scrape::common::queue_get('sp', $n - 1);
	IF $task = NONE { RETURN fn::scrape::sp::finish(); };
	IF $task.t = 'skipped' { RETURN fn::scrape::common::advance($n, 'task skipped'); };
	IF $task.t = 'list' {
		LET $html = <string> fn::scrape::common::get(string::concat($base, $areas[$task.a], '?pag=', <string> $task.p));
		LET $title = array::last(string::split(fn::scrape::common::decode(fn::scrape::common::between($html, '<title>', '</title>')), ' - '));
		LET $label = IF $task.p = 1 { string::trim($title) } ELSE { $task.l };
		LET $slug = IF $task.p = 1 { IF $task.a = 0 { 'tecnologia-da-informacao' } ELSE { fn::scrape::common::slugify($label) } } ELSE { $task.s };
		IF $task.p = 1 AND string::len($label) > 0 { fn::db::upsert_areas('sp', [{ slug: $slug, label: $label }]); };
		LET $pairs = fn::scrape::sp::parse_list($html);
		LET $known = array::flatten(array::map((SELECT VALUE entries FROM scrape_stage WHERE uf = 'sp_pairs' AND string::starts_with(key, $slug + '|') AND key != string::concat($slug, '|', <string> $task.p)), |$e| $e));
		LET $knownk = array::map($known, |$x| $x.k);
		LET $new = fn::scrape::common::uniq_by(array::filter(array::map($pairs, |$p| { k: string::concat(<string> $p.cid, '-', <string> $p.uid), cid: $p.cid, uid: $p.uid, slug: $p.slug, name: $p.name, hours: $p.hours, bolsa: $p.bolsa, unit_name: $p.unit_name }), |$p| !($p.k IN $knownk)), 'k');
		fn::scrape::common::stage_put('sp_pairs', string::concat($slug, '|', <string> $task.p), array::map($new, |$p| { k: $p.k }));
		fn::scrape::common::stage_put('sp_units', string::concat($slug, '|', <string> $task.p), array::filter(array::map($new, |$p| { unit_id: $p.uid, name: $p.unit_name }), |$u| string::len($u.name) > 0));
		LET $chunks = array::map(<array> 0..math::floor((array::len($new) + 2) / 3), |$k| {
			t: 'turmas', s: $slug, pairs: array::slice($new, $k * 3, $k * 3 + 3) });
		LET $nxt = IF array::len($pairs) > 0 AND $task.p < 25 { [{ t: 'list', a: $task.a, p: $task.p + 1, s: $slug, l: $label }] }
			ELSE IF $task.a + 1 < array::len($areas) { [{ t: 'list', a: $task.a + 1, p: 1 }] } ELSE { [] };
		fn::scrape::common::queue_push_all('sp', array::concat($chunks, $nxt));
		RETURN fn::scrape::common::advance($n, $slug + ' p' + <string> $task.p + ': ' + <string> array::len($new) + ' new pairs');
	};
	-- turmas task
	FOR $p IN $task.pairs {
		LET $free = fn::scrape::sp::parse_turmas(fn::scrape::sp::post_turmas($p.slug, $p.cid, $p.uid, true));
		fn::db::upsert_courses('sp', $task.s, $p.uid, false, [{
			course_id: $p.cid, name: $p.name, slug: $p.slug, hours: $p.hours, vagas: $free.vagas, turmas: $free.turmas,
			start_dates: $free.start_dates, schedules: $free.schedules, prices: [], is_bolsa: $p.bolsa }]);
		IF !$p.bolsa {
			LET $paid = fn::scrape::sp::parse_turmas(fn::scrape::sp::post_turmas($p.slug, $p.cid, $p.uid, false));
			IF array::len($paid.prices) > 0 {
				fn::db::upsert_courses('sp', $task.s, $p.uid, true, [{
					course_id: $p.cid, name: $p.name, slug: $p.slug, hours: $p.hours, vagas: $paid.vagas, turmas: $paid.turmas,
					start_dates: $paid.start_dates, schedules: $paid.schedules, prices: $paid.prices, is_bolsa: false }]);
			};
		};
	};
	RETURN fn::scrape::common::advance($n, $task.s + ': ' + <string> array::len($task.pairs) + ' pairs');
};
