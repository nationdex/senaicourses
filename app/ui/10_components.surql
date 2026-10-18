-- Reusable UI blocks. Each returns an HTML string; all DB values go through fn::ui::esc.

-- Alpine state shared by the three dropdowns: open/close, Esc, arrow keys, search filter.
DEFINE FUNCTION OVERWRITE fn::ui::dd_data() -> string {
	RETURN '{ open: false, q: \'\', items() { return [...this.$refs.list.querySelectorAll(\'li:not([hidden]) a\')] }, step(d) { const v = this.items(), i = v.indexOf(document.activeElement); (v[i + d] || v[d > 0 ? 0 : v.length - 1])?.focus() }, toggle() { this.open = !this.open; if (this.open) this.$nextTick(() => (this.$refs.q || this.items()[0])?.focus()) }, close() { this.open = false; this.q = \'\'; this.$refs.btn.focus() } }';
};

-- One dropdown entry: { href, fragment, label, flag?, note?, current, search }.
DEFINE FUNCTION OVERWRITE fn::ui::dd_item($i: object) -> string {
	LET $flag = IF $i.flag != NONE { '<img ' + fn::ui::c('flag') + ' src="' + fn::ui::esc($i.flag) + '" alt="" width="20" height="14" loading="lazy">' } ELSE { '' };
	LET $note = IF $i.note != NONE { '<span ' + fn::ui::c('tag') + '>' + fn::ui::esc($i.note) + '</span>' } ELSE { '' };
	RETURN '<li role="presentation" data-s="' + fn::ui::esc(string::lowercase($i.search)) + '" :hidden="!!q && !$el.dataset.s.includes(q.toLowerCase())">'
		+ '<a role="option" href="' + fn::ui::esc($i.href) + '" hx-get="' + fn::ui::esc($i.fragment) + '" hx-target="#app" hx-swap="outerHTML" hx-push-url="' + fn::ui::esc($i.href) + '" hx-indicator="#app"'
		+ ' aria-selected="' + (IF $i.current { 'true' } ELSE { 'false' }) + '" class="' + fn::ui::k('dd_a') + (IF $i.current { ' ' + fn::ui::k('dd_cur') } ELSE { '' }) + '"'
		+ ' @click="open = false; $refs.btn.focus()" @keydown.arrow-down.prevent="step(1)" @keydown.arrow-up.prevent="step(-1)">'
		+ $flag + '<span ' + fn::ui::c('grow') + '>' + fn::ui::esc($i.label) + '</span>' + $note + '</a></li>';
};

-- One dropdown. $items: [{ href, push, label, flag?, note?, current, search }]
DEFINE FUNCTION OVERWRITE fn::ui::dropdown($id: string, $label: string, $cur: string, $items: array<object>, $searchable: bool) -> string {
	LET $li = array::join((SELECT VALUE fn::ui::dd_item($this) FROM $items), '');
	LET $search = IF $searchable {
		 '<div ' + fn::ui::c('dd_search') + '>' + fn::ui::ico('search') + '<input ' + fn::ui::c('dd_input') + ' x-ref="q" x-model="q" type="search" autocomplete="off" placeholder="Buscar…" aria-label="Buscar em ' + fn::ui::esc($label) + '"'
		+ ' @keydown.arrow-down.prevent="step(1)" @keydown.enter.prevent="items()[0]?.click()"></div>'
	} ELSE { '' };
	RETURN '<div ' + fn::ui::c('field') + ' x-data="' + fn::ui::dd_data() + '" @keydown.escape.stop="close()" @click.outside="open = false">'
		+ '<label ' + fn::ui::c('micro') + ' id="' + $id + '-l" for="' + $id + '">' + fn::ui::esc($label) + '</label>'
		+ '<button type="button" ' + fn::ui::c('dd_btn') + ' id="' + $id + '" x-ref="btn" aria-haspopup="listbox" :aria-expanded="open" aria-labelledby="' + $id + '-l ' + $id + '" @click="toggle()" @keydown.arrow-down.prevent="open || toggle()">'
		+ $cur + fn::ui::ico('chevron') + '</button>'
		+ '<div ' + fn::ui::c('dd_panel') + ' x-show="open" x-cloak>' + $search
		+ '<p ' + fn::ui::c('dd_none') + '>Nada encontrado</p>'
		+  '<ul ' + fn::ui::c('dd_ul') + ' role="listbox" x-ref="list" aria-labelledby="' + $id + '-l">' + $li + '</ul></div></div>';
};

