import { EventEmitter } from "node:events";
import { RpcError, type RpcSocket } from "./rpc.js";
import type { MixState, Patch, WaveLinkClient, WlAppInfo, WlChannel, WlMix } from "./types.js";

/**
 * Wave Link 3.x: mix dinamici con id opachi, livelli 0..1 (normalizzati qui a 0..100).
 * Metodi: getChannels, getMixes, setChannel, setMix. Eventi: channel(s)Changed, mix(es)Changed.
 */

interface RawChannelMix {
  id?: string;
  mixId?: string;
  level?: number;
  isMuted?: boolean;
}
interface RawChannel {
  id: string;
  name?: string;
  level?: number;
  isMuted?: boolean;
  mixes?: RawChannelMix[];
}
interface RawMix {
  id: string;
  name?: string;
  level?: number;
  isMuted?: boolean;
}

const toPct = (v: number) => Math.round(v * 1000) / 10;
const toUnit = (v: number) => Math.max(0, Math.min(1, v / 100));

export class WaveLinkV3 extends EventEmitter implements WaveLinkClient {
  private chans = new Map<string, WlChannel>();
  private mixMap = new Map<string, WlMix>();
  /** Alcune build vogliono "mixId" al posto di "id" nelle voci per-mix di setChannel. */
  private mixKey: "id" | "mixId" = "id";

  constructor(
    private readonly rpc: RpcSocket,
    readonly info: WlAppInfo,
  ) {
    super();
    rpc.on("notification", (m: string, p: unknown) => this.onNotification(m, p));
    rpc.on("close", () => this.emit("close"));
  }

  channels(): WlChannel[] {
    return [...this.chans.values()];
  }

  mixes(): WlMix[] {
    return [...this.mixMap.values()];
  }

  async refresh(): Promise<void> {
    const [c, m] = await Promise.all([
      this.rpc.call<{ channels?: RawChannel[] }>("getChannels"),
      this.rpc.call<{ mixes?: RawMix[] }>("getMixes"),
    ]);
    this.replaceChannels(c?.channels ?? []);
    this.replaceMixes(m?.mixes ?? []);
  }

  async setChannel(channelId: string, mixId: string | null, patch: Patch): Promise<void> {
    if (mixId === null) {
      const params: Record<string, unknown> = { id: channelId };
      if (patch.level !== undefined) params.level = toUnit(patch.level);
      if (patch.muted !== undefined) params.isMuted = patch.muted;
      await this.rpc.call("setChannel", params);
      this.mergeChannel({ id: channelId, level: params.level as number | undefined, isMuted: patch.muted });
      return;
    }
    const entry: Record<string, unknown> = {};
    if (patch.level !== undefined) entry.level = toUnit(patch.level);
    if (patch.muted !== undefined) entry.isMuted = patch.muted;
    const send = (key: "id" | "mixId") => this.rpc.call("setChannel", { id: channelId, mixes: [{ [key]: mixId, ...entry }] });
    try {
      await send(this.mixKey);
    } catch (err) {
      if (!(err instanceof RpcError && err.code === -32602)) throw err;
      this.mixKey = this.mixKey === "id" ? "mixId" : "id";
      await send(this.mixKey);
    }
    this.mergeChannel({ id: channelId, mixes: [{ id: mixId, level: entry.level as number | undefined, isMuted: patch.muted }] });
  }

  async setMix(mixId: string, patch: Patch): Promise<void> {
    const params: Record<string, unknown> = { id: mixId };
    if (patch.level !== undefined) params.level = toUnit(patch.level);
    if (patch.muted !== undefined) params.isMuted = patch.muted;
    await this.rpc.call("setMix", params);
    this.mergeMix({ id: mixId, level: params.level as number | undefined, isMuted: patch.muted });
  }

  close(): void {
    this.rpc.close();
  }

  private replaceChannels(list: RawChannel[]): void {
    this.chans.clear();
    for (const raw of list) this.mergeChannel(raw, false);
  }

  private replaceMixes(list: RawMix[]): void {
    this.mixMap.clear();
    for (const raw of list) this.mergeMix(raw, false);
  }

  private mergeChannel(raw: RawChannel, emit = true): void {
    if (!raw?.id) return;
    const existing = this.chans.get(raw.id);
    const ch: WlChannel = existing ?? { id: raw.id, name: raw.name ?? raw.id, mixes: {} };
    const before = JSON.stringify(ch);
    if (raw.name !== undefined) ch.name = raw.name;
    if (raw.level !== undefined) ch.level = toPct(raw.level);
    if (raw.isMuted !== undefined) ch.muted = raw.isMuted;
    for (const m of raw.mixes ?? []) {
      const id = m.id ?? m.mixId;
      if (!id) continue;
      const cur: MixState = ch.mixes[id] ?? { level: 100, muted: false };
      ch.mixes[id] = {
        level: m.level !== undefined ? toPct(m.level) : cur.level,
        muted: m.isMuted !== undefined ? m.isMuted : cur.muted,
      };
    }
    this.chans.set(ch.id, ch);
    if (!emit) return;
    if (!existing) this.emit("topologyChanged");
    if (JSON.stringify(ch) !== before) this.emit("channelChanged", ch);
  }

  private mergeMix(raw: RawMix, emit = true): void {
    if (!raw?.id) return;
    const existing = this.mixMap.get(raw.id);
    const mix: WlMix = existing ?? { id: raw.id, name: raw.name ?? raw.id, aliases: [], level: 100, muted: false };
    const before = JSON.stringify(mix);
    if (raw.name !== undefined) mix.name = raw.name;
    if (raw.level !== undefined) mix.level = toPct(raw.level);
    if (raw.isMuted !== undefined) mix.muted = raw.isMuted;
    this.mixMap.set(mix.id, mix);
    if (!emit) return;
    if (!existing) this.emit("topologyChanged");
    if (JSON.stringify(mix) !== before) this.emit("mixChanged", mix);
  }

  private onNotification(method: string, params: unknown): void {
    const p = (params ?? {}) as Record<string, unknown>;
    switch (method) {
      case "channelChanged":
        this.mergeChannel(p as unknown as RawChannel);
        break;
      case "channelsChanged":
        this.replaceChannels((p.channels as RawChannel[]) ?? []);
        this.emit("topologyChanged");
        for (const ch of this.chans.values()) this.emit("channelChanged", ch);
        break;
      case "mixChanged":
        this.mergeMix(p as unknown as RawMix);
        break;
      case "mixesChanged":
        this.replaceMixes((p.mixes as RawMix[]) ?? []);
        this.emit("topologyChanged");
        for (const mix of this.mixMap.values()) this.emit("mixChanged", mix);
        break;
    }
  }
}
