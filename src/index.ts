#!/usr/bin/env node
import { dirname, join, resolve } from "node:path";
import { isSea } from "node:sea";
import { type Config, loadConfig, parseConfig } from "./config.js";
import type { Ctx } from "./features/context.js";
import { setupEventActions } from "./features/eventActions.js";
import { setupLevelSync } from "./features/levelSync.js";
import { setupMicIndicators } from "./features/micIndicator.js";
import { setupSceneMixes } from "./features/sceneMixes.js";
import { acquireSingleInstance } from "./instance.js";
import { logger, setLogFile, setLogLevel } from "./log.js";
import { ObsConnection } from "./obs.js";
import { readObsWebsocketSettings } from "./obsSettings.js";
import { WaveLinkConnection } from "./wavelink/connection.js";
import { connectWaveLink } from "./wavelink/discovery.js";

const log = logger("waveobs");

const HELP = `WaveOBS — ponte tra Elgato Wave Link e OBS Studio

Uso:
  waveobs [run] [opzioni]   avvia il ponte
  waveobs list  [opzioni]   elenca canali/mix Wave Link e scene/fonti OBS
  waveobs help              mostra questo messaggio

Opzioni:
  --config <file>     file di configurazione (predefinito: config.json accanto a waveobs.exe)
  --with-obs          modalità "insieme a OBS": una sola istanza, si chiude quando OBS si chiude
  --log-file <file>   scrive il log anche su file (con --with-obs: waveobs.log accanto al config)
`;

/** Cartella base: accanto all'eseguibile quando WaveOBS è impacchettato come .exe, altrimenti la cartella corrente. */
const BASE_DIR = isSea() ? dirname(process.execPath) : process.cwd();

/** Con --with-obs: secondi di attesa per la prima connessione a OBS e dopo una disconnessione. */
const OBS_STARTUP_GRACE_S = 120;
const OBS_LOST_GRACE_S = 15;

function parseArgs(argv: string[]) {
  let command = "run";
  let config = join(BASE_DIR, "config.json");
  let withObs = false;
  let logFile: string | undefined;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]!;
    if (a === "--config" || a === "-c") config = resolve(argv[++i] ?? config);
    else if (a === "--with-obs") withObs = true;
    else if (a === "--log-file") logFile = argv[++i];
    else if (a === "--help" || a === "-h") command = "help";
    else if (!a.startsWith("-")) command = a;
  }
  if (withObs && !logFile) logFile = join(dirname(config), "waveobs.log");
  return { command, config, withObs, logFile: logFile ? resolve(logFile) : undefined };
}

async function run(cfg: Config, withObs: boolean): Promise<void> {
  const wl = new WaveLinkConnection(cfg.wavelink);
  const obs = new ObsConnection(resolveObs(cfg));
  const ctx: Ctx = { cfg, wl, obs };

  setupSceneMixes(ctx);
  setupMicIndicators(ctx);
  setupLevelSync(ctx);
  setupEventActions(ctx);

  let closing = false;
  const shutdown = async (reason: string) => {
    if (closing) return;
    closing = true;
    log.info(`chiusura: ${reason}`);
    setTimeout(() => process.exit(0), 1500).unref();
    wl.stop();
    await Promise.race([obs.stop(), new Promise((r) => setTimeout(r, 1000))]);
    process.exit(0);
  };
  process.on("SIGINT", () => void shutdown("Ctrl+C"));
  process.on("SIGTERM", () => void shutdown("SIGTERM"));

  if (withObs) {
    await acquireSingleInstance(() => void shutdown("avviata una nuova istanza"));
    // Vive solo finché OBS è aperto.
    let timer: NodeJS.Timeout | null = setTimeout(
      () => void shutdown(`OBS non raggiungibile dopo ${OBS_STARTUP_GRACE_S}s`),
      OBS_STARTUP_GRACE_S * 1000,
    );
    obs.on("connected", () => {
      if (timer) clearTimeout(timer);
      timer = null;
    });
    obs.on("disconnected", () => {
      timer = setTimeout(() => void shutdown("OBS è stato chiuso"), OBS_LOST_GRACE_S * 1000);
    });
    obs.ws.on("ExitStarted", () => void shutdown("OBS è stato chiuso"));
  }

  wl.start();
  obs.start();
  log.info(withObs ? "avviato insieme a OBS." : "in ascolto. Ctrl+C per uscire.");
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

  const obsOpts = resolveObs(cfg);
  const obs = new ObsConnection(obsOpts);
  try {
    await obs.ws.connect(obsOpts.url, obsOpts.password);
    const { scenes, currentProgramSceneName } = await obs.ws.call("GetSceneList");
    const { inputs } = await obs.ws.call("GetInputList");
    console.log(`\n== OBS (${obsOpts.url}) ==\nScene:`);
    for (const s of [...scenes].reverse()) {
      const { sceneItems } = await obs.ws.call("GetSceneItemList", { sceneName: String(s.sceneName) });
      const items = sceneItems.map((i) => String(i.sourceName)).join(", ");
      console.log(`  - "${s.sceneName}"${s.sceneName === currentProgramSceneName ? " (attiva)" : ""}: ${items}`);
    }
    console.log("Fonti audio/ingressi:");
    for (const i of inputs) console.log(`  - "${i.inputName}"  (${i.inputKind})`);
    await obs.ws.disconnect();
  } catch (err) {
    console.log(`\n== OBS ==\n  impossibile connettersi a ${obsOpts.url}: ${(err as Error).message}`);
  }
  console.log();
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  if (args.command === "help") {
    console.log(HELP);
    return;
  }
  if (args.logFile) setLogFile(args.logFile);
  let cfg: Config;
  try {
    cfg = args.command === "list" ? safeLoad(args.config) : loadConfig(args.config);
  } catch (err) {
    logger("config").error((err as Error).message);
    process.exit(1);
  }
  setLogLevel(cfg.logLevel);
  if (args.command === "list") return list(cfg);
  if (args.command === "run") {
    try {
      return await run(cfg, args.withObs);
    } catch (err) {
      log.error((err as Error).message);
      process.exit(1);
    }
  }
  console.error(`Comando sconosciuto: ${args.command}\n\n${HELP}`);
  process.exit(1);
}

/** Completa url/password di OBS leggendo le impostazioni di obs-websocket, se non sono nel config. */
function resolveObs(cfg: Config): { url: string; password?: string } {
  const saved = cfg.obs.url && cfg.obs.password !== undefined ? null : readObsWebsocketSettings();
  const url = cfg.obs.url ?? `ws://127.0.0.1:${saved?.port ?? 4455}`;
  const password = cfg.obs.password ?? saved?.password;
  if (saved && cfg.obs.password === undefined) log.debug("password di OBS letta dalle impostazioni di obs-websocket");
  return { url, password };
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
