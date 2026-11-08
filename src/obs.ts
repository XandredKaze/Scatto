import { EventEmitter } from "node:events";
import OBSWebSocket, { EventSubscription, type OBSEventTypes, type OBSRequestTypes, type OBSResponseTypes } from "obs-websocket-js";
import { logger } from "./log.js";

const log = logger("obs");

/**
 * Connessione a obs-websocket v5 con riconnessione automatica.
 * Emette "connected" / "disconnected"; gli eventi OBS si ascoltano su `.ws`.
 */
export class ObsConnection extends EventEmitter {
  readonly ws = new OBSWebSocket();
  connected = false;
  private stopped = false;
  private timer: NodeJS.Timeout | null = null;
  private delay = 1000;
  private warned = false;

  constructor(private readonly opts: { url: string; password?: string }) {
    super();
    this.ws.on("ConnectionClosed", () => {
      if (!this.connected) return;
      this.connected = false;
      log.warn("connessione a OBS persa");
      this.emit("disconnected");
      this.schedule();
    });
  }

  call<T extends keyof OBSRequestTypes>(type: T, data?: OBSRequestTypes[T]): Promise<OBSResponseTypes[T]> {
    return (this.ws.call as (t: T, d?: OBSRequestTypes[T]) => Promise<OBSResponseTypes[T]>)(type, data);
  }

  onObs<E extends keyof OBSEventTypes>(event: E, fn: (data: OBSEventTypes[E]) => void): void {
    (this.ws.on as (e: E, f: (d: OBSEventTypes[E]) => void) => void)(event, fn);
  }

  start(): void {
    this.stopped = false;
    void this.attempt();
  }

  async stop(): Promise<void> {
    this.stopped = true;
    if (this.timer) clearTimeout(this.timer);
    await this.ws.disconnect().catch(() => {});
  }

  private async attempt(): Promise<void> {
    if (this.stopped) return;
    try {
      const { obsWebSocketVersion } = await this.ws.connect(this.opts.url, this.opts.password, {
        eventSubscriptions: EventSubscription.All,
      });
      this.connected = true;
      this.delay = 1000;
      this.warned = false;
      log.info(`connesso a OBS (obs-websocket ${obsWebSocketVersion}) su ${this.opts.url}`);
      this.emit("connected");
    } catch (err) {
      const msg = (err as Error).message || String(err);
      if (/auth/i.test(msg)) {
        log.error(`autenticazione OBS fallita: controlla obs.password nel config (${msg})`);
      } else if (!this.warned) {
        log.warn(`OBS non raggiungibile su ${this.opts.url} (${msg}). Riprovo in background...`);
        this.warned = true;
      }
      this.schedule();
    }
  }

  private schedule(): void {
    if (this.stopped) return;
    if (this.timer) clearTimeout(this.timer);
    this.timer = setTimeout(() => void this.attempt(), this.delay);
    this.delay = Math.min(this.delay * 2, 15000);
  }
}
