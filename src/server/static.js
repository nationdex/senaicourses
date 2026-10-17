import path from "node:path";

const PUBLIC_DIR = path.resolve(import.meta.dir, "../../public");
const DEV = process.env.NODE_ENV !== "production";

/** Serves files from public/ (assets, css, js). Returns null when nothing matches. */
export async function serveStatic(req) {
	const { pathname } = new URL(req.url);
	const file = path.resolve(PUBLIC_DIR, `.${decodeURIComponent(pathname)}`);
	if (!file.startsWith(`${PUBLIC_DIR}${path.sep}`)) return null; // path traversal
	const f = Bun.file(file);
	if (!(await f.exists())) return null;
	return new Response(f, {
		headers: { "Cache-Control": DEV ? "no-cache" : "public, max-age=3600" },
	});
}
