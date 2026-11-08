import { appendFileSync, statSync, writeFileSync } from "node:fs";

type Level = "debug" | "info" | "warn" | "error";
const ORDER: Record<Level, number> = { debug: 10, info: 20, warn: 30, error: 40 };

let current: Level = (process.env.WAVEOBS_LOG as Level) in ORDER ? (process.env.WAVEOBS_LOG as Level) : "info";

export function setLogLevel(level: Level): void {
  current = level;
}

let logFile: string | null = null;

/** Scrive il log anche su file (utile quando WaveOBS gira nascosto, avviato da OBS). */
export function setLogFile(path: string): void {
  try {
    if (statSync(path).size > 1_000_000) writeFileSync(path, "");
  } catch {
    /* il file non esiste ancora */
  }
  logFile = path;
}

function emit(level: Level, scope: string, msg: string, extra: unknown[]): void {
  if (ORDER[level] < ORDER[current]) return;
  const ts = new Date().toISOString().slice(11, 23);
  const line = `${ts} ${level.toUpperCase().padEnd(5)} [${scope}] ${msg}`;
  const out = level === "error" || level === "warn" ? console.error : console.log;
  out(line, ...extra);
  if (logFile) {
    const tail = extra.length ? " " + extra.map((e) => (typeof e === "string" ? e : JSON.stringify(e))).join(" ") : "";
    try {
      appendFileSync(logFile, `${new Date().toISOString().slice(0, 10)} ${line}${tail}\n`);
    } catch {
      /* ignora errori di scrittura */
    }
  }
}

export function logger(scope: string) {
  return {
    debug: (msg: string, ...extra: unknown[]) => emit("debug", scope, msg, extra),
    info: (msg: string, ...extra: unknown[]) => emit("info", scope, msg, extra),
    warn: (msg: string, ...extra: unknown[]) => emit("warn", scope, msg, extra),
    error: (msg: string, ...extra: unknown[]) => emit("error", scope, msg, extra),
  };
}

export type Logger = ReturnType<typeof logger>;
