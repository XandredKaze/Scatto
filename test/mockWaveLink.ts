import { WebSocketServer, type WebSocket } from "ws";

export interface MockServer {
  port: number;
  received: Array<{ method: string; params: unknown }>;
  notify(method: string, params: unknown): void;
  close(): Promise<void>;
}

/** Piccolo server JSON-RPC che imita Wave Link. `handlers` restituisce il result per ogni metodo. */
export async function startMock(handlers: Record<string, (params: any) => unknown>): Promise<MockServer> {
  const wss = new WebSocketServer({ port: 0, host: "127.0.0.1" });
  await new Promise<void>((r) => wss.once("listening", () => r()));
  const sockets = new Set<WebSocket>();
  const received: MockServer["received"] = [];
  wss.on("connection", (ws, req) => {
    if (req.headers.origin !== "streamdeck://") {
      ws.close();
      return;
    }
    sockets.add(ws);
    ws.on("close", () => sockets.delete(ws));
    ws.on("message", (buf) => {
      const msg = JSON.parse(buf.toString());
      received.push({ method: msg.method, params: msg.params });
      const h = handlers[msg.method];
      if (!h) {
        ws.send(JSON.stringify({ id: msg.id, jsonrpc: "2.0", error: { code: -32601, message: "Method not found" } }));
        return;
      }
      try {
        ws.send(JSON.stringify({ id: msg.id, jsonrpc: "2.0", result: h(msg.params) }));
      } catch (e: any) {
        ws.send(JSON.stringify({ id: msg.id, jsonrpc: "2.0", error: { code: e.code ?? -32000, message: e.message } }));
      }
    });
  });
  const port = (wss.address() as { port: number }).port;
  return {
    port,
    received,
    notify(method, params) {
      for (const s of sockets) s.send(JSON.stringify({ jsonrpc: "2.0", method, params }));
    },
    close: () =>
      new Promise<void>((r) => {
        for (const s of sockets) s.terminate();
        wss.close(() => r());
      }),
  };
}

export const tick = (ms = 30) => new Promise((r) => setTimeout(r, ms));
