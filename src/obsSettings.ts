import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

/** Impostazioni del server obs-websocket salvate da OBS (plugin_config/obs-websocket/config.json). */
export interface ObsWebsocketSettings {
  port?: number;
  password?: string;
}

export function obsWebsocketConfigPaths(env: NodeJS.ProcessEnv = process.env): string[] {
  const rel = join("obs-studio", "plugin_config", "obs-websocket", "config.json");
  const paths: string[] = [];
  if (env.APPDATA) paths.push(join(env.APPDATA, rel));
  paths.push(join(homedir(), "Library", "Application Support", rel));
  paths.push(join(env.XDG_CONFIG_HOME ?? join(homedir(), ".config"), rel));
  return paths;
}

/** Legge porta e password di obs-websocket dalla configurazione di OBS, se presente. */
export function readObsWebsocketSettings(paths = obsWebsocketConfigPaths()): ObsWebsocketSettings | null {
  for (const p of paths) {
    try {
      const data = JSON.parse(readFileSync(p, "utf8"));
      return {
        port: Number.isInteger(data.server_port) ? data.server_port : undefined,
        password: data.auth_required === false ? undefined : (data.server_password || undefined),
      };
    } catch {
      /* non presente */
    }
  }
  return null;
}
