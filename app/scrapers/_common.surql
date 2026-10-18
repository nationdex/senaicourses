-- Shared scraper helpers (workstream C). Loaded before the per-state files.
-- SurrealQL only: no regex capture groups, no try/catch, no http timeout.
-- Parsing is done with string::split / slice / replace(regex) / matches.

-- Identifiable User-Agent, same as the legacy adapters.
DEFINE FUNCTION OVERWRITE fn::scrape::common::headers() -> object {
	RETURN { 'User-Agent': 'Mozilla/5.0 (compatible; SENAI-Monitor)' };
};

-- GET a URL as text/JSON (JSON content-type parses to a value, anything else is a string).
-- An HTTP error fails the calling step (the driver retries the same n).
DEFINE FUNCTION OVERWRITE fn::scrape::common::get($url: string) {
	RETURN http::get($url, fn::scrape::common::headers());
};

-- Form POST (application/x-www-form-urlencoded), as the legacy postForm().
DEFINE FUNCTION OVERWRITE fn::scrape::common::post_form($url: string, $body: string) {
	RETURN http::post($url, $body, {
		'User-Agent': 'Mozilla/5.0 (compatible; SENAI-Monitor)',
		'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
		'X-Requested-With': 'XMLHttpRequest'
	});
};

-- Code point -> string (via UTF-8 bytes).
DEFINE FUNCTION OVERWRITE fn::scrape::common::chr($cp: int) -> string {
	IF $cp < 128 { RETURN <string> <bytes> [$cp]; };
	IF $cp < 2048 { RETURN <string> <bytes> [192 + math::floor($cp / 64), 128 + ($cp % 64)]; };
	IF $cp < 65536 {
		RETURN <string> <bytes> [224 + math::floor($cp / 4096), 128 + (math::floor($cp / 64) % 64), 128 + ($cp % 64)];
	};
	RETURN <string> <bytes> [240 + math::floor($cp / 262144), 128 + (math::floor($cp / 4096) % 64), 128 + (math::floor($cp / 64) % 64), 128 + ($cp % 64)];
};

-- Parse digits in base 10 or 16; NONE when invalid/empty.
DEFINE FUNCTION OVERWRITE fn::scrape::common::parse_base($s: string, $base: int) -> option<int> {
	LET $n = string::len($s);
	IF $n = 0 OR $n > 8 { RETURN NONE; };
	LET $digits = '0123456789abcdef';
	LET $vals = array::map(<array> 0..$n, |$i| {
		LET $ch = string::lowercase(string::slice($s, $i, $i + 1));
		RETURN IF string::contains($digits, $ch) { string::len(string::split($digits, $ch)[0]) } ELSE { 99 };
	});
	IF array::any($vals, |$d| $d >= $base) { RETURN NONE; };
	RETURN array::fold($vals, 0, |$acc, $d| $acc * $base + $d);
};

-- One '&#...' segment (text AFTER the '&#'): decoded char + rest, or the original text.
DEFINE FUNCTION OVERWRITE fn::scrape::common::entity_piece($p: string) -> string {
	LET $semi = string::split(string::slice($p, 0, 9), ';');
	IF array::len($semi) < 2 { RETURN '&#' + $p; };
	LET $tok = $semi[0];
	LET $hex = string::starts_with($tok, 'x') OR string::starts_with($tok, 'X');
	LET $cp = IF $hex { fn::scrape::common::parse_base(string::slice($tok, 1), 16) } ELSE { fn::scrape::common::parse_base($tok, 10) };
	IF $cp = NONE OR $cp <= 0 { RETURN '&#' + $p; };
	RETURN fn::scrape::common::chr($cp) + string::slice($p, string::len($tok) + 1);
};

