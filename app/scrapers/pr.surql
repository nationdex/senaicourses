-- SENAI-PR: Liferay Objects headless API (novo.senaipr.org.br/o/c/...). cursos + turmases, joined by
-- codcurso. No usable área taxonomy ("setor" is 76% "Outras"): only Tecnologia da Informação, by
-- keyword on the course name (as the legacy adapter). Single step (2 requests).
DEFINE FUNCTION OVERWRITE fn::scrape::pr::price($inv: any) -> array<string> {
	IF $inv = NONE OR $inv = NULL OR !string::contains(<string> $inv, 'R$') { RETURN []; };
	LET $rem = fn::scrape::common::after(<string> $inv, 'R$');
	LET $ws = string::replace($rem, /[^\s][\s\S]*$/, '');
	LET $num = string::replace(string::replace($rem, /^\s+/, ''), /[^\d.,][\s\S]*$/, '');
	IF string::len($num) = 0 { RETURN []; };
	RETURN ['R$' + $ws + $num];
};

DEFINE FUNCTION OVERWRITE fn::scrape::pr::step($n: int) -> object {
	IF $n != 0 { RETURN { next: NONE, done: true, note: 'single-step scraper' }; };
	LET $base = 'https://novo.senaipr.org.br/o/c';
	LET $cursos = fn::scrape::common::get($base + '/cursos/scopes/8486040?fields=id,codcurso,curso,urldapagina&pageSize=5000&filter=cursoInativo%20eq%20false');
	LET $turmas = fn::scrape::common::get($base + '/turmases/scopes/8486040?fields=id,codcurso,unidade,turno,duracao,iniciodasaulas,investimento&pageSize=5000');
	IF type::of($cursos) != 'object' OR type::of($turmas) != 'object' { THROW 'pr: unexpected response'; };
	LET $it = array::filter($cursos.items ?? [], |$c| string::matches($c.curso ?? '', /(?i)desenvolvimento\s+de\s+sistemas|programador(a)?\s+(de\s+)?(sistemas|web|mobile|aplicativos|full-?stack)|inform[aá]tica|redes?\s+de\s+computadores?|cibersistemas|intelig[êe]ncia\s+artificial|power\s*bi|\bexcel\b|desenvolvedor|programa[çc][aã]o\s+(de\s+)?(web|software|sistemas)/));
	IF array::len($it) = 0 { THROW 'pr: no IT courses in catalog'; };
	LET $entries = array::map(
		array::filter($turmas.items ?? [], |$t| ($t.unidade ?? '') != '' AND array::any($it, |$c| $c.codcurso = $t.codcurso)),
		|$t| {
			LET $c = array::filter($it, |$c| $c.codcurso = $t.codcurso)[0];
			RETURN {
				unit_id: fn::scrape::common::fnv_id(fn::scrape::common::decode($t.unidade)), unit_name: fn::scrape::common::decode($t.unidade),
				area: 'tecnologia-da-informacao', area_label: 'Tecnologia da Informação',
				is_paid: !string::matches($t.investimento ?? '', /(?i)gratuit/),
				course: {
					course_id: $t.id, name: fn::scrape::common::decode($c.curso), slug: string::lowercase($c.codcurso), hours: fn::scrape::common::to_int($t.duracao, 0),
					vagas: NULL, turmas: 1,
					start_dates: IF ($t.iniciodasaulas ?? '') != '' { [$t.iniciodasaulas] } ELSE { [] },
					schedules: IF ($t.turno ?? '') != '' { [{ periodo: $t.turno, horario: '' }] } ELSE { [] },
					prices: fn::scrape::pr::price($t.investimento), is_bolsa: false, url: $c.urldapagina
				}
			};
		});
	IF array::len($entries) = 0 { THROW 'pr: no IT turmas'; };
	fn::scrape::common::cycle_start('pr');
	fn::scrape::common::write_entries('pr', $entries);
	LET $f = fn::scrape::common::finalize('pr');
	RETURN { next: NONE, done: true, note: <string> array::len($entries) + ' IT turmas; ' + $f.note };
};
