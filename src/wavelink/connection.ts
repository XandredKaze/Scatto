import { EventEmitter } from "node:events";
import { logger } from "../log.js";
import { connectWaveLink } from "./discovery.js";
import type { Patch, WaveLinkClient, WlChannel, WlMix } from "./types.js";

const log = logger("wavelink");

/**
 * Mantiene viva la connessione a Wave Link (riconnessione automatica) e
 * ri-emette gli eventi del client corrente: "connected", "disconnected",
 * "channelChanged", "mixChanged", "topologyChanged".
 */
export class WaveLinkConnection extends EventEmitter {
  client: WaveLinkClient | null = null;
  private stopped = false;
  private timer: NodeJS.Timeout | null = null;
  private delay = 1000;

  constructor(private readonly opts: { host: string; port?: number }) {
    super();
  }

  start(): void {
    this.stopped = false;
    void this.attempt();
  }

  stop(): void {
    this.stopped = true;
    if (this.timer) clearTimeout(this.timer);
    this.client?.close();
    this.client = null;
  }

  get connected(): boolean {
    return this.client !== null;
  }

  channels(): WlChannel[] {
    return this.client?.channels() ?? [];
  }

  mixes(): WlMix[] {
    return this.client?.mixes() ?? [];
  }

  async setChannel(channelId: string, mixId: string | null, patch: Patch): Promise<void> {
    if (!this.client) throw new Error("Wave Link non connesso");
    await this.client.setChannel(channelId, mixId, patch);
  }

  async setMix(mixId: string, patch: Patch): Promise<void> {
    if (!this.client) throw new Error("Wave Link non connesso");
    await this.client.setMix(mixId, patch);
  }

  private async attempt(): Promise<void> {
    if (this.stopped) return;
    try {
      const client = await connectWaveLink(this.opts);
      if (this.stopped) {
        client.close();
        return;
      }
      this.delay = 1000;
      this.client = client;
      for (const ev of ["channelChanged", "mixChanged", "topologyChanged"]) {
        client.on(ev, (...args: unknown[]) => this.emit(ev, ...args));
      }
      client.once("close", () => {
        if (this.client !== client) return;
        this.client = null;
        log.warn("connessione a Wave Link persa");
        this.emit("disconnected");
        this.schedule();
      });
      this.emit("connected", client);
    } catch (err) {
      log.debug((err as Error).message);
      if (this.delay === 1000) log.warn(`${(err as Error).message} Riprovo in background...`);
      this.schedule();
    }
  }

  private schedule(): void {
    if (this.stopped) return;
    this.timer = setTimeout(() => void this.attempt(), this.delay);
    this.delay = Math.min(this.delay * 2, 15000);
  }
}