-- Port of legacy decodeEntities(): numeric entities, &amp; &lt; &gt; &quot; &apos;,
-- then strips tags and trims. Also handles &nbsp; and the Portuguese named entities.
DEFINE FUNCTION OVERWRITE fn::scrape::common::decode($str: any) -> string {
	IF $str = NONE OR $str = NULL { RETURN ''; };
	LET $s0 = <string> $str;
	LET $parts = string::split($s0, '&#');
	LET $s1 = IF array::len($parts) > 1 {
		array::fold(array::slice($parts, 1), $parts[0], |$acc, $p| $acc + fn::scrape::common::entity_piece($p))
	} ELSE { $s0 };
	IF !string::contains($s1, '&') AND !string::contains($s1, '<') { RETURN string::trim($s1); };
	LET $pairs = [
		['&nbsp;', ' '], ['&aacute;', 'á'], ['&agrave;', 'à'], ['&acirc;', 'â'], ['&atilde;', 'ã'],
		['&ccedil;', 'ç'], ['&eacute;', 'é'], ['&ecirc;', 'ê'], ['&iacute;', 'í'], ['&oacute;', 'ó'],
		['&ocirc;', 'ô'], ['&otilde;', 'õ'], ['&uacute;', 'ú'], ['&Aacute;', 'Á'], ['&Eacute;', 'É'],
		['&Iacute;', 'Í'], ['&Oacute;', 'Ó'], ['&Uacute;', 'Ú'], ['&Ccedil;', 'Ç'], ['&Atilde;', 'Ã'],
		['&ordm;', 'º'], ['&ordf;', 'ª'], ['&amp;', '&'], ['&lt;', '<'], ['&gt;', '>'],
		['&quot;', '"'], ['&apos;', "'"]
	];
	LET $s2 = array::fold($pairs, $s1, |$acc, $pr| string::replace($acc, $pr[0], $pr[1]));
	RETURN string::trim(string::replace($s2, /<[^>]+>/, ''));
};

-- Collapse whitespace runs to a single space and trim.
DEFINE FUNCTION OVERWRITE fn::scrape::common::squish($s: any) -> string {
	IF $s = NONE OR $s = NULL { RETURN ''; };
	RETURN string::trim(string::replace(<string> $s, /\s+/, ' '));
};

-- Equivalent of the legacy slugify(): "Tecnologia da Informação" -> "tecnologia-da-informacao".
DEFINE FUNCTION OVERWRITE fn::scrape::common::slugify($s: string) -> string {
	RETURN string::slug($s);
};

-- Text after the first occurrence of $a ('' if absent).
DEFINE FUNCTION OVERWRITE fn::scrape::common::after($s: string, $a: string) -> string {
	LET $p = string::split($s, $a);
	IF array::len($p) < 2 { RETURN ''; };
	RETURN string::slice($s, string::len($p[0]) + string::len($a));
};

-- Text before the first occurrence of $b (whole string if absent).
DEFINE FUNCTION OVERWRITE fn::scrape::common::before($s: string, $b: string) -> string {
	RETURN string::split($s, $b)[0];
};

-- Text between the first $a and the following $b ('' if $a absent).
DEFINE FUNCTION OVERWRITE fn::scrape::common::between($s: string, $a: string, $b: string) -> string {
	RETURN fn::scrape::common::before(fn::scrape::common::after($s, $a), $b);
};

-- Value of attribute $attr inside a tag/opening-tag string ('' if absent). Handles " and '.
DEFINE FUNCTION OVERWRITE fn::scrape::common::attr($tag: string, $attr: string) -> string {
	LET $d = fn::scrape::common::between($tag, $attr + '="', '"');
	IF string::contains($tag, $attr + '="') { RETURN $d; };
	IF string::contains($tag, $attr + "='") { RETURN fn::scrape::common::between($tag, $attr + "='", "'"); };
	RETURN '';
};

-- parseInt(): leading integer of the string, else $default (0).
DEFINE FUNCTION OVERWRITE fn::scrape::common::to_int($s: any, $default: int) -> int {
	IF $s = NONE OR $s = NULL { RETURN $default; };
	LET $t = string::replace(string::replace(<string> $s, /^\D+/, ''), /\D[\s\S]*$/, '');
	IF string::len($t) = 0 OR string::len($t) > 15 { RETURN $default; };
	RETURN <int> $t;
};

-- parseFloat(): leading decimal number of the string (digits and dots), else $default.
DEFINE FUNCTION OVERWRITE fn::scrape::common::to_float($s: any, $default: float) -> float {
	IF $s = NONE OR $s = NULL { RETURN $default; };
	LET $t = string::replace(string::replace(string::trim(<string> $s), /^[^0-9.]+/, ''), /[^0-9.][\s\S]*$/, '');
	LET $t2 = IF string::len(string::split($t, '.')[0]) = 0 { '0' + $t } ELSE { $t };
	IF string::len($t) = 0 OR !string::matches($t2, /^\d+(\.\d*)?$/) { RETURN $default; };
	RETURN <float> $t2;
};

