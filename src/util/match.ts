import type { MixState, WlChannel, WlMix } from "../wavelink/types.js";

const norm = (s: string) => s.trim().toLowerCase();

/** Trova un canale per id esatto oppure per nome (senza distinzione maiuscole/minuscole). */
export function findChannel(channels: WlChannel[], ref: string): WlChannel | undefined {
  const r = norm(ref);
  return channels.find((c) => c.id === ref) ?? channels.find((c) => norm(c.name) === r) ?? channels.find((c) => norm(c.id) === r);
}

/**
 * Trova un mix per id, nome o alias; in mancanza accetta una parola contenuta
 * nel nome purché identifichi un solo mix (es. "stream" -> "Stream Mix").
 */
export function findMix(mixes: WlMix[], ref: string): WlMix | undefined {
  const r = norm(ref);
  const exact =
    mixes.find((m) => m.id === ref) ??
    mixes.find((m) => norm(m.name) === r) ??
    mixes.find((m) => m.aliases.some((a) => norm(a) === r)) ??
    mixes.find((m) => norm(m.id) === r);
  if (exact || !r) return exact;
  const partial = mixes.filter((m) => norm(m.name).split(/[^\p{L}\p{N}]+/u).includes(r));
  return partial.length === 1 ? partial[0] : undefined;
}

/**
 * Stato effettivo di un canale. Con mix: lo stato in quel mix.
 * Senza mix: lo stato globale (3.x) oppure, se assente (2.x), quello del mix Stream.
 */
export function channelState(ch: WlChannel, mixes: WlMix[], mixRef?: string): MixState | undefined {
  if (mixRef) {
    const mix = findMix(mixes, mixRef);
    return mix ? ch.mixes[mix.id] : undefined;
  }
  if (ch.level !== undefined || ch.muted !== undefined) {
    return { level: ch.level ?? 100, muted: ch.muted ?? false };
  }
  const stream = findMix(mixes, "stream");
  return stream ? ch.mixes[stream.id] : Object.values(ch.mixes)[0];
}

/** Mix da usare per scrivere lo stato "effettivo" (null = globale). */
export function effectiveMixId(ch: WlChannel, mixes: WlMix[], mixRef?: string): string | null | undefined {
  if (mixRef) return findMix(mixes, mixRef)?.id;
  if (ch.level !== undefined || ch.muted !== undefined) return null;
  return findMix(mixes, "stream")?.id ?? Object.keys(ch.mixes)[0];
}

/** Elenco leggibile dei nomi disponibili, per i messaggi di errore. */
export function namesOf(items: Array<{ name: string }>): string {
  return items.length ? items.map((i) => `"${i.name}"`).join(", ") : "(nessuno)";
}
