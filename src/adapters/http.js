import { config } from "../../config/config.js";
export function decodeEntities(str) {
	return str
		.replace(/&#x([0-9A-Fa-f]+);/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)))
		.replace(/&#(\d+);/g, (_, dec) => String.fromCharCode(parseInt(dec, 10)))
		.replace(/&amp;/g, "&")
		.replace(/&lt;/g, "<")
		.replace(/&gt;/g, ">")
		.replace(/&quot;/g, '"')
		.replace(/&apos;/g, "'")
		.replace(/<[^>]+>/g, "")
		.trim();
}
// Stable, URL/DB-safe identifier from a display name, e.g. "Tecnologia da
// Informação" → "tecnologia-da-informacao". Used to derive Area.slug values.
export function slugify(name) {
	return name
		.normalize("NFD")
		.replace(/[̀-ͯ]/g, "")
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, "-")
		.replace(/^-+|-+$/g, "");
}
// Run up to `limit` tasks at once; returns results in input order.
export async function withConcurrency(tasks, limit) {
	const results = new Array(tasks.length);
	let idx = 0;
	async function worker() {
		while (idx < tasks.length) {
			const i = idx++;
			const task = tasks[i];
			if (task) results[i] = await task();
		}
	}
	await Promise.all(Array.from({ length: Math.min(limit, tasks.length) }, worker));
	return results;
}
// Retry an async task up to `retries` times with exponential backoff.
export async function withRetry(fn, retries = config.maxRetries) {
	let lastErr;
	for (let attempt = 0; attempt <= retries; attempt++) {
		try {
			return await fn();
		} catch (err) {
			lastErr = err;
			if (attempt < retries) await Bun.sleep(300 * 2 ** attempt);
		}
	}
	throw lastErr;
}
export async function get(url, timeoutMs = config.fetchTimeoutMs) {
	return withRetry(async () => {
		const res = await fetch(url, {
			headers: { "User-Agent": "Mozilla/5.0 (compatible; SENAI-Monitor)" },
			signal: AbortSignal.timeout(timeoutMs),
		});
		return res.ok ? res.text() : "";
	}).catch(() => "");
}
export async function postForm(url, body, timeoutMs = config.fetchTimeoutMs) {
	return withRetry(async () => {
		const res = await fetch(url, {
			method: "POST",
			headers: {
				"User-Agent": "Mozilla/5.0 (compatible; SENAI-Monitor)",
				"Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
				"X-Requested-With": "XMLHttpRequest",
			},
			body,
			signal: AbortSignal.timeout(timeoutMs),
		});
		return res.ok ? res.text() : "";
	}).catch(() => "");
}
export async function getJson(url, timeoutMs = config.fetchTimeoutMs) {
	return withRetry(async () => {
		const res = await fetch(url, {
			headers: {
				"User-Agent": "Mozilla/5.0 (compatible; SENAI-Monitor)",
				accept: "application/json",
			},
			signal: AbortSignal.timeout(timeoutMs),
		});
		return res.ok ? await res.json() : null;
	}).catch(() => null);
}
