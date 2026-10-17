import { createFuturoDigitalAdapter } from "./futuro-digital.js";
// SENAI-PE sells through the same shared "futuro.digital" VTEX cluster 137
// as ma.js/pi.js/ro.js/ms.js/go.js, under the real "PE|" productReferenceCode
// prefix (confirmed: 64 real products, 85 available turma offers across 9
// real cities — Recife, Petrolina, Caruaru, etc. — with real "Área
// Tecnológica" taxonomy including Tecnologia da Informação). The largest of
// this batch of newly-added VTEX states.
export const peAdapter = createFuturoDigitalAdapter("pe", "PE|");