-- Brazilian currency as the legacy toFixed(2) + comma: 1234.5 -> "R$ 1234,50".
DEFINE FUNCTION OVERWRITE fn::scrape::common::brl($x: number) -> string {
	LET $c = <int> math::round(<float> $x * 100);
	LET $r = $c % 100;
	RETURN 'R$ ' + <string> math::floor($c / 100) + ',' + IF $r < 10 { '0' + <string> $r } ELSE { <string> $r };
};

-- Stable 31-bit FNV-1a hash of a name (matches the legacy futuro-digital city id):
--   h = 0x811c9dc5; per UTF-16 unit: h = imul(h ^ c, 0x01000193); id = (h & 0x7fffffff) || 1
-- UTF-8 -> UTF-16 units handles the BMP (all the catalogs contain); astral chars count as one unit.
DEFINE FUNCTION OVERWRITE fn::scrape::common::units_of($name: string) -> array<int> {
	LET $b = <array> <bytes> $name;
	LET $leads = array::filter(<array> 0..array::len($b), |$i| $b[$i] < 128 OR $b[$i] >= 192);
	RETURN array::map($leads, |$i| {
		LET $x = $b[$i];
		RETURN IF $x < 128 { $x }
		ELSE IF $x < 224 { ($x - 192) * 64 + ($b[$i + 1] - 128) }
		ELSE IF $x < 240 { ($x - 224) * 4096 + ($b[$i + 1] - 128) * 64 + ($b[$i + 2] - 128) }
		ELSE { ($x - 240) * 262144 + ($b[$i + 1] - 128) * 4096 + ($b[$i + 2] - 128) * 64 + ($b[$i + 3] - 128) };
	});
};

-- xor of two non-negative ints below 2^32.
DEFINE FUNCTION OVERWRITE fn::scrape::common::xor($a: int, $b: int) -> int {
	RETURN array::fold(<array> 0..32, 0, |$acc, $k| {
		LET $p = math::pow(2, $k);
		RETURN IF (math::floor($a / $p) % 2) != (math::floor($b / $p) % 2) { $acc + $p } ELSE { $acc };
	});
};

DEFINE FUNCTION OVERWRITE fn::scrape::common::fnv_id($name: string) -> int {
	LET $h = array::fold(fn::scrape::common::units_of($name), 2166136261, |$h, $c| {
		-- c < 65536: only the low 16 bits of h change.
		LET $lo = $h % 65536;
		RETURN (($h - $lo) + fn::scrape::common::xor($lo, $c)) * 16777619 % 4294967296;
	});
	LET $id = $h % 2147483648;
	RETURN IF $id = 0 { 1 } ELSE { $id };
};

-- First dd/mm/yyyy date found in a string, else NONE.
DEFINE FUNCTION OVERWRITE fn::scrape::common::first_date($s: any) -> option<string> {
	IF $s = NONE OR $s = NULL { RETURN NONE; };
	LET $toks = array::map(string::split(string::replace(<string> $s, /\s+/, ' '), ' '), |$t| string::replace($t, /[^0-9\/]/, ''));
	LET $hit = array::filter($toks, |$t| string::matches($t, /^\d{2}\/\d{2}\/\d{4}$/));
	RETURN $hit[0];
};

-- Distinct preserving first-seen order, by a string key field.
DEFINE FUNCTION OVERWRITE fn::scrape::common::uniq_by($rows: array<object>, $key: string) -> array<object> {
	RETURN array::fold($rows, [], |$acc, $r| IF array::any($acc, |$a| $a[$key] = $r[$key]) { $acc } ELSE { array::push($acc, $r) });
};

