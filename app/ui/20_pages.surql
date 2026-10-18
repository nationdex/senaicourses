-- Page-level composition: the #app region (also the htmx fragment) and full pages.

-- The swappable region: filters + title + stats + course lists, or a state notice.
DEFINE FUNCTION OVERWRITE fn::ui::main_body($q: object) -> string {
	LET $s = fn::ui::sel($q);
	LET $uf = $s.uf;
	LET $coming = $s.state.status = 'coming-soon';
	LET $area_label = ((SELECT label FROM $s.areas WHERE slug = $s.area)[0].label) ?? 'Tecnologia da Informação';
	LET $unit_row = (SELECT name, official_id, unit_id FROM $s.units WHERE unit_id = $s.unit)[0];
	LET $unit_name = $unit_row.name ?? '';
	LET $refresh = fn::ui::url('/main', $uf, $s.area, $s.unit);
	LET $free = SELECT * FROM course WHERE uf = $uf AND area = $s.area AND unit_id = $s.unit AND is_paid = false ORDER BY vagas DESC, name;
	LET $paid = SELECT * FROM course WHERE uf = $uf AND area = $s.area AND unit_id = $s.unit AND is_paid = true ORDER BY vagas DESC, name;
	LET $iso = (SELECT VALUE scraped_at FROM course WHERE uf = $uf AND area = $s.area AND unit_id = $s.unit ORDER BY scraped_at DESC LIMIT 1)[0];
	LET $title = IF $coming { $s.state.name } ELSE IF string::len($unit_name) > 0 { $unit_name } ELSE { $s.state.name };
	LET $eyebrow = IF $coming { 'Estado' } ELSE { 'Cursos · ' + fn::ui::esc($area_label) };
	LET $unit_foot = IF $coming OR string::len($unit_name) = 0 { '' } ELSE { ' · Unidade ' + $unit_name + ' (ID ' + <string> ($unit_row.official_id ?? $unit_row.unit_id) + ')' };
	LET $actions = IF $coming OR string::len($unit_name) = 0 { '' } ELSE {
		'<div ' + fn::ui::c('actions') + '><p ' + fn::ui::c('updated') + '>' + fn::ui::ico('clock') + (IF $iso = NONE { 'Sem dados ainda' } ELSE { 'Atualizado às ' + fn::ui::updated($iso) }) + '</p>'
		+ '<button type="button" ' + fn::ui::c('btn') + ' hx-get="' + fn::ui::esc($refresh) + '" hx-target="#app" hx-swap="outerHTML" hx-indicator="#app">' + fn::ui::ico('refresh') + '<span>Atualizar</span></button></div>'
	};
	LET $results = IF $coming {
		fn::ui::notice('clock', 'Em breve', 'Ainda estamos verificando como o SENAI de <strong>' + fn::ui::esc($s.state.name) + '</strong> publica vagas de cursos. Assim que houver uma fonte de dados confiável, este estado passa a mostrar cursos reais.')
	} ELSE IF !$s.has_data AND array::len($s.units) = 0 {
		fn::ui::notice('inbox', 'Coletando dados', 'Os cursos de <strong>' + fn::ui::esc($s.state.name) + '</strong> ainda estão sendo coletados em segundo plano. Volte em alguns minutos.')
	} ELSE IF array::len($free) = 0 AND array::len($paid) = 0 {
		fn::ui::notice('alert', 'Nenhum curso encontrado', 'A unidade <strong>' + fn::ui::esc($unit_name) + '</strong> não possui cursos presenciais de ' + fn::ui::esc($area_label) + ' cadastrados no SENAI ' + fn::ui::esc($s.state.name) + ' no momento.')
	} ELSE {
		fn::ui::stats($free, $iso)
		+ IF array::len($free) > 0 { fn::ui::course_section('Cursos gratuitos', '01', $free, false) } ELSE { '' }
		+ IF array::len($paid) > 0 { fn::ui::course_section('Cursos pagos', '02', $paid, true) } ELSE { '' }
	};
	RETURN '<main id="app" ' + fn::ui::c('app') + '>'
		+ '<div ' + fn::ui::c('wrap') + '><div ' + fn::ui::c('titlebar') + '><div><p ' + fn::ui::c('micro_red') + '>' + $eyebrow + '</p><h1 ' + fn::ui::c('h1') + '>' + fn::ui::esc($title) + '</h1>'
		+ '<p ' + fn::ui::c('muted') + '>SENAI ' + fn::ui::esc($s.state.name) + IF $coming OR array::len($s.units) = 0 { '' } ELSE { ' · ' + <string> array::len($s.units) + fn::ui::plural(array::len($s.units), ' unidade', ' unidades') + ' com cursos de ' + fn::ui::esc($area_label) } + '</p></div>' + $actions + '</div>'
		+ fn::ui::filters($s)
		+ '<div ' + fn::ui::c('busy') + ' role="status" aria-live="polite">Carregando…</div>'
		+ '<div ' + fn::ui::c('results') + '>' + $results + '</div>'
		+ '</div></main>' + fn::ui::site_footer($s.state.source_label, $unit_foot);
};

