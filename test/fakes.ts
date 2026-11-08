import { EventEmitter } from "node:events";
import { parseConfig } from "../src/config.js";
import type { Ctx, ObsLike, WlLike } from "../src/features/context.js";
import type { Patch, WlChannel, WlMix } from "../src/wavelink/types.js";

export class FakeWl extends EventEmitter implements WlLike {
  connected = true;
  calls: Array<{ channelId?: string; mixId: string | null; patch: Patch }> = [];
  constructor(
    public chans: WlChannel[],
    public mixList: WlMix[],
  ) {
    super();
  }
  channels() {
    return this.chans;
  }
  mixes() {
    return this.mixList;
  }
  async setChannel(channelId: string, mixId: string | null, patch: Patch) {
    this.calls.push({ channelId, mixId, patch });
    const ch = this.chans.find((c) => c.id === channelId)!;
    const ids = mixId === null ? Object.keys(ch.mixes) : [mixId];
    for (const id of ids) ch.mixes[id] = { ...(ch.mixes[id] ?? { level: 100, muted: false }), ...patch };
    this.emit("channelChanged", ch);
  }
  async setMix(mixId: string, patch: Patch) {
    this.calls.push({ mixId, patch });
    Object.assign(this.mixList.find((m) => m.id === mixId)!, patch);
  }
}

/** OBS finto: registra le chiamate e, come OBS vero, emette l'evento di ritorno. */
export class FakeObs extends EventEmitter implements ObsLike {
  connected = true;
  calls: Array<{ type: string; data: any }> = [];
  obsEvents = new EventEmitter();
  scenes: Record<string, string[]> = {};
  inputs: Record<string, { mul: number; muted: boolean }> = {};

  async call(type: any, data?: any): Promise<any> {
    this.calls.push({ type, data });
    switch (type) {
      case "SetInputVolume":
        this.inputs[data.inputName] = { ...(this.inputs[data.inputName] ?? { muted: false }), mul: data.inputVolumeMul };
        this.obsEvents.emit("InputVolumeChanged", { inputName: data.inputName, inputVolumeMul: data.inputVolumeMul, inputVolumeDb: 0 });
        return {};
      case "SetInputMute":
        this.inputs[data.inputName] = { ...(this.inputs[data.inputName] ?? { mul: 1 }), muted: data.inputMuted };
        this.obsEvents.emit("InputMuteStateChanged", { inputName: data.inputName, inputMuted: data.inputMuted });
        return {};
      case "GetInputVolume":
        return { inputVolumeMul: this.inputs[data.inputName]?.mul ?? 1, inputVolumeDb: 0 };
      case "GetInputMute":
        return { inputMuted: this.inputs[data.inputName]?.muted ?? false };
      case "GetSceneList":
        return { scenes: Object.keys(this.scenes).map((sceneName) => ({ sceneName })), currentProgramSceneName: "" };
      case "GetCurrentProgramScene":
        return { currentProgramSceneName: Object.keys(this.scenes)[0] };
      case "GetSceneItemId": {
        const idx = this.scenes[data.sceneName]?.indexOf(data.sourceName) ?? -1;
        if (idx < 0) throw new Error("No scene items were found");
        return { sceneItemId: idx + 1 };
      }
      default:
        return {};
    }
  }
  onObs(event: any, fn: any) {
    this.obsEvents.on(event, fn);
  }
  /** Simula un'azione dell'utente in OBS. */
  userEvent(event: string, data: any) {
    this.obsEvents.emit(event, data);
  }
}

export function makeCtx(rawCfg: unknown, wl: FakeWl, obs: FakeObs): Ctx {
  return { cfg: parseConfig(rawCfg), wl, obs };
}

export const mixesV3 = (): WlMix[] => [
  { id: "mix-mon", name: "Monitor Mix", aliases: [], level: 100, muted: false },
  { id: "mix-str", name: "Stream Mix", aliases: [], level: 100, muted: false },
];

export const channelsV3 = (): WlChannel[] => [
  { id: "ch-mic", name: "Microfono", level: 100, muted: false, mixes: { "mix-mon": { level: 100, muted: false }, "mix-str": { level: 100, muted: false } } },
  { id: "ch-music", name: "Musica", level: 100, muted: false, mixes: { "mix-mon": { level: 40, muted: false }, "mix-str": { level: 30, muted: false } } },
];

export const flush = () => new Promise((r) => setTimeout(r, 5));
