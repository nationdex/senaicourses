-- UI core helpers (workstream B). Pure string builders: no side effects.

-- Minimal HTML escape for any DB value that reaches the page (text or attribute).
DEFINE FUNCTION OVERWRITE fn::ui::esc($s: any) -> string {
	RETURN string::replace(string::replace(string::replace(string::replace(string::replace(
		<string> ($s ?? ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;'), '\'', '&#39;');
};

DEFINE FUNCTION OVERWRITE fn::ui::plural($n: number, $one: string, $many: string) -> string {
	RETURN IF $n = 1 { $one } ELSE { $many };
};

-- Absolute URL of a route under this database. $path starts with '/'.
-- $uf/$area/$unit must already be validated (state code, area slug, int) by fn::ui::sel.
DEFINE FUNCTION OVERWRITE fn::ui::url($path: string, $uf: string, $area: string, $unit: number) -> string {
	RETURN fn::cfg::base() + $path + '?uf=' + $uf + '&area=' + $area + '&unit=' + <string> $unit;
};

-- Validates raw query params against the tables and fills defaults.
-- Returns { uf, area, unit, state, areas, units, has_data }.
DEFINE FUNCTION OVERWRITE fn::ui::sel($q: object) -> object {
	LET $states = SELECT * FROM state ORDER BY sort, name;
	LET $uf_raw = string::lowercase(<string> ($q.uf ?? ''));
	LET $state = (SELECT * FROM state WHERE uf = $uf_raw LIMIT 1)[0]
		?? (SELECT * FROM state WHERE uf = 'sp' LIMIT 1)[0]
		?? $states[0];
	LET $uf = $state.uf ?? 'sp';
	LET $areas = SELECT slug, label FROM area WHERE uf = $uf ORDER BY label;
	LET $area_raw = <string> ($q.area ?? '');
	LET $area = IF array::len(SELECT slug FROM $areas WHERE slug = $area_raw) > 0 { $area_raw }
		ELSE IF array::len(SELECT slug FROM $areas WHERE slug = 'tecnologia-da-informacao') > 0 { 'tecnologia-da-informacao' }
		ELSE { $areas[0].slug ?? 'tecnologia-da-informacao' };
	LET $with_courses = array::distinct(SELECT VALUE unit_id FROM course WHERE uf = $uf AND area = $area);
	LET $units = IF array::len($with_courses) > 0 {
		SELECT unit_id, name, official_id FROM unit WHERE uf = $uf AND unit_id IN $with_courses ORDER BY name
	} ELSE {
		SELECT unit_id, name, official_id FROM unit WHERE uf = $uf ORDER BY name
	};
	LET $unit_raw = <string> ($q.unit ?? '');
	LET $unit_num = IF string::matches($unit_raw, /^[0-9]{1,9}$/) { <int> $unit_raw } ELSE { -1 };
	-- Default unit: the one with the most open seats (alphabetical first would be the EAD pseudo-unit).
	LET $best = (SELECT unit_id, math::sum(vagas ?? 0) AS seats FROM course WHERE uf = $uf AND area = $area AND is_paid = false GROUP BY unit_id ORDER BY seats DESC LIMIT 1)[0].unit_id;
	LET $unit = IF array::len(SELECT unit_id FROM $units WHERE unit_id = $unit_num) > 0 { $unit_num }
		ELSE { $best ?? $units[0].unit_id ?? 0 };
	RETURN {
		uf: $uf, area: $area, unit: $unit, state: $state, states: $states,
		areas: $areas, units: $units, has_data: array::len($with_courses) > 0
	};
};


-- UnoCSS utility class registry: one place for every repeated class string.
DEFINE FUNCTION OVERWRITE fn::ui::k($n: string) -> string {
	LET $micro = 'text-[11px] leading-tight font-semibold tracking-[.09em] uppercase';
	LET $badge = 'text-[10px] font-semibold tracking-[.08em] uppercase px-2 py-[3px] rounded-md border';
	LET $k = {
		wrap: 'w-full max-w-[1120px] mx-auto px-4 md:px-6',
		micro: $micro + ' text-muted', micro_red: $micro + ' text-red',
		muted: 'text-muted',
		topbar: 'bg-surf border-b border-line text-xs text-muted',
		topbar_in: 'flex items-center justify-between gap-3 min-h-9',
		topbar_l: 'truncate',
		topbar_r: 'flex items-center gap-3 shrink-0',
		topbar_a: 'no-underline hover:text-fg hover:underline',
		icon_btn: 'inline-flex items-center justify-center w-8 h-8 p-0 border border-line rounded-lg bg-bg text-fg cursor-pointer hover:border-muted',
		hdr: 'bg-bg border-b border-line',
		hdr_in: 'flex items-center gap-4 min-h-[68px]',
		logo: 'inline-flex',
		logo_img: 'block h-[34px] w-auto',
		hdr_title: 'font-disp font-bold text-[13px] tracking-[.06em] uppercase text-muted pl-4 border-l border-line',
		titlebar: 'flex flex-wrap items-end justify-between gap-4 pt-8 pb-5',
		h1: 'font-disp font-extrabold text-[26px] md:text-[40px] leading-[1.1] tracking-[-.01em] mt-1.5 mb-1 break-words',
		actions: 'flex items-center gap-3 flex-wrap',
		updated: 'inline-flex items-center gap-1.5 text-[13px] text-muted',
		btn: 'btn inline-flex items-center gap-2 min-h-10 px-4 border-0 rounded-xl bg-btn text-white font-semibold text-sm cursor-pointer hover:bg-redd',
		filters: 'grid gap-3 grid-cols-1 md:grid-cols-[1fr_1fr_1.4fr] p-4 bg-surf border border-line rounded-xl',
		filters_one: 'grid gap-3 grid-cols-1 md:grid-cols-[minmax(0,360px)] p-4 bg-surf border border-line rounded-xl',
		field: 'relative flex flex-col gap-1.5 min-w-0',
		dd_btn: 'dd-btn flex items-center gap-2.5 w-full min-h-11 px-3 bg-bg text-fg border border-line rounded-[10px] font-medium text-sm text-left cursor-pointer hover:border-red',
		grow: 'flex-1 min-w-0 truncate',
		flag: 'w-5 h-3.5 object-cover rounded-[2px] border border-line shrink-0',
		dd_panel: 'dd-panel absolute z-30 top-full inset-x-0 mt-1.5 bg-bg border border-line rounded-[10px] shadow-xl overflow-hidden',
		dd_search: 'dd-search flex items-center gap-2 px-3 border-b border-line text-muted',
		dd_input: 'flex-1 min-w-0 h-[42px] border-0 bg-transparent text-fg text-sm outline-none',
		dd_ul: 'max-h-72 overflow-y-auto',
		dd_none: 'dd-none hidden px-3 py-3.5 text-sm text-muted',
		dd_a: 'flex items-center gap-2.5 min-h-[42px] px-3 py-2 no-underline text-sm hover:bg-surf focus-visible:bg-surf focus-visible:outline-none hover:shadow-[inset_3px_0_0_var(--red)] focus-visible:shadow-[inset_3px_0_0_var(--red)]',
		dd_cur: 'font-semibold text-red',
		tag: 'text-[10px] font-semibold tracking-[.08em] uppercase text-muted border border-line rounded-md px-1.5 py-0.5 whitespace-nowrap',
		app: 'app',
		busy: 'busy pt-3 text-[13px] text-muted',
		results: 'results pt-5 pb-10',
		stats: 'grid grid-cols-2 md:grid-cols-4 gap-3 mb-8',
		stat: 'p-4 border border-line rounded-xl bg-surf min-w-0',
		stat_v: 'font-disp font-extrabold text-3xl leading-[1.1] mt-2 mb-1 text-fg',
		stat_s: 'text-xs text-muted',
		block: 'mb-8',
		block_h: 'flex items-center gap-3 mb-3',
		block_h3: 'font-disp font-bold text-lg',
		block_n: 'font-mono text-[11px] font-semibold tracking-[.04em] text-red px-[7px] py-[3px] border border-line rounded-md',
		count: 'ml-auto font-mono text-xs font-semibold text-muted',
		courses: 'border border-line rounded-xl overflow-hidden bg-bg',
		course: 'course relative grid gap-3 p-4 border-t border-line first:border-t-0 hover:bg-surf md:grid-cols-[minmax(0,1fr)_240px] md:gap-8 md:items-start',
		course_name: 'text-[15px] leading-snug font-semibold',
		course_name_off: 'text-[15px] leading-snug font-semibold text-muted',
		course_link: 'course-link no-underline hover:underline underline-offset-4 focus-visible:outline-none',
		ext: 'inline ml-1.5 align-[-2px] text-muted',
		course_meta: 'flex flex-wrap items-center gap-2 mt-1.5 min-h-[22px]',
		hours: 'font-mono text-xs font-medium text-muted',
		badge: $badge + ' border-line text-muted',
		badge_ok: $badge + ' border-transparent text-ok bg-okbg',
		badge_warn: $badge + ' border-transparent text-warn bg-warnbg',
		badge_dim: $badge + ' border-transparent text-muted bg-surf2',
		facts: 'grid gap-1 mt-2.5 text-[13px] text-muted',
		fact: 'flex gap-2 items-start',
		fact_ico: 'shrink-0 mt-0.5 w-3.5 h-3.5',
		strong: 'text-fg font-semibold',
		seat_line: 'flex flex-wrap items-baseline gap-1.5 text-[13px] text-muted',
		seat_n: 'font-disp font-extrabold text-[22px] leading-none text-fg',
		seat_n_warn: 'font-disp font-extrabold text-[22px] leading-none text-warn',
		turmas: 'ml-auto text-xs',
		bar: 'h-1.5 mt-2.5 bg-surf2 rounded-full overflow-hidden',
		bar_full: 'h-1.5 mt-2.5 bg-warnbg rounded-full overflow-hidden',
		fill: 'block h-full rounded-full bg-red',
		fill_paid: 'block h-full rounded-full bg-fg',
		notice: 'flex gap-4 items-start p-6 border border-line rounded-xl bg-surf',
		notice_ico: 'w-6 h-6 text-red shrink-0',
		notice_t: 'font-disp font-bold text-base mb-1',
		notice_p: 'text-muted max-w-[60ch]',
		ftr: 'border-t border-line bg-surf text-[13px] mt-auto',
		ftr_in: 'grid gap-1.5 py-6',
		ftr_a: 'underline underline-offset-4 hover:text-red',
		prose: 'max-w-[760px] pt-8 pb-14',
		prose_h1: 'font-disp font-extrabold text-[28px] md:text-[40px] leading-[1.1] mt-1.5 mb-2',
		prose_h2: 'font-disp font-bold text-lg mt-8 mb-2',
		prose_p: 'max-w-[68ch] mt-2.5',
		prose_ul: 'list-disc pl-5 grid gap-1 mt-2.5 max-w-[68ch]',
		prose_code: 'font-mono text-[.9em] bg-surf2 px-1 rounded',
		prose_a: 'text-red underline underline-offset-4',
		back: 'inline-flex items-center gap-2 text-sm text-muted no-underline hover:text-fg mb-6',
		skip: 'skip absolute -left-[999px] top-2 bg-btn text-white px-3 py-2 rounded-lg z-50 focus:left-2',
		body: 'm-0 bg-bg text-fg font-sans text-[15px] leading-normal border-t-[3px] border-red min-h-screen flex flex-col'
	};
	RETURN $k[$n] ?? '';
};

-- ` class="..."` attribute for a registry entry.
DEFINE FUNCTION OVERWRITE fn::ui::c($n: string) -> string {
	RETURN 'class="' + fn::ui::k($n) + '"';
};

-- Inline 16px stroke icons (currentColor).
DEFINE FUNCTION OVERWRITE fn::ui::ico($name: string) -> string {
	RETURN fn::ui::ico_c($name, 'shrink-0');
};

DEFINE FUNCTION OVERWRITE fn::ui::ico_c($name: string, $cls: string) -> string {
	LET $a = '<svg class="ico ' + $cls + '" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">';
	LET $p = {
		search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
		chevron: '<path d="m6 9 6 6 6-6"/>',
		refresh: '<path d="M21 12a9 9 0 1 1-3-6.7"/><path d="M21 4v5h-5"/>',
		sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
		moon: '<path d="M21 13A9 9 0 1 1 11 3a7 7 0 0 0 10 10z"/>',
		calendar: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/>',
		clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
		tag: '<path d="M3 12V3h9l9 9-9 9z"/><circle cx="7.5" cy="7.5" r="1.2"/>',
		ext: '<path d="M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/>',
		back: '<path d="M19 12H5M12 5l-7 7 7 7"/>',
		inbox: '<path d="M3 13h5l1 3h6l1-3h5M5 5h14l2 8v6H3v-6z"/>',
		alert: '<circle cx="12" cy="12" r="9"/><path d="M12 8v5M12 16.5v.5"/>'
	};
	RETURN $a + ($p[$name] ?? '') + '</svg>';
};

-- Wraps body HTML in a full document. $title is plain text (escaped here).
DEFINE FUNCTION OVERWRITE fn::ui::document($title: string, $body: string) -> string {
	LET $b = fn::cfg::base();
	RETURN array::join([
		'<!doctype html><html lang="pt-BR" x-data="{ theme: $persist(\'\').as(\'senai-theme\'), get dark() { return this.theme ? this.theme === \'dark\' : matchMedia(\'(prefers-color-scheme: dark)\').matches } }" :data-theme="dark ? \'dark\' : \'light\'">',
		'<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">',
		'<title>', fn::ui::esc($title), '</title>',
		'<meta name="description" content="Vagas em cursos presenciais do SENAI, por estado, área e unidade. Agregador independente e não oficial.">',
		'<link rel="icon" href="', $b, '/assets/favicon.svg" type="image/svg+xml">',
		'<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
		'<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=Montserrat:wght@700;800;900&display=swap">',
		'<link rel="stylesheet" href="', $b, '/ui.css">',
		'<script>window.__unocss={theme:{colors:{bg:"var(--bg)",fg:"var(--fg)",muted:"var(--muted)",line:"var(--line)",surf:"var(--surface)",surf2:"var(--surface2)",red:"var(--red)",redd:"var(--red-d)",btn:"var(--btn)",ok:"var(--ok)",okbg:"var(--ok-bg)",warn:"var(--warn)",warnbg:"var(--warn-bg)"},fontFamily:{sans:"Inter,system-ui,sans-serif",disp:"Montserrat,Inter,system-ui,sans-serif"}}}</script>',
		'<script src="https://cdn.jsdelivr.net/npm/@unocss/runtime@66.1.0/uno.global.js"></script>',
		'<script src="https://cdn.jsdelivr.net/npm/htmx.org@2.0.4/dist/htmx.min.js"></script>',
		'<script defer src="https://cdn.jsdelivr.net/npm/@alpinejs/persist@3.14.9/dist/cdn.min.js"></script>',
		'<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.14.9/dist/cdn.min.js"></script>',
		'</head><body x-cloak un-cloak ', fn::ui::c('body'), '><a ', fn::ui::c('skip'), ' href="#app">Ir para o conteúdo</a>', $body, '</body></html>'
	], '');
};

DEFINE FUNCTION OVERWRITE fn::ui::html($status: int, $body: string) -> object {
	RETURN {
		status: $status,
		headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' },
		body: $body
	};
};