-- Per-uf work queue kept in the database (cross-step state): a list of arbitrary objects.
DEFINE TABLE OVERWRITE scrape_queue SCHEMALESS;
DEFINE INDEX OVERWRITE scrape_queue_uf ON TABLE scrape_queue FIELDS uf, idx UNIQUE;
DEFINE FUNCTION OVERWRITE fn::scrape::common::queue_set($uf: string, $items: array<object>) {
	DELETE scrape_queue WHERE uf = $uf RETURN NONE;
	FOR $i IN <array> 0..array::len($items) {
		CREATE scrape_queue CONTENT { uf: $uf, idx: $i, data: $items[$i] } RETURN NONE;
	};
};
DEFINE FUNCTION OVERWRITE fn::scrape::common::queue_get($uf: string, $idx: int) {
	LET $r = (SELECT data, skip FROM scrape_queue WHERE uf = $uf AND idx = $idx)[0];
	IF $r = NONE { RETURN NONE; };
	-- a task the driver gave up on (see skip_task) comes back as { t: 'skipped' }
	IF $r.skip = true { RETURN { t: 'skipped' }; };
	RETURN $r.data;
};
-- Driver contract: when step $n of a queue-driven scraper ($uf in sc ce to mt sp al...) keeps failing
-- (e.g. one upstream page that always answers 5xx), call this and continue with $n + 1. The task
-- is then skipped (its data stays as it was) instead of blocking the cycle forever.
DEFINE FUNCTION OVERWRITE fn::scrape::common::skip_task($uf: string, $n: int) -> object {
	LET $t = (UPDATE scrape_queue SET skip = true WHERE uf = $uf AND idx = $n - 1 RETURN AFTER);
	RETURN { skipped: array::len($t) > 0 };
};
DEFINE FUNCTION OVERWRITE fn::scrape::common::queue_len($uf: string) -> int {
	RETURN (SELECT VALUE count() FROM scrape_queue WHERE uf = $uf GROUP ALL)[0] ?? 0;
};

DEFINE FUNCTION OVERWRITE fn::scrape::common::queue_push($uf: string, $item: object) {
	CREATE scrape_queue CONTENT { uf: $uf, idx: fn::scrape::common::queue_len($uf), data: $item } RETURN NONE;
};
-- Pushes several tasks (in order).
DEFINE FUNCTION OVERWRITE fn::scrape::common::queue_push_all($uf: string, $items: array<object>) {
	LET $base = fn::scrape::common::queue_len($uf);
	FOR $i IN <array> 0..array::len($items) {
		CREATE scrape_queue CONTENT { uf: $uf, idx: $base + $i, data: $items[$i] } RETURN NONE;
	};
};

-- Cycle start marker (taken at step 0, used by the final prune).
DEFINE TABLE OVERWRITE scrape_meta SCHEMALESS;
DEFINE FUNCTION OVERWRITE fn::scrape::common::cycle_start($uf: string) {
	UPSERT type::record('scrape_meta', $uf) CONTENT { uf: $uf, started_at: <string> time::now() } RETURN NONE;
};
DEFINE FUNCTION OVERWRITE fn::scrape::common::cycle_started_at($uf: string) -> string {
	RETURN (SELECT VALUE started_at FROM ONLY type::record('scrape_meta', $uf)) ?? '1970-01-01T00:00:00Z';
};

-- Final step of a queue-driven cycle: drops every course of $uf (free+paid) not refreshed since
-- the cycle started. Only reached when every earlier step of the cycle succeeded.
DEFINE FUNCTION OVERWRITE fn::scrape::common::finalize($uf: string) -> object {
	LET $since = fn::scrape::common::cycle_started_at($uf);
	LET $scopes = (SELECT area, unit_id, is_paid FROM course WHERE uf = $uf AND scraped_at < $since GROUP BY area, unit_id, is_paid);
	FOR $s IN $scopes { fn::db::prune_unit($uf, $s.area, $s.unit_id, $s.is_paid, $since); };
	RETURN { next: NONE, done: true, note: 'done; pruned ' + <string> array::len($scopes) + ' stale scopes' };
};

-- Standard step result after finishing queue task $n.
DEFINE FUNCTION OVERWRITE fn::scrape::common::advance($n: int, $note: string) -> object {
	RETURN { next: $n + 1, done: false, note: $note };
};

