import { atmosphere } from "../components/atmosphere.js";
import { html } from "../html.js";
import { layout, shell } from "../layout.js";

const H2 = "text-lg font-semibold text-ink/90 mb-3";
const MAIL = html`<a href="mailto:arielaram@protonmail.com" class="underline hover:text-ink/95 transition-colors">arielaram@protonmail.com</a>`;

export function privacyPage() {
	const inner = html`
	<div class="glass-card rounded-2xl p-8 md:p-12">
		<a href="/" class="inline-flex items-center gap-2 text-sm text-ink/45 hover:text-ink/85 transition-colors mb-8 cursor-alias">← Voltar para o início</a>

		<h1 class="text-3xl font-bold text-ink mb-2">Política de Privacidade</h1>
		<p class="text-ink/45 text-sm mb-8">Última atualização: 25 de abril de 2026</p>

		<div class="space-y-8 text-ink/72 text-sm leading-relaxed">
			<section>
				<h2 class="${H2}">1. Sobre este site</h2>
				<p>
					Este site (<strong>spsenai.arielaram.com</strong>) é um agregador independente e não oficial de vagas em cursos gratuitos de Tecnologia da Informação oferecidos pelo <strong>SENAI-SP</strong>. Os dados exibidos são obtidos publicamente em <span class="text-ink/55">sp.senai.br</span> e atualizados automaticamente a cada 5 minutos. O site é operado por <strong>Ariel Aram</strong> (${MAIL}).
				</p>
			</section>

			<section>
				<h2 class="${H2}">2. Dados coletados</h2>
				<p>
					Este site <strong>não coleta dados pessoais diretamente</strong>. Não há cadastro, login, formulário ou armazenamento de informações identificáveis dos visitantes em nossos servidores. Os dados exibidos (cursos, vagas, horários) são públicos e provenientes exclusivamente do SENAI-SP.
				</p>
			</section>

			<section>
				<h2 class="${H2}">3. Armazenamento local</h2>
				<p>
					O site pode utilizar armazenamento local no navegador (como <code>localStorage</code>) apenas para salvar preferências de exibição de forma anônima e local no seu próprio dispositivo.
				</p>
			</section>

			<section>
				<h2 class="${H2}">4. Seus direitos</h2>
				<p class="mb-2">
					Nos termos da <strong>LGPD</strong> (Lei Geral de Proteção de Dados — Lei nº 13.709/2018) e do <strong>GDPR</strong> (Regulamento Geral de Proteção de Dados da UE), você tem direito a:
				</p>
				<ul class="ml-4 list-disc space-y-1 text-ink/58">
					<li>Confirmar a existência de tratamento de dados pessoais</li>
					<li>Acessar seus dados pessoais</li>
					<li>Corrigir dados incompletos, inexatos ou desatualizados</li>
					<li>Solicitar a anonimização, bloqueio ou eliminação de dados</li>
					<li>Revogar o consentimento a qualquer momento</li>
					<li>Opor-se ao tratamento realizado com base em legítimo interesse</li>
				</ul>
				<p class="mt-3">
					Como este site não armazena dados pessoais em seus servidores, não mantemos perfis de usuários ou rastreamento individualizado.
				</p>
			</section>

			<section>
				<h2 class="${H2}">5. Links externos e isenção de responsabilidade</h2>
				<p>
					Este site pode conter links para o site oficial do SENAI-SP. Não nos responsabilizamos pela disponibilidade, exatidão ou políticas de privacidade de sites externos. As informações sobre cursos são fornecidas "como estão" e podem não refletir alterações em tempo real no sistema do SENAI-SP.
				</p>
			</section>

			<section>
				<h2 class="${H2}">6. Contato</h2>
				<p>Para dúvidas sobre esta política de privacidade, entre em contato pelo e-mail: ${MAIL}.</p>
			</section>
		</div>
	</div>`;
	return layout({
		body: shell({
			atmosphere: atmosphere(),
			inner,
			rootClass: "min-h-screen p-6 md:p-12",
			column: "relative z-10 max-w-3xl mx-auto",
		}),
	});
}