DEFINE FUNCTION OVERWRITE fn::ui::filters($s: object) -> string {
	LET $st = SELECT VALUE {
		href: fn::ui::url('/home', uf, 'tecnologia-da-informacao', 0), fragment: fn::ui::url('/main', uf, 'tecnologia-da-informacao', 0),
		label: name, flag: fn::cfg::base() + '/assets/flags/' + uf + '.png',
		note: IF status = 'coming-soon' { 'Em breve' } ELSE { NONE },
		current: uf = $s.uf, search: name + ' ' + uf
	} FROM $s.states;
	LET $ar = SELECT VALUE {
		href: fn::ui::url('/home', $s.uf, slug, 0), fragment: fn::ui::url('/main', $s.uf, slug, 0),
		label: label, current: slug = $s.area, search: label
	} FROM $s.areas;
	LET $un = SELECT VALUE {
		href: fn::ui::url('/home', $s.uf, $s.area, unit_id), fragment: fn::ui::url('/main', $s.uf, $s.area, unit_id),
		label: name, note: 'ID ' + <string> (official_id ?? unit_id), current: unit_id = $s.unit,
		search: name + ' ' + <string> (official_id ?? '') + ' ' + <string> unit_id
	} FROM $s.units;
	LET $cur_state = '<img ' + fn::ui::c('flag') + ' src="' + fn::cfg::base() + '/assets/flags/' + $s.uf + '.png" alt="" width="20" height="14"><span ' + fn::ui::c('grow') + '>' + fn::ui::esc($s.state.name) + '</span>';
	LET $cur_area = '<span ' + fn::ui::c('grow') + '>' + fn::ui::esc(((SELECT label FROM $s.areas WHERE slug = $s.area)[0].label) ?? 'Selecione') + '</span>';
	LET $cur_unit = '<span ' + fn::ui::c('grow') + '>' + fn::ui::esc(((SELECT name FROM $s.units WHERE unit_id = $s.unit)[0].name) ?? 'Selecione') + '</span>';
	LET $coming = $s.state.status = 'coming-soon';
	RETURN '<form ' + fn::ui::c(IF $coming { 'filters_one' } ELSE { 'filters' }) + ' onsubmit="return false" role="search" aria-label="Filtros">'
		+ fn::ui::dropdown('dd-state', 'Estado', $cur_state, $st, true)
		+ IF $coming { '' } ELSE {
			fn::ui::dropdown('dd-area', 'Área', $cur_area, $ar, false)
			+ fn::ui::dropdown('dd-unit', 'Unidade', $cur_unit, $un, true)
		}
		+ '</form>';
};

DEFINE FUNCTION OVERWRITE fn::ui::theme_toggle() -> string {
	RETURN '<button type="button" ' + fn::ui::c('icon_btn') + ' @click="theme = dark ? \'light\' : \'dark\'" :aria-label="dark ? \'Usar tema claro\' : \'Usar tema escuro\'" :title="dark ? \'Tema claro\' : \'Tema escuro\'">'
		+ '<span x-show="!dark">' + fn::ui::ico('moon') + '</span><span x-show="dark" x-cloak>' + fn::ui::ico('sun') + '</span></button>';
};

DEFINE FUNCTION OVERWRITE fn::ui::site_header() -> string {
	LET $b = fn::cfg::base();
	RETURN '<div ' + fn::ui::c('topbar') + '><div class="' + fn::ui::k('wrap') + ' ' + fn::ui::k('topbar_in') + '"><span ' + fn::ui::c('topbar_l') + '>Agregador independente e não oficial de vagas do SENAI</span>'
		+ '<span ' + fn::ui::c('topbar_r') + '><a ' + fn::ui::c('topbar_a') + ' href="' + $b + '/privacidade">Privacidade</a>' + fn::ui::theme_toggle() + '</span></div></div>'
		+ '<header ' + fn::ui::c('hdr') + '><div class="' + fn::ui::k('wrap') + ' ' + fn::ui::k('hdr_in') + '"><a ' + fn::ui::c('logo') + ' href="' + $b + '/home" aria-label="SENAI — Cursos, página inicial"><img ' + fn::ui::c('logo_img') + ' src="' + $b + '/assets/senai.svg" alt="SENAI" height="34"></a>'
		+ '<span ' + fn::ui::c('hdr_title') + '>Cursos e vagas</span></div></header>';
};

DEFINE FUNCTION OVERWRITE fn::ui::site_footer($source: string, $unit: string) -> string {
	RETURN '<footer id="ftr" hx-swap-oob="true" ' + fn::ui::c('ftr') + '><div class="' + fn::ui::k('wrap') + ' ' + fn::ui::k('ftr_in') + '"><p>Fonte: <strong>' + fn::ui::esc($source) + '</strong>' + fn::ui::esc($unit) + '</p>'
		+ '<p><a ' + fn::ui::c('ftr_a') + ' href="' + fn::cfg::base() + '/privacidade">Política de Privacidade</a></p>'
		+ '<p ' + fn::ui::c('muted') + '>Projeto independente, sem vínculo oficial com o SENAI. Confirme as vagas no site oficial antes de se inscrever.</p></div></footer>';
};

