import { createFuturoDigitalAdapter } from "./futuro-digital.js";
// SENAI-RN sells through the same shared "futuro.digital" VTEX cluster 137
// as ma.js/pi.js/ro.js/ms.js/go.js, under the real "RN|" productReferenceCode
// prefix (confirmed: 47 real products, 22 with an actually available turma,
// across Natal and Mossoró, with real "Área Tecnológica" taxonomy).
export const rnAdapter = createFuturoDigitalAdapter("rn", "RN|");
