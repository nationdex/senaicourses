DEFINE API OVERWRITE '/health' FOR get THEN {
	RETURN {
		status: 200,
		headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
		body: '{"ok":true,"time":"' + <string> time::now() + '"}'
	};
};
