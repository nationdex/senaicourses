-- SENAI-MG: JetEngine CCT REST route (fiemg.com.br/senai/wp-json/jet-cct/cursos_tec_senai). The route
-- ignores `page`, so one request with a big per_page returns everything. Only published + open
-- rows of the four known course titles (mapped 1:1 to an área label, like the legacy adapter).
DEFINE FUNCTION OVERWRITE fn::scrape::mg::area($course: string) -> option<string> {
	LET $c = string::lowercase($course);
	RETURN IF $c = 'técnico em segurança do trabalho' { 'Segurança do Trabalho' }
		ELSE IF $c = 'técnico em qualidade' { 'Gestão da Qualidade' }
		ELSE IF $c = 'técnico em eletrotécnica' { 'Eletrotécnica' }
		ELSE IF $c = 'técnico em automação industrial' { 'Eletrônica e Automação' }
		ELSE { NONE };
};

DEFINE FUNCTION OVERWRITE fn::scrape::mg::step($n: int) -> object {
	IF $n != 0 { RETURN { next: NONE, done: true, note: 'single-step scraper' }; };
	LET $base = 'https://fiemg.com.br/senai';
	LET $rows = fn::scrape::common::get($base + '/wp-json/jet-cct/cursos_tec_senai?per_page=500');
	IF type::of($rows) != 'array' OR array::len($rows) = 0 { THROW 'mg: unexpected response'; };
	LET $open = array::filter($rows, |$r| $r.cct_status = 'publish' AND $r.matricula_encerrada = 'aberta'
		AND string::len(string::trim($r.curso ?? '')) > 0 AND string::len(string::trim($r.ofertado_por ?? '')) > 0
		AND fn::scrape::mg::area(string::trim($r.curso)) != NONE);
	LET $entries = array::map($open, |$r| {
		LET $course = string::trim($r.curso);
		LET $label = fn::scrape::mg::area($course);
		LET $unit = fn::scrape::common::decode(string::replace(string::trim($r.ofertado_por), /(?i)^senai\s+/, ''));
		LET $price = fn::scrape::common::to_float(string::replace(IF ($r.valor_da_matricula ?? '') != '' { $r.valor_da_matricula } ELSE { $r.mensalidade ?? '0' }, ',', '.'), 0);
		RETURN {
			unit_id: fn::scrape::common::fnv_id($unit), unit_name: $unit,
			area: fn::scrape::common::slugify($label), area_label: $label, is_paid: $price > 0,
			course: {
				course_id: fn::scrape::common::to_int($r._ID, 0), name: string::concat(fn::scrape::common::decode($course), ' — ', fn::scrape::common::decode($r.cidade ?? $unit)),
				slug: 'mg-' + <string> $r._ID, hours: fn::scrape::common::to_int($r.carga_horaria, 0), vagas: NULL, turmas: 1,
				start_dates: [], schedules: IF ($r.turno ?? '') != '' { [{ periodo: $r.turno, horario: '' }] } ELSE { [] },
				prices: IF $price > 0 { [fn::scrape::common::brl($price)] } ELSE { [] },
				is_bolsa: false, url: $r.link ?? ($base + '/cursos-profissionalizantes/')
			}
		};
	});
	IF array::len($entries) = 0 { THROW 'mg: no open offers'; };
	fn::scrape::common::cycle_start('mg');
	fn::scrape::common::write_entries('mg', $entries);
	LET $f = fn::scrape::common::finalize('mg');
	RETURN { next: NONE, done: true, note: <string> array::len($entries) + ' offers; ' + $f.note };
};
