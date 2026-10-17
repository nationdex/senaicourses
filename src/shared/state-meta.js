/** Single source of truth for every state's cosmetic/static info: display name,
 * logo and flag URLs (served from public/assets), brand hue, and a fallback
 * sourceLabel domain. Deliberately free of any adapter/db/config import so both
 * the views and the registry can use it. Real "active vs coming-soon" status is
 * server truth (see adapters/registry.js). */
export const STATE_META = {
	sp: {
		name: "São Paulo",
		logo: "/assets/logo.svg",
		flag: "/assets/sp.png",
		hue: 20,
		sourceLabel: "sp.senai.br",
	},
	sc: {
		name: "Santa Catarina",
		logo: "/assets/sc-senai.png",
		flag: "/assets/sc.png",
		hue: 145,
		sourceLabel: "cursos.sesisenai.org.br",
	},
	ac: {
		name: "Acre",
		logo: "/assets/ac-senai.png",
		flag: "/assets/ac.png",
		hue: 55,
		sourceLabel: "senaiac.org.br",
	},
	al: {
		name: "Alagoas",
		logo: "/assets/al-senai.png",
		flag: "/assets/al.png",
		hue: 300,
		sourceLabel: "al.senai.br",
	},
	am: {
		name: "Amazonas",
		logo: "/assets/am-senai.png",
		flag: "/assets/am.png",
		hue: 15,
		sourceLabel: "fieam.org.br/senai",
	},
	ap: {
		name: "Amapá",
		logo: "/assets/ap-senai.png",
		flag: "/assets/ap.png",
		hue: 130,
		sourceLabel: "ap.senai.br",
	},
	ba: {
		name: "Bahia",
		logo: "/assets/bh-senai.png",
		flag: "/assets/bh.png",
		hue: 30,
		sourceLabel: "curtaduracaosenaiba.com.br",
	},
	ce: {
		name: "Ceará",
		logo: "/assets/ce-senai.png",
		flag: "/assets/ce.png",
		hue: 90,
		sourceLabel: "senai-ce.org.br",
	},
	df: {
		name: "Distrito Federal",
		logo: "/assets/df-senai.png",
		flag: "/assets/df.png",
		hue: 110,
		sourceLabel: "cursos.senaidf.org.br",
	},
	es: {
		name: "Espírito Santo",
		logo: "/assets/es-senai.png",
		flag: "/assets/es.png",
		hue: 350,
		sourceLabel: "senaies.com.br",
	},
	go: {
		name: "Goiás",
		logo: "/assets/go-senai.png",
		flag: "/assets/go.png",
		hue: 100,
		sourceLabel: "senaigoias.com.br",
	},
	ma: {
		name: "Maranhão",
		logo: "/assets/ma-senai.png",
		flag: "/assets/ma.png",
		hue: 340,
		sourceLabel: "futuro.digital/senai-ma",
	},
	mg: {
		name: "Minas Gerais",
		logo: "/assets/mg-senai.png",
		flag: "/assets/mg.png",
		hue: 20,
		sourceLabel: "fiemg.com.br",
	},
	ms: {
		name: "Mato Grosso do Sul",
		logo: "/assets/ms-senai.png",
		flag: "/assets/ms.png",
		hue: 215,
		sourceLabel: "ms.senai.br",
	},
	mt: {
		name: "Mato Grosso",
		logo: "/assets/mt-senai.png",
		flag: "/assets/mt.png",
		hue: 270,
		sourceLabel: "senaimt.ind.br",
	},
	pa: {
		name: "Pará",
		logo: "/assets/pa-senai.png",
		flag: "/assets/pa.png",
		hue: 355,
		sourceLabel: "senaipa.org.br",
	},
	pb: {
		name: "Paraíba",
		logo: "/assets/pb-senai.png",
		flag: "/assets/pb.png",
		hue: 5,
		sourceLabel: "fiepb.com.br/senai",
	},
	pe: {
		name: "Pernambuco",
		logo: "/assets/pe-senai.png",
		flag: "/assets/pe.png",
		hue: 258,
		sourceLabel: "pe.senai.br",
	},
	pi: {
		name: "Piauí",
		logo: "/assets/pi-senai.png",
		flag: "/assets/pi.png",
		hue: 175,
		sourceLabel: "fiepi.com.br",
	},
	pr: {
		name: "Paraná",
		logo: "/assets/pr-senai.png",
		flag: "/assets/pr.png",
		hue: 195,
		sourceLabel: "novo.senaipr.org.br",
	},
	rj: {
		name: "Rio de Janeiro",
		logo: "/assets/rj-senai.png",
		flag: "/assets/rj.png",
		hue: 248,
		sourceLabel: "firjansenai.com.br",
	},
	rn: {
		name: "Rio Grande do Norte",
		logo: "/assets/rn-senai.png",
		flag: "/assets/rn.png",
		hue: 265,
		sourceLabel: "rn.senai.br",
	},
	rs: {
		name: "Rio Grande do Sul",
		logo: "/assets/rs-senai.png",
		flag: "/assets/rs.png",
		hue: 155,
		sourceLabel: "cursos.senairs.org.br",
	},
	ro: {
		name: "Rondônia",
		logo: "/assets/ro-senai.png",
		flag: "/assets/ro.png",
		hue: 160,
		sourceLabel: "portal.fiero.org.br/senai",
	},
	rr: {
		name: "Roraima",
		logo: "/assets/rr-senai.png",
		flag: "/assets/rr.png",
		hue: 75,
		sourceLabel: "rr.senai.br",
	},
	se: {
		name: "Sergipe",
		logo: "/assets/se-senai.png",
		flag: "/assets/se.png",
		hue: 45,
		sourceLabel: "se.senai.br",
	},
	to: {
		name: "Tocantins",
		logo: "/assets/to-senai.png",
		flag: "/assets/to.png",
		hue: 185,
		sourceLabel: "senai-to.com.br",
	},
};

/** Selector display order — SP and SC first (longest-running live adapters), then
 * alphabetical. Drives both the backend's /api/states response and the frontend
 * selector directly (see homePage in views/pages/home.js). */
export const STATE_ORDER = Object.keys(STATE_META);

/** First-paint hint only, so SP doesn't flash "coming soon" before /api/states
 * resolves (same-origin, near-instant, but not synchronous). The real status
 * always comes from the server — see ADAPTERS in adapters/registry.js, which is
 * the actual source of truth and must be kept in sync with this list. */
export const KNOWN_ACTIVE = [
	"sp",
	"sc",
	"al",
	"rs",
	"ma",
	"mg",
	"ms",
	"go",
	"to",
	"pi",
	"ro",
	"ce",
	"mt",
	"df",
	"pr",
	"es",
	"pa",
	"pe",
	"rn",
];
