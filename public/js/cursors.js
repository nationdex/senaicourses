// Windows "Aero Cursors" pack. `.cur` files are used natively as static CSS
// cursors; `.ani` has no CSS support, so ani-cursor (the library Webamp uses
// for Winamp skins) decodes the real frames and drives `cursor` through a
// discrete @keyframes animation, feeding the browser each frame's raw .cur
// bytes. See css/aero.css for how the static roles are applied.
import { convertAniBinaryToCSS } from "https://cdn.jsdelivr.net/npm/ani-cursor@2.3.1/+esm";
import { aniClass, aniUrl, hueToCursorColor } from "./cursor-color.js";

const CUR = "/assets/cursors";
export const ARROW = `url(${CUR}/Arrow.cur), auto`;

/** Sets the custom properties every static cursor role in aero.css reads. */
export function initStaticCursors() {
	const root = document.documentElement.style;
	const roles = {
		arrow: ["Arrow", "auto"],
		pointer: ["Hand", "pointer"],
		text: ["Text", "text"],
		help: ["Help", "help"],
		move: ["Move", "move"],
		crosshair: ["Cross", "crosshair"],
		alias: ["Up", "alias"],
		// Cursor-scheme slot order (see the pack's .inf): vert/horz are the
		// straight resize handles, dgn1/dgn2 the two diagonals.
		"ns-resize": ["Resize3", "ns-resize"],
		"ew-resize": ["Resize1", "ew-resize"],
		"nwse-resize": ["Resize4", "nwse-resize"],
		"nesw-resize": ["Resize2", "nesw-resize"],
	};
	for (const [role, [file, fallback]] of Object.entries(roles)) {
		root.setProperty(`--cursor-${role}`, `url(${CUR}/${file}.cur), ${fallback}`);
	}
}

// One <style> per animated cursor the page actually needs, injected the first
// time it is needed.
const injected = new Set();

function ensureAni(className, url) {
	if (injected.has(className)) return;
	injected.add(className);
	fetch(url)
		.then((res) => res.arrayBuffer())
		.then((buf) => {
			const style = document.createElement("style");
			style.dataset.aniCursor = className;
			style.textContent = convertAniBinaryToCSS(`.${className}`, new Uint8Array(buf));
			document.head.appendChild(style);
		})
		.catch(() => injected.delete(className));
}

/** Loads whatever `data-ani="busy-red"` / `data-ani="wagtail"` elements need. */
function loadFor(el) {
	const spec = el.dataset.ani;
	if (!spec) return;
	if (spec === "wagtail") return ensureAni("cursor-wagtail", `${CUR}/Wagtail.ani`);
	const [category, color] = spec.split("-");
	ensureAni(aniClass(category, color), aniUrl(category, color));
}

export function watchAnimatedCursors() {
	const scan = (node) => {
		if (node.nodeType !== 1) return;
		if (node.dataset?.ani) loadFor(node);
		for (const el of node.querySelectorAll?.("[data-ani]") ?? []) loadFor(el);
	};
	scan(document.documentElement);
	new MutationObserver((records) => {
		for (const r of records) for (const n of r.addedNodes) scan(n);
	}).observe(document.documentElement, { childList: true, subtree: true });
}

/** Pointer + trailing ring while data is being fetched; plain arrow otherwise.
 * Inline `style` always beats a class, so the arrow is only set when idle. */
export function setWorking(root, on) {
	const color = hueToCursorColor(Number(document.documentElement.dataset.hue ?? 20));
	const cls = aniClass("working", color);
	for (const c of [...root.classList])
		if (c.startsWith("cursor-working-")) root.classList.remove(c);
	if (on) {
		ensureAni(cls, aniUrl("working", color));
		root.classList.add(cls);
		root.style.cursor = "";
	} else {
		root.style.cursor = ARROW;
	}
}
