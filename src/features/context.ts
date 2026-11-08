import type { OBSEventTypes, OBSRequestTypes, OBSResponseTypes } from "obs-websocket-js";
import type { Config } from "../config.js";
import type { Patch, WlChannel, WlMix } from "../wavelink/types.js";

/** Superficie di Wave Link usata dalle funzioni (implementata da WaveLinkConnection). */
export interface WlLike {
  readonly connected: boolean;
  channels(): WlChannel[];
  mixes(): WlMix[];
  setChannel(channelId: string, mixId: string | null, patch: Patch): Promise<void>;
  setMix(mixId: string, patch: Patch): Promise<void>;
  on(event: "connected" | "disconnected" | "topologyChanged", fn: () => void): unknown;
  on(event: "channelChanged", fn: (ch: WlChannel) => void): unknown;
  on(event: "mixChanged", fn: (mix: WlMix) => void): unknown;
}

/** Superficie di OBS usata dalle funzioni (implementata da ObsConnection). */
export interface ObsLike {
  readonly connected: boolean;
  call<T extends keyof OBSRequestTypes>(type: T, data?: OBSRequestTypes[T]): Promise<OBSResponseTypes[T]>;
  onObs<E extends keyof OBSEventTypes>(event: E, fn: (data: OBSEventTypes[E]) => void): void;
  on(event: "connected" | "disconnected", fn: () => void): unknown;
}

export interface Ctx {
  cfg: Config;
  wl: WlLike;
  obs: ObsLike;
}

/** Esegue `fn` ogni volta che entrambe le connessioni diventano attive. */
export function whenBothConnected(ctx: Ctx, fn: () => void): void {
  const check = () => {
    if (ctx.wl.connected && ctx.obs.connected) fn();
  };
  ctx.wl.on("connected", check);
  ctx.obs.on("connected", check);
}
