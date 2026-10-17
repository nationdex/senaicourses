// SurrealDB lifecycle + a minimal SurrealQL-over-HTTP client (no SDK, no
// package manager). The `surreal` binary runs as a child process with SurrealKV
// storage; queries go to its JSON-RPC HTTP endpoint.
import { config } from "../../config/config.js";

const NAMESPACE = "senai";
const DATABASE = "cursos";

const base = `http://${config.surrealBind}`;
const auth = `Basic ${btoa(`${config.surrealUser}:${config.surrealPass}`)}`;

/** @type {import("bun").Subprocess | null} */
let child = null;

async function healthy() {
	try {
		const res = await fetch(`${base}/health`, { signal: AbortSignal.timeout(1000) });
		return res.ok;
	} catch {
		return false;
	}
}

function stopChild() {
	child?.kill();
	child = null;
}

/** Starts (or attaches to) SurrealDB. Throws if it cannot be reached. */
export async function startSurreal() {
	if (!(await healthy())) {
		if (!config.surrealAutostart) {
			throw new Error(`SurrealDB não está rodando em ${config.surrealBind}`);
		}
		try {
			child = Bun.spawn(
				[
					config.surrealBin,
					"start",
					"--log",
					"warn",
					"--bind",
					config.surrealBind,
					"--user",
					config.surrealUser,
					"--pass",
					config.surrealPass,
					config.surrealStorage,
				],
				{ stdout: "inherit", stderr: "inherit" },
			);
		} catch (err) {
			throw new Error(
				`não foi possível iniciar "${config.surrealBin}" (${err.code ?? err.message}) — instale em https://surrealdb.com/install`,
			);
		}
		for (const sig of ["exit", "SIGINT", "SIGTERM"]) {
			process.on(sig, () => {
				stopChild();
				if (sig !== "exit") process.exit(0);
			});
		}
		for (let i = 0; i < 50 && !(await healthy()); i++) {
			if (child.exitCode !== null) throw new Error(`surreal encerrou (código ${child.exitCode})`);
			await Bun.sleep(200);
		}
		if (!(await healthy())) throw new Error("SurrealDB não respondeu a tempo");
	}
}

/**
 * Runs SurrealQL. Returns one result per statement.
 * @param {string} sql
 * @param {Record<string, unknown>} [vars]
 */
export async function query(sql, vars = {}) {
	const res = await fetch(`${base}/rpc`, {
		method: "POST",
		headers: {
			Accept: "application/json",
			"Content-Type": "application/json",
			Authorization: auth,
			"Surreal-NS": NAMESPACE,
			"Surreal-DB": DATABASE,
		},
		body: JSON.stringify({ id: 1, method: "query", params: [sql, vars] }),
		signal: AbortSignal.timeout(30_000),
	});
	if (!res.ok) throw new Error(`SurrealDB HTTP ${res.status}: ${await res.text()}`);
	const body = await res.json();
	if (body.error) throw new Error(`SurrealDB: ${body.error.message}`);
	const out = [];
	for (const stmt of body.result) {
		if (stmt.status !== "OK") throw new Error(`SurrealDB: ${stmt.result}`);
		out.push(stmt.result);
	}
	return out;
}
