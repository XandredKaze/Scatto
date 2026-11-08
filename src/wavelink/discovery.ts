import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { logger } from "../log.js";
import { namesOf } from "../util/match.js";
import { RpcSocket } from "./rpc.js";
import type { WaveLinkClient, WlAppInfo } from "./types.js";
import { WaveLinkV2 } from "./v2.js";
import { WaveLinkV3 } from "./v3.js";

const log = logger("wavelink");

/** Porte note: 3.x usa 1884–1893 (o quella scritta in ws-info.json), 1.x/2.x usa 1824–1833. */
export const V3_PORTS = range(1884, 1893);
export const V2_PORTS = range(1824, 1833);

function range(a: number, b: number): number[] {
  return Array.from({ length: b - a + 1 }, (_, i) => a + i);
}

/** Legge la porta da ws-info.json (Wave Link 3.x per Windows, app MSIX). */
export function portsFromWsInfo(env: NodeJS.ProcessEnv = process.env): number[] {
  const root = env.LOCALAPPDATA;
  if (!root) return [];
  const pkgDir = join(root, "Packages");
  let dirs: string[] = [];
  try {
    dirs = readdirSync(pkgDir).filter((d) => d.toLowerCase().startsWith("elgato.wavelink"));
  } catch {
    return [];
  }
  const ports: number[] = [];
  for (const d of dirs) {
    try {
      const data = JSON.parse(readFileSync(join(pkgDir, d, "LocalState", "ws-info.json"), "utf8"));
      const port = data?.port;
      if (Number.isInteger(port) && port > 0 && port < 65536) ports.push(port);
    } catch {
      /* file assente o non valido */
    }
  }
  return ports;
}

export function candidatePorts(explicit?: number): number[] {
  if (explicit) return [explicit];
  return [...new Set([...portsFromWsInfo(), ...V3_PORTS, ...V2_PORTS])];
}

export function detectProtocol(raw: Record<string, unknown>): WlAppInfo | null {
  if (!raw || typeof raw !== "object") return null;
  if (raw.appID === "EWL") {
    return { protocol: 3, name: String(raw.name ?? "Wave Link"), version: raw.version as string | undefined, raw };
  }
  const name = String(raw.appName ?? raw.name ?? "");
  if (/wave\s*link/i.test(name) || raw.interfaceRevision !== undefined) {
    return { protocol: 2, name: name || "Wave Link", version: (raw.appVersion ?? raw.version) as string | undefined, raw };
  }
  return null;
}

/** Prova le porte candidate e restituisce il primo Wave Link che risponde. */
export async function connectWaveLink(opts: { host: string; port?: number }): Promise<WaveLinkClient> {
  for (const port of candidatePorts(opts.port)) {
    let rpc: RpcSocket;
    try {
      rpc = await RpcSocket.open(`ws://${opts.host}:${port}`, { openTimeoutMs: 1000 });
    } catch {
      continue;
    }
    try {
      const raw = await rpc.call<Record<string, unknown>>("getApplicationInfo");
      const info = detectProtocol(raw);
      if (!info) {
        log.debug(`porta ${port}: risposta non riconosciuta`, raw);
        rpc.close();
        continue;
      }
      const client = info.protocol === 3 ? new WaveLinkV3(rpc, info) : new WaveLinkV2(rpc, info);
      await client.refresh();
      log.info(`connesso a ${info.name} ${info.version ?? ""} (protocollo ${info.protocol}.x) su porta ${port}`);
      log.info(`mix: ${namesOf(client.mixes())}`);
      log.info(`canali: ${namesOf(client.channels())}`);
      return client;
    } catch (err) {
      log.debug(`porta ${port}: ${(err as Error).message}`);
      rpc.close();
    }
  }
  throw new Error("Wave Link non trovato: è avviato su questo PC?");
}
