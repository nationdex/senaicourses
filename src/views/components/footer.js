import { html } from "../html.js";

/** Inner markup — swapped alone (innerHTML OOB) so the entrance animation doesn't replay. */
export function footerInner({ state, comingSoon, unitName, unitDisplayId }) {
	return html`
		Fonte: <span class="text-ink/42">${state.sourceLabel}</span>
		${comingSoon ? "" : html` · Unidade ${unitName} (ID ${unitDisplayId}) · Refresh automático a cada 5 min`}
		· <a href="/privacidade" class="underline hover:text-ink/60 transition-colors cursor-alias">Política de Privacidade</a>`;
}

export function footer(props) {
	return html`<p id="footer" class="text-center text-xs text-ink/35 pb-2 section-3d section-3d-5">${footerInner(props)}</p>`;
}
