import { createFuturoDigitalAdapter } from "./futuro-digital.js";
// SENAI-PA sells through the same shared "futuro.digital" VTEX cluster 137
// as ma.js/pi.js/ro.js/ms.js/go.js, under the real "PA|" productReferenceCode
// prefix (confirmed: 12 real products, 3 with an actually available turma, in
// Paragominas — thin but real, same tier as ms.js).
export const paAdapter = createFuturoDigitalAdapter("pa", "PA|");
