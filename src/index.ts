#!/usr/bin/env node
import { resolve } from "node:path";
import { type Config, loadConfig, parseConfig } from "./config.js";
import type { Ctx } from "./features/context.js";
import { setupEventActions } from "./features/eventActions.js";
import { setupLevelSync } from "./features/levelSync.js";
import { setupMicIndicators } from "./features/micIndicator.js";
import { setupSceneMixes } from "./features/sceneMixes.js";
import { logger, setLogLevel } from "./log.js";
import { ObsConnection } from "./obs.js";
import { WaveLinkConnection } from "./wavelink/connection.js";
import { connectWaveLink } from "./wavelink/discovery.js";

const log = logger("scatto");

const HELP = `Scatto — ponte tra Elgato Wave Link e OBS Studio

Uso:
  scatto [run] [--config config.json]   avvia il ponte
  scatto list  [--config config.json]   elenca canali/mix Wave Link e scene/fonti OBS
  scatto help                           mostra questo messaggio
`;

function parseArgs(argv: string[]) {
  let command = "run";
  let config = "config.json";
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]!;
    if (a === "--config" || a === "-c") config = argv[++i] ?? config;
    else if (a === "--help" || a === "-h") command = "help";
    else if (!a.startsWith("-")) command = a;
  }
  return { command, config: resolve(config) };
}

async function run(cfg: Config): Promise<void> {
  const wl = new WaveLinkConnection(cfg.wavelink);
  const obs = new ObsConnection(cfg.obs);
  const ctx: Ctx = { cfg, wl, obs };

  setupSceneMixes(ctx);
  setupMicIndicators(ctx);
  setupLevelSync(ctx);
  setupEventActions(ctx);

  wl.start();
  obs.start();
  log.info("in ascolto. Ctrl+C per uscire.");

  const shutdown = async () => {
    log.info("chiusura...");
    wl.stop();
    await obs.stop();
    process.exit(0);
  };
  process.on("SIGINT", () => void shutdown());
  process.on("SIGTERM", () => void shutdown());
}

async function list(cfg: Config): Promise<void> {
  try {
    const wl = await connectWaveLink(cfg.wavelink);
    console.log(`\n== Wave Link (${wl.info.name} ${wl.info.version ?? ""}, protocollo ${wl.info.protocol}.x) ==`);
    console.log("Mix:");
    for (const m of wl.mixes()) {
      const alias = m.aliases.length ? `  alias: ${m.aliases.join(", ")}` : "";
      console.log(`  - "${m.name}"  id=${m.id}  livello=${m.level} muto=${m.muted}${alias}`);
    }
    console.log("Canali:");
    const mixName = (id: string) => wl.mixes().find((m) => m.id === id)?.name ?? id;
    for (const c of wl.channels()) {
      const per = Object.entries(c.mixes)
        .map(([id, s]) => `${mixName(id)}=${s.level}${s.muted ? " (muto)" : ""}`)
        .join(", ");
      const glob = c.level !== undefined ? ` globale=${c.level}${c.muted ? " (muto)" : ""}` : "";
      console.log(`  - "${c.name}"  id=${c.id}${glob}  [${per}]`);
    }
    wl.close();
  } catch (err) {
    console.log(`\n== Wave Link ==\n  ${(err as Error).message}`);
  }

  const obs = new ObsConnection(cfg.obs);
  try {
    await obs.ws.connect(cfg.obs.url, cfg.obs.password);
    const { scenes, currentProgramSceneName } = await obs.ws.call("GetSceneList");
    const { inputs } = await obs.ws.call("GetInputList");
    console.log(`\n== OBS (${cfg.obs.url}) ==\nScene:`);
    for (const s of [...scenes].reverse()) {
      const { sceneItems } = await obs.ws.call("GetSceneItemList", { sceneName: String(s.sceneName) });
      const items = sceneItems.map((i) => String(i.sourceName)).join(", ");
      console.log(`  - "${s.sceneName}"${s.sceneName === currentProgramSceneName ? " (attiva)" : ""}: ${items}`);
    }
    console.log("Fonti audio/ingressi:");
    for (const i of inputs) console.log(`  - "${i.inputName}"  (${i.inputKind})`);
    await obs.ws.disconnect();
  } catch (err) {
    console.log(`\n== OBS ==\n  impossibile connettersi a ${cfg.obs.url}: ${(err as Error).message}`);
  }
  console.log();
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  if (args.command === "help") {
    console.log(HELP);
    return;
  }
  let cfg: Config;
  try {
    cfg = args.command === "list" ? safeLoad(args.config) : loadConfig(args.config);
  } catch (err) {
    console.error((err as Error).message);
    process.exit(1);
  }
  setLogLevel(cfg.logLevel);
  if (args.command === "list") return list(cfg);
  if (args.command === "run") return run(cfg);
  console.error(`Comando sconosciuto: ${args.command}\n\n${HELP}`);
  process.exit(1);
}

/** Per "list" il config è facoltativo: senza file si usano i valori predefiniti. */
function safeLoad(path: string): Config {
  try {
    return loadConfig(path);
  } catch (err) {
    if ((err as Error).message.startsWith("File di configurazione non trovato")) return parseConfig({});
    throw err;
  }
}

void main();
