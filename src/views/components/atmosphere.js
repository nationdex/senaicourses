import { html } from "../html.js";

// Fixed, deterministic bubble presets — hand-picked, not Math.random() — so the
// markup is identical on every render. Each only ever animates transform/opacity
// via CSS (see .aero-bubble in css/aero.css), so this whole layer is compositor-only.
const BUBBLES = [
	{ left: "6%", size: "16px", duration: "22s", delay: "0s", drift: "24px" },
	{ left: "16%", size: "10px", duration: "17s", delay: "3s", drift: "-18px" },
	{ left: "28%", size: "26px", duration: "27s", delay: "1s", drift: "34px" },
	{ left: "41%", size: "13px", duration: "20s", delay: "6s", drift: "-22px" },
	{ left: "55%", size: "20px", duration: "24s", delay: "2s", drift: "16px" },
	{ left: "68%", size: "9px", duration: "16s", delay: "8s", drift: "-14px" },
	{ left: "80%", size: "24px", duration: "29s", delay: "4s", drift: "28px" },
	{ left: "91%", size: "14px", duration: "19s", delay: "5.5s", drift: "-20px" },
];

export function atmosphere() {
	return html`
	<div class="aero-bg-glow"></div>
	<div class="aero-orb aero-orb-1"></div>
	<div class="aero-orb aero-orb-2"></div>
	<div class="aero-orb aero-orb-3"></div>
	<div class="aero-rays"></div>
	<div class="aero-bubbles">
		${BUBBLES.map(
			(b) =>
				html`<span class="aero-bubble" style="--bubble-left:${b.left};--bubble-size:${b.size};--bubble-duration:${b.duration};--bubble-delay:${b.delay};--bubble-drift:${b.drift}"></span>`,
		)}
	</div>`;
}
