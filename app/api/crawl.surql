-- Guarded operational routes. All require the header  x-crawl-key: <secret>
-- (see lib/dispatch.surql and run.sh). Responses are small plain text / JSON.

DEFINE FUNCTION OVERWRITE fn::crawl::deny() -> object {
	RETURN { status: 403, headers: { 'content-type': 'text/plain; charset=utf-8' }, body: 'forbidden' };
};

-- GET /crawl/:uf/:n -> runs one scraper step; JSON { next, done, note }.
DEFINE API OVERWRITE '/crawl/:uf/:n' FOR get THEN {
	IF NOT (fn::crawl::authorized($request.headers)) { RETURN fn::crawl::deny(); };
	LET $uf = $request.params.uf;
	IF NOT ($uf IN fn::scrape::active()) {
		RETURN { status: 404, headers: { 'content-type': 'text/plain; charset=utf-8' }, body: 'unknown state' };
	};
	LET $r = fn::scrape::step($uf, <int> $request.params.n);
	RETURN {
		status: 200,
		headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
		body: string::concat(
			'{"next":', IF $r.next = NONE { 'null' } ELSE { <string> $r.next },
			',"done":', IF $r.done = true { 'true' } ELSE { 'false' },
			',"note":"', string::replace(string::replace(<string> ($r.note ?? ''), '\\', '/'), '"', "'"), '"}'
		)
	};
};

-- GET /crawl-status -> one line per active state: "<uf> <last_finished_unix> <strikes> <skip>".
DEFINE API OVERWRITE '/crawl-status' FOR get THEN {
	IF NOT (fn::crawl::authorized($request.headers)) { RETURN fn::crawl::deny(); };
	RETURN { status: 200, headers: { 'content-type': 'text/plain; charset=utf-8', 'cache-control': 'no-store' }, body: fn::crawl::status() };
};

-- GET /crawl-report/:uf/:result  (ok | fail | skip) -> records the cycle outcome.
DEFINE API OVERWRITE '/crawl-report/:uf/:result' FOR get THEN {
	IF NOT (fn::crawl::authorized($request.headers)) { RETURN fn::crawl::deny(); };
	IF NOT ($request.params.uf IN fn::scrape::active()) OR NOT ($request.params.result IN ['ok', 'fail', 'skip']) {
		RETURN { status: 400, headers: { 'content-type': 'text/plain; charset=utf-8' }, body: 'bad request' };
	};
	fn::crawl::report($request.params.uf, $request.params.result);
	RETURN { status: 200, headers: { 'content-type': 'text/plain; charset=utf-8' }, body: 'ok' };
};

-- GET /retention/:days -> deletes courses not scraped for :days days; body = rows removed.
DEFINE API OVERWRITE '/retention/:days' FOR get THEN {
	IF NOT (fn::crawl::authorized($request.headers)) { RETURN fn::crawl::deny(); };
	LET $days = <int> $request.params.days;
	IF $days < 1 { RETURN { status: 400, headers: { 'content-type': 'text/plain; charset=utf-8' }, body: 'days must be >= 1' }; };
	RETURN { status: 200, headers: { 'content-type': 'text/plain; charset=utf-8' }, body: <string> fn::crawl::retention($days) };
};

-- GET /crawl-skip/:uf/:n -> gives up on queue task of step :n (see fn::scrape::common::skip_task); body "1" or "0".
DEFINE API OVERWRITE '/crawl-skip/:uf/:n' FOR get THEN {
	IF NOT (fn::crawl::authorized($request.headers)) { RETURN fn::crawl::deny(); };
	IF NOT ($request.params.uf IN fn::scrape::active()) {
		RETURN { status: 400, headers: { 'content-type': 'text/plain; charset=utf-8' }, body: 'bad request' };
	};
	LET $r = fn::scrape::common::skip_task($request.params.uf, <int> $request.params.n);
	RETURN { status: 200, headers: { 'content-type': 'text/plain; charset=utf-8' }, body: IF $r.skipped { '1' } ELSE { '0' } };
};
