-- Crawl dispatcher + bookkeeping. Scrapers live in app/scrapers/ (workstream C):
-- fn::scrape::<uf>::step($n) -> { next, done, note }. This file only routes to them and
-- keeps per-state crawl state. Idempotent (OVERWRITE).

-- One row per state: last run, consecutive failed cycles, cycles still to skip (back-off).
DEFINE TABLE OVERWRITE crawl_state SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD OVERWRITE last_started  ON crawl_state TYPE option<datetime>;
DEFINE FIELD OVERWRITE last_finished ON crawl_state TYPE option<datetime>;   -- last complete, successful cycle
DEFINE FIELD OVERWRITE last_n        ON crawl_state TYPE option<int>;
DEFINE FIELD OVERWRITE last_note     ON crawl_state TYPE option<string>;
DEFINE FIELD OVERWRITE strikes       ON crawl_state TYPE int DEFAULT 0;      -- consecutive failed cycles
DEFINE FIELD OVERWRITE skip_cycles   ON crawl_state TYPE int DEFAULT 0;      -- cycles to skip (exponential back-off)

-- The shared secret guarding /crawl*, /retention. Written by run.sh at boot from a
-- git-ignored file; never defined in the repo. Not readable through any table API.
DEFINE TABLE OVERWRITE crawl_secret SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD OVERWRITE value ON crawl_secret TYPE string;

-- True when the request carries the right x-crawl-key header.
DEFINE FUNCTION OVERWRITE fn::crawl::authorized($headers: object) -> bool {
	LET $given = $headers['x-crawl-key'];
	LET $want = (SELECT VALUE value FROM ONLY crawl_secret:main);
	RETURN $want != NONE AND $given != NONE AND <string> $given = $want;
};

DEFINE FUNCTION OVERWRITE fn::scrape::active() -> array<string> {
	RETURN ['sp','sc','al','rs','ma','mg','ms','go','to','pi','ro','ce','mt','df','pr','es','pa','pe','rn'];
};

-- Dispatcher: uf -> fn::scrape::<uf>::step($n). A missing function (scraper not loaded
-- yet) or a failed request fails the call; the driver retries the same $n.
DEFINE FUNCTION OVERWRITE fn::scrape::step($uf: string, $n: int) -> object {
	IF $n = 0 {
		UPSERT type::record('crawl_state', $uf) MERGE { last_started: time::now() } RETURN NONE;
	};
	LET $r = IF $uf = 'sp' { fn::scrape::sp::step($n) }
	ELSE IF $uf = 'sc' { fn::scrape::sc::step($n) }
	ELSE IF $uf = 'al' { fn::scrape::al::step($n) }
	ELSE IF $uf = 'rs' { fn::scrape::rs::step($n) }
	ELSE IF $uf = 'ma' { fn::scrape::ma::step($n) }
	ELSE IF $uf = 'mg' { fn::scrape::mg::step($n) }
	ELSE IF $uf = 'ms' { fn::scrape::ms::step($n) }
	ELSE IF $uf = 'go' { fn::scrape::go::step($n) }
	ELSE IF $uf = 'to' { fn::scrape::to::step($n) }
	ELSE IF $uf = 'pi' { fn::scrape::pi::step($n) }
	ELSE IF $uf = 'ro' { fn::scrape::ro::step($n) }
	ELSE IF $uf = 'ce' { fn::scrape::ce::step($n) }
	ELSE IF $uf = 'mt' { fn::scrape::mt::step($n) }
	ELSE IF $uf = 'df' { fn::scrape::df::step($n) }
	ELSE IF $uf = 'pr' { fn::scrape::pr::step($n) }
	ELSE IF $uf = 'es' { fn::scrape::es::step($n) }
	ELSE IF $uf = 'pa' { fn::scrape::pa::step($n) }
	ELSE IF $uf = 'pe' { fn::scrape::pe::step($n) }
	ELSE IF $uf = 'rn' { fn::scrape::rn::step($n) }
	ELSE { { next: NONE, done: true, note: 'unknown state' } };
	UPSERT type::record('crawl_state', $uf) MERGE {
		last_n: $n,
		last_note: <string> ($r.note ?? ''),
		last_finished: IF $r.done = true { time::now() } ELSE { NONE }
	} RETURN NONE;
	RETURN $r;
};

-- Cycle outcome reported by the driver (a failed step is an HTTP error, which cannot be
-- recorded from inside the failing call). result: 'ok' | 'fail' | 'skip'.
--   ok   -> strikes 0, skip 0
--   fail -> strikes+1, skip_cycles = min(2^(strikes-1), 8)
--   skip -> skip_cycles-1 (the driver skipped this state this cycle)
DEFINE FUNCTION OVERWRITE fn::crawl::report($uf: string, $result: string) {
	LET $cur = (SELECT * FROM ONLY type::record('crawl_state', $uf));
	LET $strikes = $cur.strikes ?? 0;
	LET $skip = $cur.skip_cycles ?? 0;
	IF $result = 'ok' {
		UPSERT type::record('crawl_state', $uf) MERGE { strikes: 0, skip_cycles: 0 } RETURN NONE;
	} ELSE IF $result = 'fail' {
		LET $s = $strikes + 1;
		UPSERT type::record('crawl_state', $uf) MERGE {
			strikes: $s, skip_cycles: math::min([math::pow(2, $s - 1), 8])
		} RETURN NONE;
	} ELSE IF $result = 'skip' {
		UPSERT type::record('crawl_state', $uf) MERGE { skip_cycles: math::max([$skip - 1, 0]) } RETURN NONE;
	};
};

-- Plain-text status for crawl.sh: one line per state that has a row (missing = never crawled):
--   <uf> <last_finished unix seconds, 0 = never> <strikes> <skip_cycles>
DEFINE FUNCTION OVERWRITE fn::crawl::status() -> string {
	LET $lines = SELECT VALUE string::concat(
		record::id(id), ' ', <string> (IF last_finished != NONE { time::unix(last_finished) } ELSE { 0 }),
		' ', <string> strikes, ' ', <string> skip_cycles
	) FROM crawl_state;
	RETURN array::join($lines, '\n');
};

-- Retention: drop courses not re-scraped for $days days (the source no longer lists them).
DEFINE FUNCTION OVERWRITE fn::crawl::retention($days: int) -> int {
	LET $cutoff = <string> (time::now() - <duration> string::concat(<string> $days, 'd'));
	LET $before = count((SELECT id FROM course WHERE scraped_at < $cutoff));
	fn::db::delete_stale($cutoff);
	RETURN $before;
};
