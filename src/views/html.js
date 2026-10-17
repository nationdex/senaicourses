// Tiny HTML templating: `html` tagged templates escape every interpolated value
// unless it is already Safe (output of another `html` call, `raw()`, or an
// array of those). Views are plain functions returning Safe strings.

class Safe {
	/** @param {string} value */
	constructor(value) {
		this.value = value;
	}
	toString() {
		return this.value;
	}
}

const ESCAPES = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };

/** @param {unknown} value */
export function esc(value) {
	return String(value ?? "").replace(/[&<>"']/g, (c) => ESCAPES[c]);
}

/** Mark trusted markup (icons, JSON for attributes) as already safe. */
export function raw(value) {
	return new Safe(String(value));
}

function render(value) {
	if (value instanceof Safe) return value.value;
	if (Array.isArray(value)) return value.map(render).join("");
	if (value === false || value === null || value === undefined) return "";
	return esc(value);
}

export function html(strings, ...values) {
	let out = strings[0];
	for (let i = 0; i < values.length; i++) out += render(values[i]) + strings[i + 1];
	return new Safe(out);
}

/** Join class names, dropping falsy entries. */
export function cx(...parts) {
	return parts.filter(Boolean).join(" ");
}

/** JSON for an Alpine/htmx attribute value (double-quoted attribute, so fully escaped). */
export function jsonAttr(value) {
	return raw(esc(JSON.stringify(value)));
}
