/** Wave Link 0..100 -> moltiplicatore lineare OBS (1.0 = 0 dB). */
export function pctToMul(pct: number): number {
  return Math.max(0, Math.min(100, pct)) / 100;
}

/** Moltiplicatore OBS -> Wave Link 0..100 (oltre 0 dB viene limitato a 100). */
export function mulToPct(mul: number): number {
  return Math.max(0, Math.min(100, Math.round(mul * 1000) / 10));
}

export const LEVEL_TOLERANCE = 1;
