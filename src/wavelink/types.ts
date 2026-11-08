import type { EventEmitter } from "node:events";

/** Stato di un canale all'interno di un mix. `level` è sempre normalizzato 0..100. */
export interface MixState {
  level: number;
  muted: boolean;
}

export interface WlChannel {
  id: string;
  name: string;
  /** Stato per mix, indicizzato per id del mix. */
  mixes: Record<string, MixState>;
  /** Livello/mute globale del canale (solo Wave Link 3.x). */
  level?: number;
  muted?: boolean;
}

export interface WlMix {
  id: string;
  name: string;
  /** Nomi alternativi accettati in configurazione (es. "monitor", "local"). */
  aliases: string[];
  level: number;
  muted: boolean;
}

export interface WlAppInfo {
  protocol: 2 | 3;
  name: string;
  version?: string;
  raw: Record<string, unknown>;
}

export interface Patch {
  level?: number;
  muted?: boolean;
}

/**
 * Interfaccia comune ai due protocolli. Gli eventi emessi sono:
 *  - "channelChanged" (channel: WlChannel)
 *  - "mixChanged"     (mix: WlMix)
 *  - "topologyChanged" ()   — canali o mix aggiunti/rimossi
 *  - "close"          ()
 */
export interface WaveLinkClient extends EventEmitter {
  readonly info: WlAppInfo;
  channels(): WlChannel[];
  mixes(): WlMix[];
  refresh(): Promise<void>;
  /** mixId = null => tutti i mix (o il valore globale del canale in 3.x). */
  setChannel(channelId: string, mixId: string | null, patch: Patch): Promise<void>;
  setMix(mixId: string, patch: Patch): Promise<void>;
  close(): void;
}