-- ---------------------------------------------------------------------------
-- Flat "entries" pipeline for catalogs that list (unit, área, course) rows.
-- entry = { unit_id, unit_name, official_id?, area, area_label, is_paid, course: {course_id, name,
--   slug, hours, vagas, turmas, start_dates, schedules, prices, is_bolsa, url} }
-- Large catalogs are staged page by page in scrape_stage and written in one later step.
-- ---------------------------------------------------------------------------
DEFINE TABLE OVERWRITE scrape_stage SCHEMALESS;
DEFINE INDEX OVERWRITE scrape_stage_uf ON TABLE scrape_stage FIELDS uf;
DEFINE FUNCTION OVERWRITE fn::scrape::common::stage_clear($uf: string) {
	DELETE scrape_stage WHERE uf = $uf RETURN NONE;
};
DEFINE FUNCTION OVERWRITE fn::scrape::common::stage_put($uf: string, $key: string, $entries: array<object>) {
	UPSERT type::record('scrape_stage', string::concat($uf, '_', $key)) CONTENT { uf: $uf, key: $key, entries: $entries } RETURN NONE;
};
DEFINE FUNCTION OVERWRITE fn::scrape::common::stage_all($uf: string) -> array<object> {
	RETURN array::flatten((SELECT VALUE entries FROM scrape_stage WHERE uf = $uf));
};

-- Writes (areas, units, courses) for one batch of entries.
DEFINE FUNCTION OVERWRITE fn::scrape::common::write_entries($uf: string, $entries: array<object>) {
	LET $areas = fn::scrape::common::uniq_by(array::map($entries, |$e| { slug: $e.area, label: $e.area_label }), 'slug');
	IF array::len($areas) > 0 { fn::db::upsert_areas($uf, $areas); };
	LET $units = fn::scrape::common::uniq_by(array::map($entries, |$e| { unit_id: $e.unit_id, name: $e.unit_name, official_id: $e.official_id }), 'unit_id');
	IF array::len($units) > 0 { fn::db::upsert_units($uf, $units); };
	LET $scopes = fn::scrape::common::uniq_by(array::map($entries, |$e| { k: string::concat($e.area, '|', <string> $e.unit_id, '|', <string> $e.is_paid), area: $e.area, unit_id: $e.unit_id, is_paid: $e.is_paid }), 'k');
	FOR $sc IN $scopes {
		LET $rows = array::map(
			array::filter($entries, |$e| $e.area = $sc.area AND $e.unit_id = $sc.unit_id AND $e.is_paid = $sc.is_paid),
			|$e| $e.course);
		fn::db::upsert_courses($uf, $sc.area, $sc.unit_id, $sc.is_paid, $rows);
	};
};

-- ---------------------------------------------------------------------------
-- Shared VTEX backend (tewbhv.vtexcommercestable.com.br).
-- Staging: one page of a product cluster is fetched per call and flattened into
-- vtex_offer rows (one per AVAILABLE item offer); per-state steps then build
-- areas / units / courses from vtex_offer. Pages are skipped while fresh.
-- ---------------------------------------------------------------------------
DEFINE TABLE OVERWRITE vtex_offer SCHEMALESS;
DEFINE INDEX OVERWRITE vtex_offer_uf ON TABLE vtex_offer FIELDS uf, area;
DEFINE INDEX OVERWRITE vtex_offer_page ON TABLE vtex_offer FIELDS cluster, page;
DEFINE TABLE OVERWRITE vtex_page SCHEMALESS;

DEFINE FUNCTION OVERWRITE fn::scrape::common::vtex::search_base() -> string {
	RETURN 'https://tewbhv.vtexcommercestable.com.br/api/catalog_system/pub/products/search';
};

-- Offer rows of one VTEX product ([] when it belongs to another state / has no area).
DEFINE FUNCTION OVERWRITE fn::scrape::common::vtex::product_rows(
	$p: object, $cluster: int, $page: int, $fixed_uf: option<string>, $ufs: array<string>
) -> array<object> {
	LET $ref = $p.productReferenceCode ?? '';
	LET $uf = IF $fixed_uf != NONE { $fixed_uf }
		ELSE IF string::contains($ref, '|') { string::lowercase(string::split($ref, '|')[0]) }
		ELSE { '' };
	IF !($uf IN $ufs) { RETURN []; };
	LET $area = $p['Área Tecnológica'][0];
	IF $area = NONE OR $area = NULL { RETURN []; };
	-- GO source data error: a fashion/textile course mistagged as Tecnologia da Informação.
	IF $uf = 'go' AND $area = 'Tecnologia da Informação'
		AND string::matches(string::lowercase($p.productName ?? ''), /vestu[aá]rio|confec[çc][ãa]o de roupas|t[êe]xtil|\bmoda\b/) { RETURN []; };
	LET $hours = fn::scrape::common::to_int($p['Carga Horária'][0], 0);
	LET $items = array::filter($p.items ?? [], |$it| ($it.sellers[0].commertialOffer.IsAvailable ?? false) = true
		AND ($it.Cidade[0] ?? '') != '');
	RETURN array::map($items, |$it| {
		uf: $uf, cluster: $cluster, page: $page, area_label: $area,
		area: fn::scrape::common::slugify($area),
		city: $it.Cidade[0], product_name: $p.productName, link_text: $p.linkText, link: $p.link,
		hours: $hours, item_id: fn::scrape::common::to_int($it.itemId, 0),
		turno: $it.Turno[0] ?? '', dia: $it['Dia da Semana'][0] ?? '',
		price: $it.sellers[0].commertialOffer.Price ?? 0
	});
};

