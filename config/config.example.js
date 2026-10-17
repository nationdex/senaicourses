// Copie este arquivo para config.ts e ajuste os valores desejados.
// Todos os valores exibidos são os padrões — só altere o que precisar mudar.
// Qualquer valor pode ser sobrescrito por variável de ambiente.

export const config = {
	// ── Servidor ─────────────────────────────────────────────────────────────────
	// Porta em que o servidor HTTP vai escutar.
	// Equivalente: PORT=8080 bun start
	port: Number(process.env.PORT ?? 3010),

	// Interface de rede. "0.0.0.0" aceita conexões externas; "127.0.0.1" apenas locais.
	host: process.env.HOST ?? "0.0.0.0",

	// ── SurrealDB embarcado ───────────────────────────────────────────────────────
	// O servidor sobe o binário `surreal` (https://surrealdb.com/install) como
	// processo filho, com armazenamento SurrealKV em disco, e fala SurrealQL com
	// ele por HTTP. Sem o binário o site segue funcionando só com o cache em
	// memória (sem persistência entre reinícios).
	// Equivalente: SURREAL_STORAGE=surrealkv:///app/data/senai.kv
	surrealStorage: process.env.SURREAL_STORAGE ?? "surrealkv://./data/senai.kv",

	// Caminho do binário `surreal`.
	surrealBin: process.env.SURREAL_BIN ?? "surreal",

	// Endereço local do SurrealDB (use sempre loopback) e credenciais do root.
	// Troque a senha se a máquina for compartilhada.
	surrealBind: process.env.SURREAL_BIND ?? "127.0.0.1:8000",
	surrealUser: process.env.SURREAL_USER ?? "root",
	surrealPass: process.env.SURREAL_PASS ?? "root",

	// false = não sobe o processo; conecta num SurrealDB que já esteja rodando em surrealBind.
	surrealAutostart: (process.env.SURREAL_AUTOSTART ?? "true") !== "false",

	// ── Cache ─────────────────────────────────────────────────────────────────────
	// Por quanto tempo o catálogo (todos os pares curso × unidade) fica em cache.
	// Aumentar reduz a carga no SENAI; diminuir garante dados mais frescos.
	// Equivalente: CATALOG_TTL_MS=3600000  (1 hora)
	catalogTtlMs: Number(process.env.CATALOG_TTL_MS ?? 2 * 60 * 60 * 1000), // padrão: 2 h

	// Por quanto tempo os dados de turmas de cada unidade ficam em cache.
	// Equivalente: UNIT_TTL_MS=900000  (15 minutos)
	unitTtlMs: Number(process.env.UNIT_TTL_MS ?? 30 * 60 * 1000), // padrão: 30 min

	// ── Requisições HTTP ──────────────────────────────────────────────────────────
	// Timeout por requisição em milissegundos. Aumente se o SENAI estiver lento.
	// Equivalente: FETCH_TIMEOUT_MS=20000
	fetchTimeoutMs: Number(process.env.FETCH_TIMEOUT_MS ?? 12_000), // padrão: 12 s

	// Número de tentativas antes de desistir de uma requisição com falha.
	// O backoff é exponencial: 300 ms · 2^tentativa entre cada retry.
	// Equivalente: MAX_RETRIES=5
	maxRetries: Number(process.env.MAX_RETRIES ?? 3),

	// ── Concorrência ──────────────────────────────────────────────────────────────
	// Quantas páginas do catálogo são baixadas em paralelo durante buildCatalog().
	// Reduza se estiver recebendo erros de rate-limit do SENAI.
	// Equivalente: CATALOG_CONCURRENCY=6
	catalogConcurrency: Number(process.env.CATALOG_CONCURRENCY ?? 12),

	// Quantas requisições de turmas são disparadas em paralelo por unidade.
	// Equivalente: TURMAS_CONCURRENCY=6
	turmasConcurrency: Number(process.env.TURMAS_CONCURRENCY ?? 12),

	// Quantas unidades são pré-aquecidas simultaneamente na inicialização.
	// Reduzir diminui a carga inicial no SENAI; aumentar acelera o warmup.
	// Equivalente: WARMUP_CONCURRENCY=3
	warmupConcurrency: Number(process.env.WARMUP_CONCURRENCY ?? 6),

	// ── Interface (frontend) ──────────────────────────────────────────────────────
	// ID da unidade pré-selecionada quando o site carrega pela primeira vez.
	// 403 = Alumínio · 499 = Mairinque  (consulte /api/units para ver todas)
	// Equivalente: DEFAULT_UNIT_ID=499
	defaultUnitId: Number(process.env.DEFAULT_UNIT_ID ?? 403),

	// Intervalo de auto-refresh em segundos (exibido como contagem regressiva na UI).
	// Equivalente: REFRESH_INTERVAL_SECONDS=120
	refreshIntervalSeconds: Number(process.env.REFRESH_INTERVAL_SECONDS ?? 300), // padrão: 5 min
};
