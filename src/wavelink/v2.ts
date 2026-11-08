import { EventEmitter } from "node:events";
import type { RpcSocket } from "./rpc.js";
import type { Patch, WaveLinkClient, WlAppInfo, WlChannel, WlMix } from "./types.js";

/**
 * Wave Link 1.x / 2.x: due mix fissi (monitor "local" e "stream"), volumi 0..100.
 * Metodi: getInputConfigs, getOutputConfig, setInputConfig, setOutputConfig.
 */
export const MIX_LOCAL = "com.elgato.mix.local";
export const MIX_STREAM = "com.elgato.mix.stream";

const MIX_DEFS: Array<Pick<WlMix, "id" | "name" | "aliases">> = [
  { id: MIX_LOCAL, name: "Monitor", aliases: ["local", "monitor mix", "monitoring", "cuffie"] },
  { id: MIX_STREAM, name: "Stream", aliases: ["stream mix"] },
];

type Pair = [boolean, number];

interface V2Input {
  identifier: string;
  name: string;
  localMixer?: Pair;
  streamMixer?: Pair;
  isAvailable?: boolean;
}

function mixKey(mixerID: string): "localMixer" | "streamMixer" | null {
  if (mixerID === MIX_LOCAL || mixerID === "local") return "localMixer";
  if (mixerID === MIX_STREAM || mixerID === "stream") return "streamMixer";
  return null;
}

function normMixerId(mixerID: string): string {
  return mixKey(mixerID) === "localMixer" ? MIX_LOCAL : MIX_STREAM;
}

export class WaveLinkV2 extends EventEmitter implements WaveLinkClient {
  private chans = new Map<string, WlChannel>();
  private mixMap = new Map<string, WlMix>();

  constructor(
    private readonly rpc: RpcSocket,
    readonly info: WlAppInfo,
  ) {
    super();
    for (const d of MIX_DEFS) this.mixMap.set(d.id, { ...d, level: 100, muted: false });
    rpc.on("notification", (m: string, p: unknown) => this.onNotification(m, p as Record<string, unknown>));
    rpc.on("close", () => this.emit("close"));
  }

  channels(): WlChannel[] {
    return [...this.chans.values()];
  }

  mixes(): WlMix[] {
    return [...this.mixMap.values()];
  }

  async refresh(): Promise<void> {
    const raw = await this.rpc.call<unknown>("getInputConfigs");
    const inputs: V2Input[] = Array.isArray(raw) ? raw : ((raw as { inputs?: V2Input[] })?.inputs ?? []);
    this.chans.clear();
    for (const inp of inputs) {
      if (inp.isAvailable === false) continue;
      const mixes: WlChannel["mixes"] = {};
      if (inp.localMixer) mixes[MIX_LOCAL] = { muted: inp.localMixer[0], level: inp.localMixer[1] };
      if (inp.streamMixer) mixes[MIX_STREAM] = { muted: inp.streamMixer[0], level: inp.streamMixer[1] };
      this.chans.set(inp.identifier, { id: inp.identifier, name: inp.name, mixes });
    }
    const out = await this.rpc.call<{ localMixer?: Pair; streamMixer?: Pair }>("getOutputConfig");
    for (const [id, key] of [[MIX_LOCAL, "localMixer"], [MIX_STREAM, "streamMixer"]] as const) {
      const pair = out?.[key];
      const mix = this.mixMap.get(id)!;
      if (pair) {
        mix.muted = pair[0];
        mix.level = pair[1];
      }
    }
  }

  async setChannel(channelId: string, mixId: string | null, patch: Patch): Promise<void> {
    const targets = mixId === null ? [MIX_LOCAL, MIX_STREAM] : [normMixerId(mixId)];
    for (const mixerID of targets) {
      if (patch.level !== undefined) {
        const value = Math.round(clamp(patch.level));
        await this.rpc.call("setInputConfig", { identifier: channelId, mixerID, property: "Volume", value });
        this.applyChannel(channelId, mixerID, { level: value });
      }
      if (patch.muted !== undefined) {
        await this.rpc.call("setInputConfig", { identifier: channelId, mixerID, property: "Mute", value: patch.muted });
        this.applyChannel(channelId, mixerID, { muted: patch.muted });
      }
    }
  }

  async setMix(mixId: string, patch: Patch): Promise<void> {
    const mixerID = normMixerId(mixId);
    if (patch.level !== undefined) {
      const value = Math.round(clamp(patch.level));
      await this.rpc.call("setOutputConfig", { mixerID, property: "Output Level", value });
      this.applyMix(mixerID, { level: value });
    }
    if (patch.muted !== undefined) {
      await this.rpc.call("setOutputConfig", { mixerID, property: "Mute", value: patch.muted });
      this.applyMix(mixerID, { muted: patch.muted });
    }
  }

  close(): void {
    this.rpc.close();
  }

  private applyChannel(id: string, mixerID: string, patch: Patch): void {
    const ch = this.chans.get(id);
    if (!ch) return;
    const cur = ch.mixes[mixerID] ?? { level: 100, muted: false };
    const next = { ...cur, ...patch };
    if (next.level === cur.level && next.muted === cur.muted && ch.mixes[mixerID]) return;
    ch.mixes[mixerID] = next;
    this.emit("channelChanged", ch);
  }

  private applyMix(mixerID: string, patch: Patch): void {
    const mix = this.mixMap.get(mixerID);
    if (!mix) return;
    const before = `${mix.level}/${mix.muted}`;
    Object.assign(mix, patch);
    if (`${mix.level}/${mix.muted}` !== before) this.emit("mixChanged", mix);
  }

  private onNotification(method: string, p: Record<string, unknown> | undefined): void {
    if (!p) p = {};
    switch (method) {
      case "inputVolumeChanged":
        this.applyChannel(String(p.identifier), normMixerId(String(p.mixerID)), { level: Number(p.value) });
        break;
      case "inputMuteChanged":
        this.applyChannel(String(p.identifier), normMixerId(String(p.mixerID)), { muted: Boolean(p.value) });
        break;
      case "outputVolumeChanged":
        this.applyMix(normMixerId(String(p.mixerID)), { level: Number(p.value) });
        break;
      case "outputMuteChanged":
        this.applyMix(normMixerId(String(p.mixerID)), { muted: Boolean(p.value) });
        break;
      case "inputNameChanged": {
        const ch = this.chans.get(String(p.identifier));
        if (ch) {
          ch.name = String(p.value);
          this.emit("topologyChanged");
        }
        break;
      }
      case "inputsChanged":
        this.refresh().then(
          () => this.emit("topologyChanged"),
          () => {},
        );
        break;
    }
  }
}

function clamp(v: number): number {
  return Math.max(0, Math.min(100, v));
}