-- Stages page $page (50 products) of cluster $cluster. $fixed_uf: e.g. 'go' for GO's own
-- clusters, or NONE to derive the uf from the "UF|" productReferenceCode prefix (master
-- cluster 137), keeping only the ufs in $ufs. Skips (cheap) if the page was staged
-- < $ttl_min minutes ago. Returns { fresh: bool, count: int, last: bool }.
DEFINE FUNCTION OVERWRITE fn::scrape::common::vtex::stage_page(
	$cluster: int, $page: int, $fixed_uf: option<string>, $ufs: array<string>, $ttl_min: int
) -> object {
	LET $pid = type::record('vtex_page', string::concat(<string> $cluster, '_', <string> $page));
	LET $cur = (SELECT * FROM ONLY $pid);
	IF $cur != NONE AND $cur.fetched_at > time::now() - <duration> string::concat(<string> $ttl_min, 'm') {
		RETURN { fresh: true, count: $cur.products, last: $cur.last };
	};
	LET $from = $page * 50;
	LET $r = http::get(
		string::concat(fn::scrape::common::vtex::search_base(), '?fq=productClusterIds:', <string> $cluster, '&_from=', <string> $from, '&_to=', <string> ($from + 49)),
		fn::scrape::common::headers()
	);
	IF type::of($r) != 'array' { THROW 'vtex: unexpected response for cluster ' + <string> $cluster + ' page ' + <string> $page; };
	IF array::len($r) = 0 AND $page = 0 { THROW 'vtex: empty first page for cluster ' + <string> $cluster; };
	LET $rows = array::flatten(array::map($r, |$p| fn::scrape::common::vtex::product_rows($p, $cluster, $page, $fixed_uf, $ufs)));
	DELETE vtex_offer WHERE cluster = $cluster AND page = $page RETURN NONE;
	IF array::len($rows) > 0 { INSERT INTO vtex_offer $rows RETURN NONE; };
	LET $n = array::len($r);
	UPSERT $pid CONTENT { fetched_at: time::now(), products: $n, last: $n < 50 };
	RETURN { fresh: false, count: $n, last: $n < 50 };
};

-- Distinct areas of a state from staged offers.
DEFINE FUNCTION OVERWRITE fn::scrape::common::vtex::areas($uf: string) -> array<object> {
	RETURN (SELECT area AS slug, area_label AS label FROM vtex_offer WHERE uf = $uf GROUP BY area, area_label);
};

DEFINE FUNCTION OVERWRITE fn::scrape::common::vtex::units($uf: string) -> array<object> {
	LET $cities = array::distinct((SELECT VALUE city FROM vtex_offer WHERE uf = $uf));
	RETURN array::map($cities, |$c| { unit_id: fn::scrape::common::fnv_id($c), name: $c });
};

-- Writes the courses of one city x (free|paid) of one área from staged offers.
DEFINE FUNCTION OVERWRITE fn::scrape::common::vtex::write_city(
	$uf: string, $area: string, $city: string, $paid: bool, $offers: array<object>
) {
	LET $uid = fn::scrape::common::fnv_id($city);
	LET $since = <string> time::now();
	LET $mine = array::filter($offers, |$o| $o.city = $city AND (($o.price > 0) = $paid));
	LET $rows = array::map($mine, |$o| {
		course_id: $o.item_id, name: $o.product_name, slug: $o.link_text, hours: $o.hours,
		vagas: NULL, turmas: 1, start_dates: [],
		schedules: IF string::len($o.turno) > 0 { [{ periodo: $o.turno, horario: $o.dia }] } ELSE { [] },
		prices: IF $paid { [fn::scrape::common::brl($o.price)] } ELSE { [] },
		is_bolsa: false, url: $o.link
	});
	IF array::len($rows) > 0 { fn::db::upsert_courses($uf, $area, $uid, $paid, $rows); };
	fn::db::prune_unit($uf, $area, $uid, $paid, $since);
};

