-- Dev data for UI checks (database cursos_ui). NOT auto-loaded by load.sh.
-- Load: app/load.sh cursos_ui app/ui/dev/dev-seed.surql   (after the default load: states come from seed/states.surql)
-- Covers: vagas null, 0 with turmas (Esgotado), 0 without turmas (Sem turmas), bolsa, paid with 1 / many prices,
-- long names, many dates and schedules, a state with a scraped unit but no courses, a state with nothing yet.

DELETE course WHERE uf IN ['sp', 'sc', 'mg'];
DELETE unit WHERE uf IN ['sp', 'sc', 'mg'];
DELETE area WHERE uf IN ['sp', 'sc', 'mg'];

fn::db::upsert_areas('sp', [
	{ slug: 'tecnologia-da-informacao', label: 'Tecnologia da Informação' },
	{ slug: 'automacao', label: 'Automação e Robótica' },
	{ slug: 'metalmecanica', label: 'Metalmecânica' }
]);
fn::db::upsert_areas('sc', [{ slug: 'tecnologia-da-informacao', label: 'Tecnologia da Informação' }]);
fn::db::upsert_areas('mg', [{ slug: 'tecnologia-da-informacao', label: 'Tecnologia da Informação' }]);

fn::db::upsert_units('sp', [
	{ unit_id: 403, name: 'São Paulo - Vila Leopoldina', official_id: 403 },
	{ unit_id: 110, name: 'Campinas - Roberto Mange', official_id: 110 },
	{ unit_id: 120, name: 'Santo André - Conde Francisco Matarazzo', official_id: 120 },
	{ unit_id: 130, name: 'Sorocaba - Antônio Ermírio <b>teste & "aspas"</b>', official_id: 130 },
	{ unit_id: 140, name: 'Jundiaí - Unidade sem cursos ainda', official_id: 140 }
]);
FOR $i IN 201..213 {
	fn::db::upsert_units('sp', [{ unit_id: $i, name: 'Cidade ' + <string> $i + ' - Escola SENAI', official_id: $i }]);
};
fn::db::upsert_units('sc', [{ unit_id: 1, name: 'Florianópolis', official_id: 1 }]);
fn::db::upsert_units('mg', [{ unit_id: 7, name: 'Belo Horizonte - CTTI', official_id: 7 }]);

