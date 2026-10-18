-- Static assets (flags, logo) served from a file bucket backed by app/assets.
-- The container/process must allow the folder: SURREAL_BUCKET_FOLDER_ALLOWLIST=/assets
-- with app/assets mounted read-only at /assets (run.sh does both).
DEFINE BUCKET OVERWRITE assets BACKEND 'file:/assets' PERMISSIONS FULL;

DEFINE FUNCTION OVERWRITE fn::assets::mime($name: string) -> string {
	RETURN IF string::ends_with($name, '.png') { 'image/png' }
	ELSE IF string::ends_with($name, '.svg') { 'image/svg+xml' }
	ELSE IF string::ends_with($name, '.webp') { 'image/webp' }
	ELSE IF string::ends_with($name, '.jpg') OR string::ends_with($name, '.jpeg') { 'image/jpeg' }
	ELSE IF string::ends_with($name, '.ico') { 'image/x-icon' }
	ELSE { 'application/octet-stream' };
};

-- Serves GET {base}/assets/<path...>. Every segment must match [a-z0-9_-][a-z0-9._-]*
-- (no dots-first, no slashes), at most 4 segments, so nothing escapes the bucket.
DEFINE API OVERWRITE '/assets/*path' FOR get THEN {
	LET $rel = array::join($request.params.path ?? [], '/');
	LET $ok = string::matches($rel, /^[a-z0-9_-][a-z0-9._-]*(\/[a-z0-9_-][a-z0-9._-]*){0,3}$/);
	LET $bytes = IF $ok { type::file('assets', '/' + $rel).get() } ELSE { NONE };
	IF $bytes = NONE {
		RETURN { status: 404, headers: { 'content-type': 'text/plain; charset=utf-8' }, body: 'not found' };
	};
	RETURN {
		status: 200,
		headers: {
			'content-type': fn::assets::mime($rel),
			'cache-control': 'public, max-age=86400'
		},
		body: $bytes
	};
};