-- Preferred display for last update: local time in the browser, UTC-3 fallback server-side.
DEFINE FUNCTION OVERWRITE fn::ui::updated($iso: option<string>) -> string {
	IF $iso = NONE { RETURN '<span ' + fn::ui::c('muted') + '>Sem dados ainda</span>'; };
	LET $d = <datetime> $iso;
	LET $br = $d - 3h;
	RETURN '<time datetime="' + fn::ui::esc($iso) + '" x-text="new Date($el.dateTime).toLocaleTimeString(\'pt-BR\', { hour: \'2-digit\', minute: \'2-digit\' })">'
		+ time::format($br, '%H:%M') + '</time>';
};

DEFINE FUNCTION OVERWRITE fn::ui::stat($label: string, $value: string, $sub: string) -> string {
	RETURN '<div ' + fn::ui::c('stat') + '><p ' + fn::ui::c('micro') + '>' + $label + '</p><p ' + fn::ui::c('stat_v') + '>' + $value + '</p><p ' + fn::ui::c('stat_s') + '>' + $sub + '</p></div>';
};

DEFINE FUNCTION OVERWRITE fn::ui::stats($free: array<object>, $iso: option<string>) -> string {
	LET $tracked = SELECT vagas FROM $free WHERE vagas != NULL;
	LET $n = array::len($free);
	LET $has = array::len($tracked) > 0;
	LET $total = math::sum(SELECT VALUE vagas FROM $tracked);
	LET $open = array::len(SELECT vagas FROM $tracked WHERE vagas > 0);
	RETURN '<div ' + fn::ui::c('stats') + '>'
		+ fn::ui::stat('Cursos', <string> $n, 'gratuitos presenciais')
		+ fn::ui::stat('Vagas abertas', IF $has { <string> $total } ELSE { '—' }, IF $has { 'total disponível' } ELSE { 'não informado pela fonte' })
		+ fn::ui::stat('Com vagas', IF $has { <string> $open } ELSE { '—' }, IF $has { 'de ' + <string> $n + fn::ui::plural($n, ' curso', ' cursos') } ELSE { 'veja cada curso' })
		+ fn::ui::stat('Atualização', fn::ui::updated($iso), 'dados coletados em segundo plano')
		+ '</div>';
};

DEFINE FUNCTION OVERWRITE fn::ui::course_url($c: object) -> option<string> {
	RETURN $c.url ?? (IF $c.uf = 'sp' { 'https://www.sp.senai.br/curso/' + $c.slug + '/' + <string> $c.course_id }
		ELSE IF $c.uf = 'sc' { 'https://cursos.sesisenai.org.br/cursos-profissionalizantes/' + $c.slug + '/' + <string> $c.course_id }
		ELSE { NONE });
};

