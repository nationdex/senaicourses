-- SENAI-AL: WordPress + admin-ajax (action senai_filter_courses, load-more, 10 cards per offset).
-- Step 0 reads the public nonce from /cursos/; steps 1..30 = one offset page each (staged);
-- step 100 = write + prune. Each <article> carries data-title/-commercial_area/-unit/-shift/-price.
DEFINE FUNCTION OVERWRITE fn::scrape::al::cards($html: string) -> array<object> {
	LET $blocks = array::slice(array::reverse(array::slice(array::reverse(string::split($html, '</article>')), 1)), 0);
	RETURN array::filter(array::map($blocks, |$b| {
		LET $rest = fn::scrape::common::after(fn::scrape::common::after($b, 'data-modality="'), '"');
		RETURN {
			ok: string::contains($b, '<article') AND string::contains($b, 'data-commercial_area="') AND string::contains($b, 'data-modality="'),
			title: fn::scrape::common::decode(fn::scrape::common::between($b, 'data-title="', '"')),
			area: fn::scrape::common::decode(fn::scrape::common::between($b, 'data-commercial_area="', '"')),
			unit: fn::scrape::common::decode(fn::scrape::common::between($b, 'data-unit="', '"')),
			shift: fn::scrape::common::decode(fn::scrape::common::between($b, 'data-shift="', '"')),
			price: fn::scrape::common::to_float(fn::scrape::common::between($b, 'data-price="', '"'), 0),
			id: fn::scrape::common::between($rest, 'id="', '"'),
			url: IF string::contains($b, 'itemprop="url" content="') { fn::scrape::common::between($b, 'itemprop="url" content="', '"') } ELSE { 'https://al.senai.br/cursos/' }
		};
	}), |$c| $c.ok AND string::len($c.id) > 0);
};

DEFINE FUNCTION OVERWRITE fn::scrape::al::step($n: int) -> object {
	LET $base = 'https://al.senai.br';
	IF $n = 0 {
		LET $html = fn::scrape::common::get($base + '/cursos/');
		LET $cfg = fn::scrape::common::between(<string> $html, 'senaiCourseFiltersConfig', ';');
		LET $nonce = fn::scrape::common::between($cfg, '"nonce":"', '"');
		IF string::len($nonce) = 0 { THROW 'al: nonce not found'; };
		fn::scrape::common::queue_set('al_nonce', [{ nonce: $nonce }]);
		fn::scrape::common::stage_clear('al');
		fn::scrape::common::cycle_start('al');
		RETURN { next: 1, done: false, note: 'nonce ok' };
	};
	IF $n >= 100 {
		LET $all = fn::scrape::common::uniq_by(fn::scrape::common::stage_all('al'), 'cid');
		IF array::len($all) = 0 { THROW 'al: nothing staged'; };
		fn::scrape::common::write_entries('al', $all);
		LET $f = fn::scrape::common::finalize('al');
		RETURN { next: NONE, done: true, note: <string> array::len($all) + ' courses; ' + $f.note };
	};
	LET $nonce = fn::scrape::common::queue_get('al_nonce', 0).nonce;
	LET $r = fn::scrape::common::post_form($base + '/wp-admin/admin-ajax.php',
		string::concat('action=senai_filter_courses&nonce=', $nonce, '&offset=', <string> (($n - 1) * 10), '&intent=load-more'));
	IF type::of($r) != 'object' { THROW 'al: unexpected ajax response (nonce expired? re-run from step 0)'; };
	LET $html = $r.data.html ?? '';
	IF string::len($html) = 0 { RETURN { next: 100, done: false, note: 'end of list at offset ' + <string> (($n - 1) * 10) }; };
	LET $cards = fn::scrape::al::cards($html);
	LET $prev = array::map(fn::scrape::common::stage_all('al'), |$e| $e.cid);
	LET $new = array::filter($cards, |$c| !($c.id IN $prev));
	LET $entries = array::map(array::filter($new, |$c| string::len($c.area) > 0 AND string::len($c.unit) > 0), |$c| {
		cid: $c.id,
		unit_id: fn::scrape::common::fnv_id($c.unit), unit_name: $c.unit,
		area: fn::scrape::common::slugify($c.area), area_label: $c.area, is_paid: $c.price > 0,
		course: {
			course_id: fn::scrape::common::to_int(string::replace($c.id, /\D/, ''), 0), name: $c.title, slug: 'al-' + $c.id,
			hours: 0, vagas: NULL, turmas: 1, start_dates: [],
			schedules: IF string::len($c.shift) > 0 { [{ periodo: $c.shift, horario: '' }] } ELSE { [] },
			prices: IF $c.price > 0 { [fn::scrape::common::brl($c.price)] } ELSE { [] },
			is_bolsa: false, url: $c.url
		}
	});
	fn::scrape::common::stage_put('al', <string> $n, $entries);
	LET $nxt = IF array::len($new) = 0 OR $n >= 30 { 100 } ELSE { $n + 1 };
	RETURN { next: $nxt, done: false, note: 'offset ' + <string> (($n - 1) * 10) + ': ' + <string> array::len($cards) + ' cards, ' + <string> array::len($new) + ' new' };
};
