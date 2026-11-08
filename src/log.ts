type Level = "debug" | "info" | "warn" | "error";
const ORDER: Record<Level, number> = { debug: 10, info: 20, warn: 30, error: 40 };

let current: Level = (process.env.SCATTO_LOG as Level) in ORDER ? (process.env.SCATTO_LOG as Level) : "info";

export function setLogLevel(level: Level): void {
  current = level;
}

function emit(level: Level, scope: string, msg: string, extra: unknown[]): void {
  if (ORDER[level] < ORDER[current]) return;
  const ts = new Date().toISOString().slice(11, 23);
  const line = `${ts} ${level.toUpperCase().padEnd(5)} [${scope}] ${msg}`;
  const out = level === "error" || level === "warn" ? console.error : console.log;
  out(line, ...extra);
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
