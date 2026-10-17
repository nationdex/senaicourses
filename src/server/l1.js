// Short-lived in-memory response cache for GET handlers. Identical requests
// inside the window (several clients polling the same unit, prefetch + click)
// are answered from memory instead of re-running the render.

const TTL_MS = 5_000;
const MAX_ENTRIES = 500;

/** @type {Map<string, { body: ArrayBuffer, status: number, headers: [string, string][], ts: number }>} */
const cache = new Map();

/** @param {(req: Request) => Promise<Response> | Response} handler */
export function l1(handler) {
	return async (req) => {
		const key = req.url;
		const hit = cache.get(key);
		if (hit && Date.now() - hit.ts <= TTL_MS) {
			return new Response(hit.body.slice(0), { status: hit.status, headers: hit.headers });
		}
		const res = await handler(req);
		if (res.status === 200) {
			const body = await res.clone().arrayBuffer();
			cache.set(key, { body, status: res.status, headers: [...res.headers], ts: Date.now() });
			if (cache.size > MAX_ENTRIES) {
				const oldest = [...cache.entries()].sort((a, b) => a[1].ts - b[1].ts)[0];
				if (oldest) cache.delete(oldest[0]);
			}
		}
		return res;
	};
}
