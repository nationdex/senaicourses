-- SENAI-CE: Laravel commerce app JSON (senai-ce.org.br): /categories/filterable-attributes/2 gives the
-- "segmento" áreas; /category-products/2?segmento=<id>&page=<n> pages the products (12 per page).
-- Queue: step 0 = áreas; step n = one (área, page) task, written straight away.
DEFINE FUNCTION OVERWRITE fn::scrape::ce::periodo($h: any) -> string {
	IF $h = NONE OR $h = NULL { RETURN ''; };
	LET $hour = fn::scrape::common::to_int(string::split($h, ':')[0], -1);
	IF $hour < 0 { RETURN ''; };
	RETURN IF $hour < 12 { 'Manhã' } ELSE IF $hour < 18 { 'Tarde' } ELSE { 'Noite' };
};

DEFINE FUNCTION OVERWRITE fn::scrape::ce::date($iso: any) -> array<string> {
	IF $iso = NONE OR $iso = NULL { RETURN []; };
	LET $p = string::split($iso, '-');
	IF array::len($p) != 3 OR string::len($p[0]) = 0 OR string::len($p[1]) = 0 OR string::len($p[2]) = 0 { RETURN []; };
	RETURN [$p[2] + '/' + $p[1] + '/' + $p[0]];
};

DEFINE FUNCTION OVERWRITE fn::scrape::ce::step($n: int) -> object {
	LET $base = 'https://www.senai-ce.org.br';
	IF $n = 0 {
		LET $j = fn::scrape::common::get($base + '/categories/filterable-attributes/2');
		LET $seg = array::filter($j.filter_attributes ?? [], |$a| $a.code = 'segmento')[0];
		LET $opts = $seg.options ?? [];
		IF array::len($opts) = 0 { THROW 'ce: no segmento options'; };
		LET $areas = array::map($opts, |$o| { id: $o.id, label: fn::scrape::common::decode($o.label), slug: fn::scrape::common::slugify($o.label) });
		fn::db::upsert_areas('ce', array::map($areas, |$a| { slug: $a.slug, label: $a.label }));
		fn::scrape::common::queue_set('ce_areas', $areas);
		fn::scrape::common::queue_set('ce', array::map(<array> 0..array::len($areas), |$i| { a: $i, p: 1 }));
		fn::scrape::common::cycle_start('ce');
		RETURN fn::scrape::common::advance(0, <string> array::len($areas) + ' areas');
	};
	LET $task = fn::scrape::common::queue_get('ce', $n - 1);
	IF $task = NONE { RETURN fn::scrape::common::finalize('ce'); };
	IF $task.t = 'skipped' { RETURN fn::scrape::common::advance($n, 'task skipped'); };
	LET $area = fn::scrape::common::queue_get('ce_areas', $task.a);
	LET $j = fn::scrape::common::get(string::concat($base, '/category-products/2?segmento=', <string> $area.id, '&page=', <string> $task.p));
	LET $ps = array::filter($j.products ?? [], |$p| fn::scrape::common::to_int($p.attributes.unidade_id, 0) > 0);
	LET $entries = array::map($ps, |$p| {
		LET $price = $p.prices.final_price.price ?? 0;
		LET $per = fn::scrape::ce::periodo($p.attributes.horario_inicio);
		LET $hi = $p.attributes.horario_inicio;
		LET $hf = $p.attributes.horario_fim;
		RETURN {
			unit_id: fn::scrape::common::to_int($p.attributes.unidade_id, 0),
			unit_name: fn::scrape::common::decode(string::replace($p.attributes.unidade_senai ?? '', /(?i)^senai\s+/, '')),
			area: $area.slug, area_label: $area.label, is_paid: $price > 0,
			course: {
				course_id: $p.product_id, name: fn::scrape::common::decode($p.name), slug: $p.slug,
				hours: fn::scrape::common::to_int($p.attributes.carga_horaria, 0), vagas: NULL, turmas: 1,
				start_dates: fn::scrape::ce::date($p.attributes.data_inicio),
				schedules: IF $per != '' { [{ periodo: $per, horario: IF ($hi ?? '') != '' AND ($hf ?? '') != '' { $hi + ' às ' + $hf } ELSE { '' } }] } ELSE { [] },
				prices: IF $price > 0 { [fn::scrape::common::brl($price)] } ELSE { [] },
				is_bolsa: false, url: $base + '/' + $p.slug
			}
		};
	});
	fn::scrape::common::write_entries('ce', $entries);
	LET $raw = array::len($j.products ?? []);
	IF $raw >= 12 AND $task.p < 30 { fn::scrape::common::queue_push('ce', { a: $task.a, p: $task.p + 1 }); };
	RETURN fn::scrape::common::advance($n, $area.slug + ' p' + <string> $task.p + ': ' + <string> $raw + ' products');
};
