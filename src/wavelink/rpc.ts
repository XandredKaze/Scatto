import { EventEmitter } from "node:events";
import WebSocket from "ws";

export class RpcError extends Error {
  constructor(
    public readonly code: number,
    message: string,
    public readonly data?: unknown,
  ) {
    super(`Wave Link RPC error ${code}: ${message}`);
  }
}

interface Pending {
  resolve: (v: unknown) => void;
  reject: (e: Error) => void;
  timer: NodeJS.Timeout;
}

/**
 * Socket JSON-RPC 2.0 verso Wave Link. Emette:
 *  - "notification" (method: string, params: unknown)
 *  - "close" ()
 */
export class RpcSocket extends EventEmitter {
  private nextId = 1;
  private pending = new Map<number, Pending>();
  private closed = false;

  private constructor(
    private readonly ws: WebSocket,
    private readonly timeoutMs: number,
  ) {
    super();
    ws.on("message", (data) => this.onMessage(data.toString()));
    ws.on("close", () => this.onClose());
    ws.on("error", () => this.onClose());
  }

  static open(url: string, opts: { timeoutMs?: number; openTimeoutMs?: number } = {}): Promise<RpcSocket> {
    return new Promise((resolve, reject) => {
      // Wave Link accetta solo connessioni che si presentano come Stream Deck.
      const ws = new WebSocket(url, { origin: "streamdeck://", handshakeTimeout: opts.openTimeoutMs ?? 2000 });
      const fail = (err: Error) => {
        ws.removeAllListeners();
        ws.on("error", () => {});
        ws.terminate();
        reject(err);
      };
      ws.once("open", () => {
        ws.removeAllListeners();
        resolve(new RpcSocket(ws, opts.timeoutMs ?? 3000));
      });
      ws.once("error", fail);
      ws.once("unexpected-response", () => fail(new Error("unexpected HTTP response")));
    });
  }

  get isOpen(): boolean {
    return !this.closed && this.ws.readyState === WebSocket.OPEN;
  }

  call<T = unknown>(method: string, params?: unknown): Promise<T> {
    if (!this.isOpen) return Promise.reject(new Error("Wave Link socket chiuso"));
    const id = this.nextId++;
    const msg = { id, jsonrpc: "2.0", method, params: params ?? null };
    return new Promise<T>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Timeout su ${method}`));
      }, this.timeoutMs);
      this.pending.set(id, { resolve: resolve as (v: unknown) => void, reject, timer });
      this.ws.send(JSON.stringify(msg));
    });
  }

  close(): void {
    this.ws.close();
    this.onClose();
  }

  private onMessage(text: string): void {
    let msg: { id?: number; method?: string; params?: unknown; result?: unknown; error?: { code: number; message: string; data?: unknown } };
    try {
      msg = JSON.parse(text);
    } catch {
      return;
    }
    if (typeof msg.id === "number" && this.pending.has(msg.id)) {
      const p = this.pending.get(msg.id)!;
      this.pending.delete(msg.id);
      clearTimeout(p.timer);
      if (msg.error) p.reject(new RpcError(msg.error.code, msg.error.message, msg.error.data));
      else p.resolve(msg.result);
      return;
    }
    if (typeof msg.method === "string") this.emit("notification", msg.method, msg.params);
  }

  private onClose(): void {
    if (this.closed) return;
    this.closed = true;
    for (const p of this.pending.values()) {
      clearTimeout(p.timer);
      p.reject(new Error("Wave Link socket chiuso"));
    }
    this.pending.clear();
    this.emit("close");
  }
}
