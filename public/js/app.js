// Page behavior: Alpine components (UI-only state: popovers, tilt, countdown)
// plus the few htmx hooks that tie server-rendered fragments together. All real
// state (selected state/área/unit, course data) lives on the server — every
// selection is an hx-get that returns HTML.
import { initStaticCursors, setWorking, watchAnimatedCursors } from "./cursors.js";

const html = document.documentElement;

initStaticCursors();
watchAnimatedCursors();

// ── Selection context ────────────────────────────────────────────────────────
// Server responses announce selection changes with an `HX-Trigger: {"ctx": …}`
// header. html[data-uf|data-area|data-hue] mirror the current selection.

document.addEventListener("ctx", (e) => {
	const { uf, area, hue } = e.detail ?? {};
	if (uf !== undefined) html.dataset.uf = uf;
	if (area !== undefined) html.dataset.area = area;
	if (hue !== undefined) {
		html.dataset.hue = hue;
		html.style.setProperty("--brand-hue", String(hue)); // transitions via @property
	}
});

// A slow response for a state/área the user has already left must not
// overwrite the newer selection.
const CHAINED = /^\/ui\/(areas|units|loading|content)$/;
document.addEventListener("htmx:beforeSwap", (e) => {
	const path = e.detail.pathInfo?.finalRequestPath;
	if (!path) return;
	const url = new URL(path, location.origin);
	if (!CHAINED.test(url.pathname)) return;
	const uf = url.searchParams.get("uf");
	const area = url.searchParams.get("area");
	// /ui/areas is what decides the área, so only the state can be stale for it.
	const checkArea = area && url.pathname !== "/ui/areas";
	if ((uf && uf !== html.dataset.uf) || (checkArea && area !== html.dataset.area)) {
		e.detail.shouldSwap = false;
	}
});

// ── "Working" cursor while course data is being fetched ─────────────────────

const root = () => document.querySelector(".aero-root");
let inflight = 0;
const isFetch = (e) =>
	CHAINED.test(new URL(e.detail.pathInfo?.requestPath ?? "", location.origin).pathname);

document.addEventListener("htmx:beforeRequest", (e) => {
	if (!isFetch(e)) return;
	inflight++;
	setWorking(root(), true);
});
document.addEventListener("htmx:afterRequest", (e) => {
	if (!isFetch(e)) return;
	inflight = Math.max(0, inflight - 1);
	if (inflight === 0) setWorking(root(), false);
});

// ── Helpers used from markup ─────────────────────────────────────────────────

window.localTime = (iso) =>
	new Date(iso).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" });

const prefetched = new Set();
/** Best-effort warm-up of a fragment (server cache + browser HTTP cache). */
function prefetch(url) {
	if (prefetched.has(url)) return;
	prefetched.add(url);
	setTimeout(() => prefetched.delete(url), 30_000);
	fetch(url, { priority: "low" }).catch(() => {});
}

// ── Alpine components ────────────────────────────────────────────────────────

