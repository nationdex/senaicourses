-- Public routes (all under /api/senai/<db>/). '/' is unreachable, hence /home.

DEFINE API OVERWRITE '/home' FOR get THEN {
	RETURN fn::ui::html(200, fn::ui::home_page($request.query ?? {}));
};

-- htmx fragment: the #app region for the given selection.
DEFINE API OVERWRITE '/main' FOR get THEN {
	RETURN fn::ui::html(200, fn::ui::main($request.query ?? {}));
};

DEFINE API OVERWRITE '/privacidade' FOR get THEN {
	RETURN fn::ui::html(200, fn::ui::privacy_page());
};

DEFINE API OVERWRITE '/ui.css' FOR get THEN {
	RETURN { status: 200, headers: { 'content-type': 'text/css; charset=utf-8', 'cache-control': 'no-cache' }, body: fn::ui::css() };
};
