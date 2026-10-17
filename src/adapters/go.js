import { config } from "../../config/config.js";
import { dbUpsertCourses, dbUpsertUnit } from "../db/index.js";
import { getJson, slugify } from "./http.js";
import { KeyedAsyncCache } from "./keyed-cache.js";

const UF = "go";
// SENAI-GO's real commerce catalog runs on a VTEX account ("tewbhv") shared by
// several "futuro.digital" states — same backend behind ma.js's Vercel micro-app
// (its images are served from the same tewbhv.vteximg.com.br host). The classic
// VTEX legacy search REST API is public, no auth required:
//   https://tewbhv.vtexcommercestable.com.br/api/catalog_system/pub/products/search
// GO's own products are tagged into four state-specific clusters, discovered by
// inspecting productClusters on any GO product returned by that search:
const CLUSTER_IDS = [550, 551, 553, 554]; // profissionalizantes, técnicos, presenciais, ead
const SEARCH_BASE =
	"https://tewbhv.vtexcommercestable.com.br/api/catalog_system/pub/products/search";
const PAGE_SIZE = 50;
const VTEX_TIMEOUT_MS = 30_000; // these pages can run past the default fetch timeout
// Every GO product carries a real "Área Tecnológica" specification field — used
// here to tag EVERY product into its real category, not just T.I. It isn't
// perfectly clean, though: manual audit during development found "Técnico em
// Vestuário" (a fashion/textile course) mistagged as "Tecnologia da Informação"
// despite its own category path saying "Demais Áreas" — IT_MISTAG_KEYWORDS is a
// small override for exactly that kind of source data error.
const IT_AREA = "Tecnologia da Informação";
const IT_MISTAG_KEYWORDS = /vestu[aá]rio|confec[çc][ãa]o de roupas|t[êe]xtil|\bmoda\b/i;
const cityIdByName = new Map();
let nextCityId = 1;
function getCityId(name) {
	let id = cityIdByName.get(name);
	if (id === undefined) {
		id = nextCityId++;
		cityIdByName.set(name, id);
	}
	return id;
}
async function fetchCluster(clusterId) {
	const all = [];
	for (let from = 0; from < 500; from += PAGE_SIZE) {
		const to = from + PAGE_SIZE - 1;
		const page = await getJson(
			`${SEARCH_BASE}?fq=productClusterIds:${clusterId}&_from=${from}&_to=${to}`,
			VTEX_TIMEOUT_MS,
		);
		if (!page || page.length === 0) break;
		all.push(...page);
		if (page.length < PAGE_SIZE) break;
	}
	return all;
}
function resolveArea(p) {
	const area = p["Área Tecnológica"]?.[0];
	if (!area) return null;
	if (area === IT_AREA && IT_MISTAG_KEYWORDS.test(p.productName)) return null;
	return area;
}
function formatPrice(price) {
	if (!price) return [];
	return [`R$ ${price.toFixed(2).replace(".", ",")}`];
}
function buildEntries(products) {
	const entries = [];
	for (const p of products) {
		const areaLabel = resolveArea(p);
		if (!areaLabel) continue;
		const areaSlug = slugify(areaLabel);
		const hoursRaw = p["Carga Horária"]?.[0];
		const hours = hoursRaw ? parseInt(hoursRaw, 10) : 0;
		for (const item of p.items ?? []) {
			const offer = item.sellers?.[0]?.commertialOffer;
			if (!offer?.IsAvailable) continue;
			const cityName = item.Cidade?.[0];
			if (!cityName) continue;
			const periodo = item.Turno?.[0] ?? "";
			const prices = formatPrice(offer.Price);
			entries.push({
				cityId: getCityId(cityName),
				cityName,
				areaSlug,
				areaLabel,
				isPaid: prices.length > 0,
				course: {
					name: p.productName,
					slug: p.linkText,
					id: parseInt(item.itemId, 10),
					hours,
					vagas: null,
					turmas: 1,
					startDates: [],
					schedules: periodo ? [{ periodo, horario: item["Dia da Semana"]?.[0] ?? "" }] : [],
					prices,
					isBolsa: false,
					url: p.link,
				},
			});
		}
	}
	return entries;
}
async function buildCatalog() {
	const perCluster = await Promise.all(CLUSTER_IDS.map(fetchCluster));
	const byId = new Map();
	for (const products of perCluster) {
		for (const p of products) byId.set(p.productId, p);
	}
	const entries = buildEntries([...byId.values()]);
	console.log(
		`[go] ${entries.length} oferta(s) em ${new Set(entries.map((e) => e.areaSlug)).size} área(s) de ${byId.size} produto(s) totais nos clusters`,
	);
	return entries;
}
// isEmpty guard: an empty result almost always means a transient VTEX fetch
// failure across all 4 clusters, not that GO genuinely has zero products — see
// KeyedAsyncCache's doc comment. GO builds its whole (small, ~100-product)
// catalog in one shot rather than per-área, so there's only one cache key here.
const catalogCache = new KeyedAsyncCache(config.catalogTtlMs, (v) => v.length === 0);
const getCatalog = () => catalogCache.get("all", buildCatalog);
async function getUnits() {
	const entries = await getCatalog();
	const seen = new Map();
	for (const e of entries) if (!seen.has(e.cityId)) seen.set(e.cityId, e.cityName);
	const units = [...seen.entries()]
		.map(([id, name]) => ({ id, name }))
		.sort((a, b) => a.name.localeCompare(b.name, "pt-BR"));
	for (const u of units) dbUpsertUnit(UF, u).catch(() => {});
	return units;
}
async function getAreas() {
	const entries = await getCatalog();
	const seen = new Map();
	for (const e of entries) if (!seen.has(e.areaSlug)) seen.set(e.areaSlug, e.areaLabel);
	return [...seen.entries()]
		.map(([slug, label]) => ({ slug, label }))
		.sort((a, b) => a.label.localeCompare(b.label, "pt-BR"));
}
async function getCatalogUnitIds(areaSlug) {
	const entries = await getCatalog();
	return [...new Set(entries.filter((e) => e.areaSlug === areaSlug).map((e) => e.cityId))];
}
async function getUnitData(unitId, areaSlug, _force = false) {
	const entries = await getCatalog();
	const courses = entries
		.filter((e) => e.cityId === unitId && e.areaSlug === areaSlug && !e.isPaid)
		.map((e) => e.course)
		.sort((a, b) => a.name.localeCompare(b.name, "pt-BR"));
	if (courses.length) dbUpsertCourses(UF, areaSlug, unitId, courses, false).catch(() => {});
	return { courses, lastUpdated: new Date().toISOString() };
}
async function getUnitPaidData(unitId, areaSlug, _force = false) {
	const entries = await getCatalog();
	const courses = entries
		.filter((e) => e.cityId === unitId && e.areaSlug === areaSlug && e.isPaid)
		.map((e) => e.course)
		.sort((a, b) => a.name.localeCompare(b.name, "pt-BR"));
	if (courses.length) dbUpsertCourses(UF, areaSlug, unitId, courses, true).catch(() => {});
	return { courses, lastUpdated: new Date().toISOString() };
}
export const goAdapter = {
	uf: UF,
	sourceLabel: "tewbhv.vtexcommercestable.com.br",
	getUnits,
	getAreas,
	getCatalogUnitIds,
	getUnitData,
	getUnitPaidData,
};