DEFINE FUNCTION OVERWRITE fn::ui::course_row($c: object, $max: number, $paid: bool) -> string {
	LET $unknown = $c.vagas = NONE OR $c.vagas = NULL;
	LET $has = !$unknown AND $c.vagas > 0;
	LET $full = !$has AND !$unknown AND $c.turmas > 0;
	LET $pct = IF $has AND $max > 0 { math::max([6, math::round($c.vagas / $max * 100)]) } ELSE { 0 };
	LET $badge = IF $full { '<span ' + fn::ui::c('badge_warn') + '>Esgotado</span>' } ELSE IF $unknown { '<span ' + fn::ui::c('badge') + '>Ver no site</span>' } ELSE IF !$has { '<span ' + fn::ui::c('badge_dim') + '>Sem turmas</span>' } ELSE { '' };
	LET $bolsa = IF $c.is_bolsa { '<span ' + fn::ui::c('badge_ok') + '>Bolsa</span>' } ELSE { '' };
	LET $hours = IF $c.hours > 0 { '<span ' + fn::ui::c('hours') + '>' + <string> $c.hours + 'h</span>' } ELSE { '' };
	LET $turmas = IF $c.turmas > 0 { <string> $c.turmas + ' ' + fn::ui::plural($c.turmas, 'turma', 'turmas') + IF $full { ' esgotada' + IF $c.turmas != 1 { 's' } ELSE { '' } } ELSE { '' } } ELSE { '' };
	LET $seat = IF $has { '<strong ' + fn::ui::c('seat_n') + '>' + <string> $c.vagas + '</strong> <span>' + fn::ui::plural($c.vagas, 'vaga', 'vagas') + '</span>' }
		ELSE IF $full { '<strong ' + fn::ui::c('seat_n_warn') + '>0</strong> <span>vagas</span>' }
		ELSE IF $unknown { '<span>Vagas não informadas</span>' }
		ELSE { '<span>Sem turmas abertas</span>' };
	LET $dates = $c.start_dates ?? [];
	LET $shown = array::slice($dates, 0, 3);
	LET $more = array::len($dates) - array::len($shown);
	LET $d_html = IF array::len($shown) > 0 {
		'<li ' + fn::ui::c('fact') + ' title="' + fn::ui::esc(array::join($dates, ' · ')) + '">' + fn::ui::ico_c('calendar', fn::ui::k('fact_ico')) + '<span>Início: ' + fn::ui::esc(array::join($shown, ', '))
		+ IF $more > 0 { ' <span>+' + <string> $more + fn::ui::plural($more, ' data', ' datas') + '</span>' } ELSE { '' } + '</span></li>'
	} ELSE { '' };
	LET $sch = array::join((SELECT VALUE fn::ui::esc(periodo) + ' · ' + fn::ui::esc(horario) + '<br>' FROM ($c.schedules ?? [])), '');
	LET $s_html = IF string::len($sch) > 0 { '<li ' + fn::ui::c('fact') + '>' + fn::ui::ico_c('clock', fn::ui::k('fact_ico')) + '<span>' + $sch + '</span></li>' } ELSE { '' };
	LET $pr = $c.prices ?? [];
	LET $p_label = IF array::len($pr) = 0 { '' } ELSE IF array::len($pr) = 1 { $pr[0] } ELSE { $pr[0] + ' – ' + $pr[array::len($pr) - 1] };
	LET $p_html = IF $paid AND string::len($p_label) > 0 { '<li ' + fn::ui::c('fact') + '>' + fn::ui::ico_c('tag', fn::ui::k('fact_ico')) + '<span ' + fn::ui::c('strong') + '>' + fn::ui::esc($p_label) + '</span></li>' } ELSE { '' };
	LET $url = fn::ui::course_url($c);
	LET $name = IF $url != NONE {
		'<a ' + fn::ui::c('course_link') + ' href="' + fn::ui::esc($url) + '" target="_blank" rel="noopener noreferrer">' + fn::ui::esc($c.name) + '<span class="sr-only">(abre o site oficial em nova aba)</span>' + fn::ui::ico_c('ext', fn::ui::k('ext')) + '</a>'
	} ELSE { '<span>' + fn::ui::esc($c.name) + '</span>' };
	RETURN '<li ' + fn::ui::c('course') + '><div><h4 ' + fn::ui::c(IF !$has AND !$unknown { 'course_name_off' } ELSE { 'course_name' }) + '>' + $name + '</h4>'
		+ '<p ' + fn::ui::c('course_meta') + '>' + $hours + $bolsa + $badge + '</p>'
		+ '<ul ' + fn::ui::c('facts') + '>' + $d_html + $s_html + $p_html + '</ul></div>'
		+ '<div><p ' + fn::ui::c('seat_line') + '>' + $seat + IF string::len($turmas) > 0 { '<span ' + fn::ui::c('turmas') + '>' + $turmas + '</span>' } ELSE { '' } + '</p>'
		+ '<div ' + fn::ui::c(IF $full { 'bar_full' } ELSE { 'bar' }) + ' aria-hidden="true"><i ' + fn::ui::c(IF $paid { 'fill_paid' } ELSE { 'fill' }) + ' style="width:' + <string> $pct + '%"></i></div></div></li>';
};

DEFINE FUNCTION OVERWRITE fn::ui::course_section($title: string, $num: string, $courses: array<object>, $paid: bool) -> string {
	LET $max = math::max(array::concat([1], SELECT VALUE vagas FROM $courses WHERE vagas != NULL));
	LET $rows = array::join((SELECT VALUE fn::ui::course_row($this, $max, $paid) FROM $courses), '');
	RETURN '<section ' + fn::ui::c('block') + ' aria-labelledby="sec-' + $num + '"><div ' + fn::ui::c('block_h') + '><span ' + fn::ui::c('block_n') + '>' + $num + '</span><h3 ' + fn::ui::c('block_h3') + ' id="sec-' + $num + '">' + $title + '</h3><span ' + fn::ui::c('count') + '>' + <string> array::len($courses) + '</span></div>'
		+ '<ul ' + fn::ui::c('courses') + '>' + $rows + '</ul></section>';
};

DEFINE FUNCTION OVERWRITE fn::ui::notice($icon: string, $title: string, $text: string) -> string {
	RETURN '<div ' + fn::ui::c('notice') + ' role="status">' + fn::ui::ico_c($icon, fn::ui::k('notice_ico')) + '<div><p ' + fn::ui::c('notice_t') + '>' + $title + '</p><p ' + fn::ui::c('notice_p') + '>' + $text + '</p></div></div>';
};
