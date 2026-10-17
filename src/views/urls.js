/** Query string for the selection triple every /ui/* endpoint takes. */
export function qs({ uf, area, unit }) {
	const p = new URLSearchParams({ uf });
	if (area) p.set("area", area);
	if (unit !== undefined && unit !== null) p.set("unit", String(unit));
	return p.toString();
}

export const contentUrl = (sel) => `/ui/content?${qs(sel)}`;
export const pageUrl = (sel) => `/?${qs(sel)}`;
