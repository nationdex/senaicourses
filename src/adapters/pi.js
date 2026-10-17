import { createFuturoDigitalAdapter } from "./futuro-digital.js";
// SENAI-PI shares the tewbhv "futuro.digital" VTEX backend (see futuro-digital.js)
// — found by reading fiepi.com.br's real course-catalog page, which links out to
// futuro.digital/senai-pi and futuro.digital/cursos-ti-informatica-senai-pi.
// productReferenceCode for PI's own products starts with "PI|" (confirmed by
// inspecting real product data in the shared cluster).
export const piAdapter = createFuturoDigitalAdapter("pi", "PI|");