document.addEventListener("alpine:init", () => {
	const Alpine = window.Alpine;
	const CloseMs = 160;

	// A popover panel is mounted (x-if="phase") only while open or animating
	// closed, so its backdrop-filter/shimmer cost is never paid at rest.
	const popoverBase = (init = {}) => ({
		open: false,
		phase: null,
		_timer: null,
		...init,
		toggle() {
			this.set(!this.open);
		},
		set(value) {
			this.open = value;
			clearTimeout(this._timer);
			if (value) {
				this.phase = "open";
			} else if (this.phase) {
				this.phase = "closing";
				this._timer = setTimeout(() => {
					this.phase = null;
				}, CloseMs);
			}
		},
		outside(e) {
			if (this.open && !this.$root.contains(e.target)) this.set(false);
		},
	});

	Alpine.data("popover", popoverBase);

	Alpine.data("unitSearch", (init) => ({
		...popoverBase(init),
		query: "",
		get needle() {
			return this.query.trim().toLowerCase();
		},
		get none() {
			const q = this.needle;
			if (!q) return false;
			return [...this.$root.querySelectorAll("[data-search]")].every(
				(li) => !li.dataset.search.includes(q),
			);
		},
		matches(li) {
			return !this.needle || li.dataset.search.includes(this.needle);
		},
		set(value) {
			popoverBase().set.call(this, value);
			if (!value) this.query = "";
		},
		openAndFocus() {
			this.set(true);
			this.$nextTick(() => this.$refs.input?.focus());
		},
		pickFirst() {
			const first = [...this.$root.querySelectorAll("[data-search]")].find((li) =>
				this.matches(li),
			);
			first?.querySelector("button")?.click();
		},
		pick(button) {
			this.selected = Number(button.dataset.id);
			this.label = button.dataset.name;
			this.set(false);
		},
		prefetch,
	}));

	// Mouse-follow 3D tilt (header, stat cards) — purely visual.
	Alpine.data("tilt", (strength = 10) => ({
		move(e) {
			const el = this.$root;
			const r = el.getBoundingClientRect();
			const x = (e.clientX - r.left) / r.width - 0.5;
			const y = (e.clientY - r.top) / r.height - 0.5;
			el.style.transform = `perspective(900px) rotateY(${x * strength}deg) rotateX(${-y * strength}deg) translateZ(6px)`;
			el.style.boxShadow = `
				0 0 0 1px oklch(0.65 0.08 var(--brand-hue) / 0.12) inset,
				0 1px 0 oklch(0.8 0.04 var(--brand-hue) / 0.15) inset,
				${-x * 8}px ${-y * 8}px 40px oklch(0.12 0.06 var(--brand-hue) / 0.7),
				0 0 50px oklch(0.4 0.18 var(--brand-hue) / 0.12)
			`;
		},
		leave() {
			this.$root.style.transform = "";
			this.$root.style.boxShadow = "";
		},
	}));

	// Continuous mouse-follow tilt + zoom for the clickable logo — rAF-batched so
	// rapid mousemove doesn't thrash layout, eased back to rest on leave.
	Alpine.data("logoTilt", (strength = 16, scale = 1.16) => ({
		rect: null,
		raf: null,
		pending: null,
		move(e) {
			if (!this.rect) this.rect = this.$root.getBoundingClientRect();
			this.pending = {
				x: (e.clientX - this.rect.left) / this.rect.width - 0.5,
				y: (e.clientY - this.rect.top) / this.rect.height - 0.5,
			};
			if (this.raf === null) {
				this.raf = requestAnimationFrame(() => {
					this.raf = null;
					const p = this.pending;
					if (!p) return;
					this.$root.style.transform = `perspective(600px) scale(${scale}) rotateY(${p.x * strength}deg) rotateX(${-p.y * strength}deg) translateZ(8px)`;
				});
			}
		},
		leave() {
			this.rect = null;
			this.pending = null;
			if (this.raf !== null) cancelAnimationFrame(this.raf);
			this.raf = null;
			this.$root.style.transform = "";
		},
	}));

	// "Próx. Refresh" card: counts down, then re-fetches #content (which replaces
	// this card, restarting the countdown from the server-configured interval).
	Alpine.data("countdown", (seconds, url) => ({
		left: seconds,
		timer: null,
		get label() {
			const m = Math.floor(this.left / 60);
			return `${m}:${String(this.left % 60).padStart(2, "0")}`;
		},
		init() {
			this.timer = setInterval(() => {
				if (!this.$root.isConnected) return clearInterval(this.timer);
				this.left -= 1;
				if (this.left <= 0) {
					this.left = seconds;
					window.htmx.ajax("GET", url, { target: "#content", swap: "innerHTML" });
				}
			}, 1000);
		},
		destroy() {
			clearInterval(this.timer);
		},
	}));
});