-- SP / Vila Leopoldina / free: every seat state.
fn::db::upsert_courses('sp', 'tecnologia-da-informacao', 403, false, [
	{ course_id: 1001, name: 'Programador de Sistemas Web', slug: 'programador-de-sistemas-web', hours: 160, vagas: 48, turmas: 3,
	  start_dates: ['03/11/2026', '17/11/2026', '01/12/2026', '15/01/2027', '02/02/2027'],
	  schedules: [{ periodo: 'Manhã', horario: '08h às 12h' }, { periodo: 'Noite', horario: '19h às 22h' }], prices: [], is_bolsa: true },
	{ course_id: 1002, name: 'Técnico em Desenvolvimento de Sistemas com Ênfase em Computação em Nuvem, Inteligência Artificial e Segurança da Informação Aplicada à Indústria 4.0', slug: 'tecnico-dev-sistemas-nuvem-ia', hours: 1200, vagas: 12, turmas: 1,
	  start_dates: ['10/11/2026'], schedules: [{ periodo: 'Tarde', horario: '13h às 17h' }], prices: [], is_bolsa: false },
	{ course_id: 1003, name: 'Lógica de Programação', slug: 'logica-de-programacao', hours: 40, vagas: 1, turmas: 1, start_dates: ['05/11/2026'], schedules: [], prices: [], is_bolsa: false },
	{ course_id: 1004, name: 'Banco de Dados SQL', slug: 'banco-de-dados-sql', hours: 60, vagas: 0, turmas: 2, start_dates: [], schedules: [], prices: [], is_bolsa: false },
	{ course_id: 1005, name: 'Introdução à Robótica Educacional', slug: 'introducao-robotica', hours: 0, vagas: 0, turmas: 0, start_dates: [], schedules: [], prices: [], is_bolsa: false },
	{ course_id: 1006, name: 'Análise de Dados com Python', slug: 'analise-de-dados-python', hours: 80, vagas: NULL, turmas: 0, start_dates: [], schedules: [], prices: [], is_bolsa: false },
	{ course_id: 1007, name: 'Redes de Computadores', slug: 'redes-de-computadores', hours: 120, vagas: 24, turmas: 2, start_dates: ['12/11/2026', '26/11/2026'], schedules: [{ periodo: 'Noite', horario: '19h às 22h30' }], prices: [], is_bolsa: true,
	  url: 'https://www.sp.senai.br/curso/redes-de-computadores/1007' }
]);
-- SP / Vila Leopoldina / paid: one price, price range, no price.
fn::db::upsert_courses('sp', 'tecnologia-da-informacao', 403, true, [
	{ course_id: 2001, name: 'Excel Avançado para Gestão', slug: 'excel-avancado', hours: 30, vagas: 18, turmas: 2, start_dates: ['08/11/2026', '22/11/2026'],
	  schedules: [{ periodo: 'Sábado', horario: '09h às 13h' }], prices: ['R$ 480,00'], is_bolsa: false },
	{ course_id: 2002, name: 'Cibersegurança Aplicada', slug: 'ciberseguranca-aplicada', hours: 120, vagas: 6, turmas: 1, start_dates: ['20/11/2026'],
	  schedules: [], prices: ['R$ 1.890,00', 'R$ 2.100,00', 'R$ 2.350,00'], is_bolsa: false },
	{ course_id: 2003, name: 'Power BI', slug: 'power-bi', hours: 24, vagas: 0, turmas: 1, start_dates: ['30/10/2026'], schedules: [], prices: ['R$ 390,00'], is_bolsa: false },
	{ course_id: 2004, name: 'Computação em Nuvem (preço indisponível)', slug: 'cloud', hours: 40, vagas: NULL, turmas: 0, start_dates: [], schedules: [], prices: [], is_bolsa: false }
]);
-- SP / Campinas: free only. Other área: one course.
fn::db::upsert_courses('sp', 'tecnologia-da-informacao', 110, false, [
	{ course_id: 1101, name: 'Montagem e Manutenção de Computadores', slug: 'montagem-manutencao', hours: 160, vagas: 30, turmas: 2, start_dates: ['04/11/2026'], schedules: [{ periodo: 'Manhã', horario: '08h às 12h' }], prices: [], is_bolsa: false }
]);
fn::db::upsert_courses('sp', 'automacao', 403, false, [
	{ course_id: 1301, name: 'Controlador Lógico Programável', slug: 'clp', hours: 80, vagas: 10, turmas: 1, start_dates: ['09/11/2026'], schedules: [], prices: [], is_bolsa: false }
]);
fn::db::upsert_courses('sp', 'tecnologia-da-informacao', 205, false, [
	{ course_id: 1401, name: 'Informática Básica', slug: 'informatica-basica', hours: 40, vagas: 20, turmas: 1, start_dates: ['11/11/2026'], schedules: [], prices: [], is_bolsa: false }
]);
-- SC: no real link pattern needed (sc URL built from slug/id), values only.
fn::db::upsert_courses('sc', 'tecnologia-da-informacao', 1, false, [
	{ course_id: 501, name: 'Programação Java', slug: 'programacao-java', hours: 100, vagas: 15, turmas: 1, start_dates: ['06/11/2026'], schedules: [], prices: [], is_bolsa: false }
]);
-- MG: no URL pattern known -> course is rendered without a link.
fn::db::upsert_courses('mg', 'tecnologia-da-informacao', 7, false, [
	{ course_id: 701, name: 'Desenvolvimento Web (sem link oficial)', slug: 'dev-web', hours: 90, vagas: 9, turmas: 1, start_dates: ['13/11/2026'], schedules: [], prices: [], is_bolsa: false }
]);
-- Unit whose name contains HTML: must render as literal text everywhere (escaping check).
fn::db::upsert_courses('sp', 'tecnologia-da-informacao', 130, false, [
	{ course_id: 1501, name: 'Curso <script>alert(1)</script> & "aspas"', slug: 'x', hours: 10, vagas: 5, turmas: 1, start_dates: [], schedules: [], prices: [], is_bolsa: false }
]);
