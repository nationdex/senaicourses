-- SENAI-SC: JSON API behind cursos.sesisenai.org.br (paid, presencial professionalizantes only).
-- Queue-driven: step 0 = active área groups; tasks = search(area, page) -> detail(area, 5 products).
DEFINE FUNCTION OVERWRITE fn::scrape::sc::step($n: int) -> object {
	LET $api = 'https://api-ecommerce.sesisenai.org.br/api';
	IF $n = 0 {
		LET $groups = fn::scrape::common::get($api + '/grupo-area-atuacao');
		IF type::of($groups) != 'array' { THROW 'sc: unexpected area list'; };
		LET $active = array::filter($groups, |$g| $g.ativo = true);
		IF array::len($active) = 0 { THROW 'sc: no active areas'; };
		LET $areas = array::map($active, |$g| { id: $g.id_grupo_area_atuacao, label: $g.descricao, slug: fn::scrape::common::slugify($g.descricao) });
		fn::db::upsert_areas('sc', array::map($areas, |$a| { slug: $a.slug, label: $a.label }));
		fn::scrape::common::queue_set('sc_areas', $areas);
		fn::scrape::common::queue_set('sc', array::map(<array> 0..array::len($areas), |$i| { t: 'search', a: $i, p: 1 }));
		fn::scrape::common::cycle_start('sc');
		RETURN fn::scrape::common::advance(0, <string> array::len($areas) + ' areas');
	};
	LET $task = fn::scrape::common::queue_get('sc', $n - 1);
	IF $task = NONE { RETURN fn::scrape::common::finalize('sc'); };
	IF $task.t = 'skipped' { RETURN fn::scrape::common::advance($n, 'task skipped'); };
	LET $area = fn::scrape::common::queue_get('sc_areas', $task.a);
	IF $task.t = 'search' {
		LET $r = fn::scrape::common::get(string::concat($api, '/produto-busca?id_modalidade[]=3&id_tipo_curso[]=2&id_grupo_area_atuacao=', <string> $area.id, '&pagina=', <string> $task.p));
		IF type::of($r) != 'object' { THROW 'sc: unexpected search response'; };
		LET $items = $r.itens ?? [];
		IF array::len($items) = 0 { RETURN fn::scrape::common::advance($n, $area.slug + ' p' + <string> $task.p + ' empty'); };
		LET $ps = array::map($items, |$it| { id: $it.id_produto, price: $it.preco_original });
		LET $chunks = array::map(<array> 0..math::floor((array::len($ps) + 4) / 5), |$k| { t: 'detail', a: $task.a, items: array::slice($ps, $k * 5, $k * 5 + 5) });
		fn::scrape::common::queue_push_all('sc', IF $task.p < 10 { array::push($chunks, { t: 'search', a: $task.a, p: $task.p + 1 }) } ELSE { $chunks });
		RETURN fn::scrape::common::advance($n, $area.slug + ' p' + <string> $task.p + ': ' + <string> array::len($ps) + ' products');
	};
	-- detail task
	FOR $it IN $task.items {
		LET $d = fn::scrape::common::get('https://cursos.sesisenai.org.br/api/produto/detalhes/' + <string> $it.id);
		IF type::of($d) = 'object' AND $d.oferta != NONE AND $d.oferta != NULL {
			-- Several ofertas (turmas) of one product in one unit collapse into one row
			-- (course ids are unique per unit): vagas are summed, turmas counted.
			FOR $uid IN array::distinct(array::map($d.oferta, |$o| $o.id_unidade_execucao)) {
				LET $os = array::filter($d.oferta, |$o| $o.id_unidade_execucao = $uid);
				fn::db::upsert_units('sc', [{ unit_id: $uid, name: fn::scrape::common::decode($os[0].nome) }]);
				fn::db::upsert_courses('sc', $area.slug, $uid, true, [{
					course_id: $d.id_produto, name: $d.titulo, slug: $d.titulo_slug ?? '',
					hours: $os[0].carga_horaria ?? $d.carga_presencial ?? 0,
					vagas: math::sum(array::map($os, |$o| $o.vagas ?? 0)),
					turmas: array::len(array::filter($os, |$o| ($o.vagas ?? 0) > 0)),
					start_dates: [], schedules: [],
					prices: IF $it.price = NONE OR $it.price = NULL { [] } ELSE { [fn::scrape::common::brl($it.price)] },
					is_bolsa: false
				}]);
			};
		};
	};
	RETURN fn::scrape::common::advance($n, $area.slug + ': ' + <string> array::len($task.items) + ' details');
};
