-- All 27 states (order = selector display order). Idempotent: re-running updates in place.
-- Status is the registry truth: the 19 states with a scraper are 'active'.
FOR $s IN [
	{ uf: "sp", name: "São Paulo", source_label: "sp.senai.br", status: "active", sort: 0 },
	{ uf: "sc", name: "Santa Catarina", source_label: "cursos.sesisenai.org.br", status: "active", sort: 1 },
	{ uf: "ac", name: "Acre", source_label: "senaiac.org.br", status: "coming-soon", sort: 2 },
	{ uf: "al", name: "Alagoas", source_label: "al.senai.br", status: "active", sort: 3 },
	{ uf: "am", name: "Amazonas", source_label: "fieam.org.br/senai", status: "coming-soon", sort: 4 },
	{ uf: "ap", name: "Amapá", source_label: "ap.senai.br", status: "coming-soon", sort: 5 },
	{ uf: "ba", name: "Bahia", source_label: "curtaduracaosenaiba.com.br", status: "coming-soon", sort: 6 },
	{ uf: "ce", name: "Ceará", source_label: "senai-ce.org.br", status: "active", sort: 7 },
	{ uf: "df", name: "Distrito Federal", source_label: "sistemafibra.org.br", status: "active", sort: 8 },
	{ uf: "es", name: "Espírito Santo", source_label: "tewbhv.vtexcommercestable.com.br", status: "active", sort: 9 },
	{ uf: "go", name: "Goiás", source_label: "tewbhv.vtexcommercestable.com.br", status: "active", sort: 10 },
	{ uf: "ma", name: "Maranhão", source_label: "futuro.digital/senai-ma", status: "active", sort: 11 },
	{ uf: "mg", name: "Minas Gerais", source_label: "fiemg.com.br", status: "active", sort: 12 },
	{ uf: "ms", name: "Mato Grosso do Sul", source_label: "tewbhv.vtexcommercestable.com.br", status: "active", sort: 13 },
	{ uf: "mt", name: "Mato Grosso", source_label: "senaimt.ind.br", status: "active", sort: 14 },
	{ uf: "pa", name: "Pará", source_label: "tewbhv.vtexcommercestable.com.br", status: "active", sort: 15 },
	{ uf: "pb", name: "Paraíba", source_label: "fiepb.com.br/senai", status: "coming-soon", sort: 16 },
	{ uf: "pe", name: "Pernambuco", source_label: "tewbhv.vtexcommercestable.com.br", status: "active", sort: 17 },
	{ uf: "pi", name: "Piauí", source_label: "tewbhv.vtexcommercestable.com.br", status: "active", sort: 18 },
	{ uf: "pr", name: "Paraná", source_label: "novo.senaipr.org.br", status: "active", sort: 19 },
	{ uf: "rj", name: "Rio de Janeiro", source_label: "firjansenai.com.br", status: "coming-soon", sort: 20 },
	{ uf: "rn", name: "Rio Grande do Norte", source_label: "tewbhv.vtexcommercestable.com.br", status: "active", sort: 21 },
	{ uf: "rs", name: "Rio Grande do Sul", source_label: "cursos.senairs.org.br", status: "active", sort: 22 },
	{ uf: "ro", name: "Rondônia", source_label: "tewbhv.vtexcommercestable.com.br", status: "active", sort: 23 },
	{ uf: "rr", name: "Roraima", source_label: "rr.senai.br", status: "coming-soon", sort: 24 },
	{ uf: "se", name: "Sergipe", source_label: "se.senai.br", status: "coming-soon", sort: 25 },
	{ uf: "to", name: "Tocantins", source_label: "cursos.senai-to.com.br", status: "active", sort: 26 },
] {
	UPSERT type::record('state', $s.uf) CONTENT $s;
};
