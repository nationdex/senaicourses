// Shared by the server (views pick cursor classes) and the browser (js/cursors.js
// loads the matching .ani file). Browser-safe: no imports, no server APIs.

/** @typedef {"red"|"yellow"|"green"|"blue"|"purple"|"pink"|"silver"} CursorColor */

// Hue bands (0-360, matching STATE_META's `hue`) mapped to the closest Aero pack
// color, so a state's cursor color tracks its own brand hue. Full 360° coverage,
// six ~60°-wide bands centered on each color's natural position on the wheel —
// "silver" is an unreachable fallback, never a band of its own.
// Red is centered near hue 20 so SP (20) and MG (20) land there.
const BANDS = [
	{ min: 350, max: 360, color: "red" },
	{ min: 0, max: 50, color: "red" },
	{ min: 50, max: 110, color: "yellow" },
	{ min: 110, max: 170, color: "green" },
	{ min: 170, max: 230, color: "blue" },
	{ min: 230, max: 290, color: "purple" },
	{ min: 290, max: 350, color: "pink" },
];

/** @param {number} hue @returns {CursorColor} */
export function hueToCursorColor(hue) {
	const h = ((hue % 360) + 360) % 360;
	return BANDS.find((b) => h >= b.min && h < b.max)?.color ?? "silver";
}

/** CSS class ani-cursor generates for a category+color, e.g. "cursor-busy-red". */
export function aniClass(category, color) {
	return `cursor-${category}-${color}`;
}

/** Public URL of the animated cursor file. */
export function aniUrl(category, color) {
	return `/assets/cursors/${category}/${color[0].toUpperCase()}${color.slice(1)}.ani`;
}
