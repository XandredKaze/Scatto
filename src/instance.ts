import { createConnection, createServer, type Server } from "node:net";

/** Porta locale usata come "lucchetto" per avere una sola istanza di WaveOBS. */
export const LOCK_PORT = 47819;

function listen(port: number, onQuit: () => void): Promise<Server | null> {
  return new Promise((resolve) => {
    const server = createServer((sock) => {
      sock.on("data", (d) => {
        if (d.toString().trim() === "quit") {
          sock.end("bye\n");
          onQuit();
        }
      });
      sock.on("error", () => {});
    });
    server.once("error", () => resolve(null));
    server.listen(port, "127.0.0.1", () => resolve(server));
  });
}

function askToQuit(port: number): Promise<void> {
  return new Promise((resolve) => {
    const sock = createConnection({ port, host: "127.0.0.1" }, () => sock.write("quit\n"));
    sock.setTimeout(1000, () => sock.destroy());
    sock.on("close", () => resolve());
    sock.on("error", () => resolve());
  });
}

/**
 * Garantisce una sola istanza: se ce n'è già una, le chiede di chiudersi e prende il suo posto
 * (così ricaricare lo script in OBS riavvia WaveOBS invece di duplicarlo).
 */
export async function acquireSingleInstance(onQuit: () => void, port = LOCK_PORT): Promise<Server> {
  for (let i = 0; i < 30; i++) {
    const server = await listen(port, onQuit);
    if (server) return server;
    if (i === 0) await askToQuit(port);
    await new Promise((r) => setTimeout(r, 200));
  }
  throw new Error(`un'altra istanza di WaveOBS non si chiude (porta ${port} occupata)`);
}
