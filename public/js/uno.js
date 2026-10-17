// UnoCSS runtime: generates the utility CSS in the browser from the classes it
// finds in the DOM (and watches for new ones that htmx swaps in). Wind4 is the
// Tailwind-v4-compatible preset, so the class names are the ones the old
// Tailwind build used. Theme tokens map to the CSS variables in css/aero.css.

import presetWind4 from "https://esm.sh/@unocss/preset-wind4@66.5.0?bundle";
import init from "https://esm.sh/@unocss/runtime@66.5.0?bundle";

const scale = (name) => ({
	// biome-ignore lint/style/useNamingConvention: UnoCSS theme key
	DEFAULT: `var(--${name})`,
	light: `var(--${name}-light)`,
	dark: `var(--${name}-dark)`,
});

window.__unocss = {
	presets: [presetWind4()],
	theme: {
		colors: {
			ink: "var(--ink)",
			glass: "var(--glass)",
			destructive: "var(--destructive)",
			brand: scale("brand"),
			accent2: scale("accent2"),
		},
		// The old @theme block derived the radius scale from --radius (1.1rem).
		radius: {
			sm: "calc(var(--radius) - 4px)",
			md: "calc(var(--radius) - 2px)",
			lg: "var(--radius)",
			xl: "calc(var(--radius) + 4px)",
		},
	},
};

await init();