DEFINE FUNCTION OVERWRITE fn::ui::home_page($q: object) -> string {
	RETURN fn::ui::document('SENAI — Cursos e vagas', fn::ui::site_header() + fn::ui::main_body($q));
};

DEFINE FUNCTION OVERWRITE fn::ui::privacy_page() -> string {
	LET $mail = '<a ' + fn::ui::c('prose_a') + ' href="mailto:arielaram@protonmail.com">arielaram@protonmail.com</a>';
	LET $h2 = fn::ui::c('prose_h2');
	LET $p = fn::ui::c('prose_p');
	LET $body = '<main id="app" ' + fn::ui::c('app') + '><div class="' + fn::ui::k('wrap') + ' ' + fn::ui::k('prose') + '">'
		+ '<a ' + fn::ui::c('back') + ' href="' + fn::cfg::base() + '/home">' + fn::ui::ico('back') + 'Voltar para o início</a>'
		+ '<p ' + fn::ui::c('micro_red') + '>Documento</p><h1 ' + fn::ui::c('prose_h1') + '>Política de Privacidade</h1><p ' + fn::ui::c('muted') + '>Última atualização: 25 de abril de 2026</p>'
		+ '<section><h2 ' + $h2 + '>1. Sobre este site</h2><p ' + $p + '>Este site é um agregador independente e não oficial de vagas em cursos presenciais do <strong>SENAI</strong>. Os dados exibidos são obtidos publicamente nos sites oficiais do SENAI de cada estado e atualizados automaticamente em segundo plano. O site é operado por <strong>Ariel Aram</strong> (' + $mail + ').</p></section>'
		+ '<section><h2 ' + $h2 + '>2. Dados coletados</h2><p ' + $p + '>Este site <strong>não coleta dados pessoais diretamente</strong>. Não há cadastro, login, formulário ou armazenamento de informações identificáveis dos visitantes em nossos servidores. Os dados exibidos (cursos, vagas, horários) são públicos e provenientes exclusivamente do SENAI.</p></section>'
		+ '<section><h2 ' + $h2 + '>3. Armazenamento local</h2><p ' + $p + '>O site pode utilizar armazenamento local no navegador (como <code ' + fn::ui::c('prose_code') + '>localStorage</code>) apenas para salvar preferências de exibição, como o tema claro ou escuro, de forma anônima e local no seu próprio dispositivo.</p></section>'
		+ '<section><h2 ' + $h2 + '>4. Seus direitos</h2><p ' + $p + '>Nos termos da <strong>LGPD</strong> (Lei Geral de Proteção de Dados — Lei nº 13.709/2018) e do <strong>GDPR</strong> (Regulamento Geral de Proteção de Dados da UE), você tem direito a:</p><ul ' + fn::ui::c('prose_ul') + '>'
		+ '<li>Confirmar a existência de tratamento de dados pessoais</li><li>Acessar seus dados pessoais</li><li>Corrigir dados incompletos, inexatos ou desatualizados</li><li>Solicitar a anonimização, bloqueio ou eliminação de dados</li><li>Revogar o consentimento a qualquer momento</li><li>Opor-se ao tratamento realizado com base em legítimo interesse</li></ul>'
		+ '<p ' + $p + '>Como este site não armazena dados pessoais em seus servidores, não mantemos perfis de usuários ou rastreamento individualizado.</p></section>'
		+ '<section><h2 ' + $h2 + '>5. Links externos e isenção de responsabilidade</h2><p ' + $p + '>Este site contém links para os sites oficiais do SENAI. Não nos responsabilizamos pela disponibilidade, exatidão ou políticas de privacidade de sites externos. As informações sobre cursos são fornecidas "como estão" e podem não refletir alterações em tempo real nos sistemas do SENAI.</p></section>'
		+ '<section><h2 ' + $h2 + '>6. Contato</h2><p ' + $p + '>Para dúvidas sobre esta política de privacidade, entre em contato pelo e-mail: ' + $mail + '.</p></section>'
		+ '</div></main>';
	RETURN fn::ui::document('Política de Privacidade — SENAI Cursos', fn::ui::site_header() + $body + fn::ui::site_footer('sites oficiais do SENAI', ''));
};

-- htmx fragment: <title> (htmx applies it to the document) + #app + out-of-band footer.
DEFINE FUNCTION OVERWRITE fn::ui::main($q: object) -> string {
	LET $s = fn::ui::sel($q);
	LET $unit_name = ((SELECT name FROM $s.units WHERE unit_id = $s.unit)[0].name) ?? '';
	LET $t = IF $s.state.status = 'coming-soon' OR string::len($unit_name) = 0 { $s.state.name } ELSE { $unit_name };
	RETURN '<title>' + fn::ui::esc('SENAI ' + $t + ' — Cursos e vagas') + '</title>' + fn::ui::main_body($q);
};