-- Writes the courses of one área of one state (all cities, free+paid) from staged offers.
DEFINE FUNCTION OVERWRITE fn::scrape::common::vtex::write_area($uf: string, $area: string) {
	LET $offers = (SELECT * FROM vtex_offer WHERE uf = $uf AND area = $area);
	LET $cities = array::distinct(array::map($offers, |$o| $o.city));
	FOR $city IN $cities {
		fn::scrape::common::vtex::write_city($uf, $area, $city, false, $offers);
		fn::scrape::common::vtex::write_city($uf, $area, $city, true, $offers);
	};
};

-- Stages the first non-fresh page at or after $page (fresh pages are skipped in one go).
-- Returns { page: int (last page handled), last: bool, fetched: bool }.
DEFINE FUNCTION OVERWRITE fn::scrape::common::vtex::stage_from(
	$cluster: int, $page: int, $fixed_uf: option<string>, $ufs: array<string>, $ttl_min: int
) -> object {
	IF $page >= 30 { RETURN { page: 29, last: true, fetched: false }; };
	LET $r = fn::scrape::common::vtex::stage_page($cluster, $page, $fixed_uf, $ufs, $ttl_min);
	IF $r.fresh AND !$r.last { RETURN fn::scrape::common::vtex::stage_from($cluster, $page + 1, $fixed_uf, $ufs, $ttl_min); };
	RETURN { page: $page, last: $r.last, fetched: !$r.fresh };
};

-- Generic step for a state on the shared VTEX backend.
--   n in [ci*30, ci*30+29]: stage cluster #ci (fresh pages skipped); next = next cluster or 1000
--   n = 1000: persist areas + units;  n = 1001+i: courses of área i (free+paid, all cities)
-- $clusters: cluster ids; $fixed_uf: NONE (derive uf from "UF|" prefix) or a uf;
-- $ufs: the ufs to keep while staging (the master cluster is shared by many states).
DEFINE FUNCTION OVERWRITE fn::scrape::common::vtex::step(
	$uf: string, $n: int, $clusters: array<int>, $fixed_uf: option<string>, $ufs: array<string>
) -> object {
	IF $n < 1000 {
		LET $ci = math::floor($n / 30);
		IF $ci >= array::len($clusters) { RETURN { next: 1000, done: false, note: 'staging complete' }; };
		LET $r = fn::scrape::common::vtex::stage_from($clusters[$ci], $n % 30, $fixed_uf, $ufs, 30);
		LET $nxt = IF !$r.last { $ci * 30 + $r.page + 1 }
			ELSE IF $ci + 1 >= array::len($clusters) { 1000 }
			ELSE { ($ci + 1) * 30 };
		RETURN { next: $nxt, done: false, note: string::concat('cluster ', <string> $clusters[$ci], ' staged through page ', <string> $r.page) };
	};
	LET $areas = (SELECT area AS slug, area_label AS label FROM vtex_offer WHERE uf = $uf GROUP BY area, area_label ORDER BY slug);
	IF $n = 1000 {
		IF array::len($areas) = 0 { RETURN { next: NONE, done: true, note: 'no available offers staged for ' + $uf }; };
		fn::db::upsert_areas($uf, $areas);
		LET $units = fn::scrape::common::vtex::units($uf);
		fn::db::upsert_units($uf, $units);
		RETURN { next: 1001, done: false, note: string::concat(<string> array::len($areas), ' areas, ', <string> array::len($units), ' units') };
	};
	LET $i = $n - 1001;
	IF $i >= array::len($areas) { RETURN { next: NONE, done: true, note: 'done' }; };
	fn::scrape::common::vtex::write_area($uf, $areas[$i].slug);
	RETURN { next: IF $i + 1 >= array::len($areas) { NONE } ELSE { $n + 1 }, done: $i + 1 >= array::len($areas), note: 'area ' + $areas[$i].slug };
};
